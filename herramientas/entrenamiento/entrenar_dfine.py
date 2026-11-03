"""Entrena D-FINE con las clases propias de Lumina SIN olvidar las 365 que ya sabe.

Parte de los pesos de Objects365 y AMPLÍA las capas de clasificación: copia las
filas de las 365 clases conocidas y agrega filas nuevas para CLASES_NUEVAS. Así el
modelo solo tiene que aprender lo nuevo, y necesita muchas menos fotos.

Uso (con GPU: Colab o Kaggle; en CPU solo sirve para probar que todo corre):
  python entrenar_dfine.py revisadas.json CARPETA_FOTOS salida/ [--epocas 40]

Después:
  python ../modelos/exportar_dfine.py salida/mejor assets/modelos/dfine-s-lumina-v1.onnx
"""
import argparse
import json
import math
import random
from pathlib import Path

import torch
from PIL import Image, ImageOps
from torchvision.transforms import ColorJitter
from transformers import DFineForObjectDetection, RTDetrImageProcessor, get_cosine_schedule_with_warmup

from clases_lumina import CLASES_NUEVAS, MODELO_BASE

PRIOR_FOCAL = -math.log((1 - 0.01) / 0.01)  # sesgo inicial típico de una clase nueva


# ---------------------------------------------------------------------------
# Modelo
# ---------------------------------------------------------------------------

def ampliar_modelo(base):
    """Devuelve un modelo con las clases de `base` + CLASES_NUEVAS, copiando todo lo aprendido."""
    viejo = len(base.config.id2label)
    id2label = {i: base.config.id2label[i] for i in range(viejo)}
    for i, c in enumerate(CLASES_NUEVAS):
        id2label[viejo + i] = c['clave']

    config = base.config.__class__.from_dict(base.config.to_dict())
    config.id2label = id2label
    config.label2id = {str(v): k for k, v in id2label.items()}
    nuevo = DFineForObjectDetection(config)

    estado_nuevo = nuevo.state_dict()
    copiadas, ampliadas = 0, []
    for nombre, peso in base.state_dict().items():
        destino = estado_nuevo[nombre]
        if destino.shape == peso.shape:
            destino.copy_(peso)
            copiadas += 1
        elif nombre.endswith('denoising_class_embed.weight'):
            # (clases + 1) filas: la última es "relleno". Se copia a la nueva última.
            destino[:viejo] = peso[:viejo]
            destino[-1] = peso[-1]
            ampliadas.append(nombre)
        elif destino.shape[0] > peso.shape[0] and destino.shape[1:] == peso.shape[1:]:
            destino[:viejo] = peso
            if nombre.endswith('.bias'):
                destino[viejo:] = PRIOR_FOCAL
            ampliadas.append(nombre)
        else:
            raise ValueError(f'No sé ampliar {nombre}: {tuple(peso.shape)} -> {tuple(destino.shape)}')
    nuevo.load_state_dict(estado_nuevo)
    print(f'Modelo ampliado: {viejo} -> {len(id2label)} clases '
          f'({copiadas} capas copiadas, {len(ampliadas)} ampliadas)')
    return nuevo


# ---------------------------------------------------------------------------
# Datos
# ---------------------------------------------------------------------------

class Fotos(torch.utils.data.Dataset):
    def __init__(self, imagenes, anotaciones, carpeta, aumentar):
        self.imagenes = imagenes
        self.anotaciones = anotaciones
        self.carpeta = carpeta
        self.aumentar = aumentar
        self.color = ColorJitter(brightness=0.4, contrast=0.4, saturation=0.4, hue=0.03)

    def __len__(self):
        return len(self.imagenes)

    def __getitem__(self, i):
        info = self.imagenes[i]
        imagen = ImageOps.exif_transpose(Image.open(self.carpeta / info['file_name'])).convert('RGB')
        cajas = [dict(a) for a in self.anotaciones.get(info['id'], [])]
        if self.aumentar:
            imagen = self.color(imagen)  # luz de día, noche, sombra...
            if random.random() < 0.5:    # espejo horizontal
                imagen = ImageOps.mirror(imagen)
                for a in cajas:
                    x, y, w, h = a['bbox']
                    a['bbox'] = [imagen.width - x - w, y, w, h]
        return imagen, {'image_id': info['id'], 'annotations': cajas}


def cargar_coco(ruta):
    coco = json.loads(Path(ruta).read_text(encoding='utf8'))
    por_imagen = {}
    for a in coco['annotations']:
        if a.get('ignorar'):
            continue
        x, y, w, h = a['bbox']
        if w < 2 or h < 2:
            continue
        por_imagen.setdefault(a['image_id'], []).append(
            {'bbox': [x, y, w, h], 'category_id': a['category_id'], 'area': w * h, 'iscrowd': 0})
    return coco['images'], por_imagen


# ---------------------------------------------------------------------------
# Evaluación sencilla: ¿encuentra las clases nuevas?
# ---------------------------------------------------------------------------

def iou(a, b):
    ix = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0


@torch.no_grad()
def evaluar(modelo, procesador, cargador, dev, primera_nueva):
    """Pérdida de validación + recall/precisión (IoU ≥ 0,5, confianza ≥ 0,5) por clase nueva."""
    modelo.eval()
    perdida, lotes = 0.0, 0
    stats = {}  # clase -> [aciertos, total_reales, total_predichas]
    for pixeles, etiquetas, tamanos in cargador:
        pixeles = pixeles.to(dev)
        etiquetas = [{k: v.to(dev) for k, v in e.items()} for e in etiquetas]
        sal = modelo(pixel_values=pixeles, labels=etiquetas)
        perdida += sal.loss.item()
        lotes += 1
        res = procesador.post_process_object_detection(sal, threshold=0.5, target_sizes=tamanos)
        for r, e, (alto, ancho) in zip(res, etiquetas, tamanos):
            reales = []
            for c, (cx, cy, w, h) in zip(e['class_labels'].tolist(), e['boxes'].tolist()):
                reales.append((c, [(cx - w / 2) * ancho, (cy - h / 2) * alto, (cx + w / 2) * ancho, (cy + h / 2) * alto]))
            predichas = list(zip(r['labels'].tolist(), r['boxes'].tolist()))
            for c, _ in reales:
                if c >= primera_nueva:
                    stats.setdefault(c, [0, 0, 0])[1] += 1
            for c, _ in predichas:
                if c >= primera_nueva:
                    stats.setdefault(c, [0, 0, 0])[2] += 1
            usadas = set()
            for c, caja in reales:
                if c < primera_nueva:
                    continue
                for j, (cp, cajap) in enumerate(predichas):
                    if j not in usadas and cp == c and iou(caja, cajap) >= 0.5:
                        usadas.add(j)
                        stats[c][0] += 1
                        break
    modelo.train()
    return perdida / max(lotes, 1), stats


# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('anotaciones', type=Path, help='JSON COCO revisado')
    p.add_argument('fotos', type=Path)
    p.add_argument('salida', type=Path)
    p.add_argument('--epocas', type=int, default=40)
    p.add_argument('--lote', type=int, default=8)
    p.add_argument('--lr', type=float, default=1e-4)
    p.add_argument('--lr-columna', type=float, default=1e-5, help='lr del backbone (cambia poco)')
    p.add_argument('--val', type=float, default=0.15, help='fracción de fotos para validar')
    p.add_argument('--pasos-max', type=int, default=0, help='cortar antes (solo para probar)')
    p.add_argument('--dispositivo', default='cuda' if torch.cuda.is_available() else 'cpu')
    p.add_argument('--semilla', type=int, default=0)
    a = p.parse_args()

    random.seed(a.semilla)
    torch.manual_seed(a.semilla)
    dev = a.dispositivo

    imagenes, por_imagen = cargar_coco(a.anotaciones)
    random.shuffle(imagenes)
    n_val = max(1, int(len(imagenes) * a.val)) if len(imagenes) > 1 else 0
    val, entren = imagenes[:n_val], imagenes[n_val:] or imagenes
    print(f'{len(entren)} fotos para entrenar, {len(val)} para validar')

    procesador = RTDetrImageProcessor.from_pretrained(MODELO_BASE)

    def juntar(lote):
        imgs, anots = zip(*lote)
        ent = procesador(images=list(imgs), annotations=list(anots), return_tensors='pt')
        tamanos = [(im.height, im.width) for im in imgs]
        return ent['pixel_values'], ent['labels'], tamanos

    cargar = dict(batch_size=a.lote, collate_fn=juntar, num_workers=0)
    c_entren = torch.utils.data.DataLoader(Fotos(entren, por_imagen, a.fotos, True), shuffle=True, **cargar)
    c_val = torch.utils.data.DataLoader(Fotos(val, por_imagen, a.fotos, False), **cargar) if val else None

    base = DFineForObjectDetection.from_pretrained(MODELO_BASE)
    primera_nueva = len(base.config.id2label)
    modelo = ampliar_modelo(base).to(dev).train()
    del base

    columna = [p_ for n, p_ in modelo.named_parameters() if 'backbone' in n]
    resto = [p_ for n, p_ in modelo.named_parameters() if 'backbone' not in n]
    opt = torch.optim.AdamW([{'params': columna, 'lr': a.lr_columna},
                             {'params': resto, 'lr': a.lr}], weight_decay=1e-4)
    total = a.epocas * len(c_entren)
    if a.pasos_max:
        total = min(total, a.pasos_max)
    plan = get_cosine_schedule_with_warmup(opt, min(300, total // 10), total)

    nombres = modelo.config.id2label
    mejor, paso = float('inf'), 0
    a.salida.mkdir(parents=True, exist_ok=True)
    for epoca in range(1, a.epocas + 1):
        suma, pasos_epoca = 0.0, 0
        for pixeles, etiquetas, _ in c_entren:
            pixeles = pixeles.to(dev)
            etiquetas = [{k: v.to(dev) for k, v in e.items()} for e in etiquetas]
            perdida = modelo(pixel_values=pixeles, labels=etiquetas).loss
            opt.zero_grad()
            perdida.backward()
            torch.nn.utils.clip_grad_norm_(modelo.parameters(), 0.1)
            opt.step()
            plan.step()
            suma += perdida.item()
            pasos_epoca += 1
            paso += 1
            if paso % 20 == 0 or a.pasos_max:
                print(f'  paso {paso}/{total} · pérdida {perdida.item():.3f}')
            if a.pasos_max and paso >= a.pasos_max:
                break

        linea = f'Época {epoca}: pérdida {suma / max(1, pasos_epoca):.3f}'
        if c_val is not None:
            p_val, stats = evaluar(modelo, procesador, c_val, dev, primera_nueva)
            linea += f' · validación {p_val:.3f}'
            for c, (ok, reales, pred) in sorted(stats.items()):
                rec = ok / reales if reales else 0
                prec = ok / pred if pred else 0
                linea += f'\n    {nombres[c]:<16} recall {rec:.0%} ({ok}/{reales}) · precisión {prec:.0%}'
            if p_val < mejor:
                mejor = p_val
                modelo.save_pretrained(a.salida / 'mejor')
                procesador.save_pretrained(a.salida / 'mejor')
                linea += '\n    (guardado como mejor)'
        print(linea)
        if a.pasos_max and paso >= a.pasos_max:
            break

    modelo.save_pretrained(a.salida / 'final')
    procesador.save_pretrained(a.salida / 'final')
    if c_val is None:
        modelo.save_pretrained(a.salida / 'mejor')
        procesador.save_pretrained(a.salida / 'mejor')
    print(f'Listo: {a.salida}')


if __name__ == '__main__':
    main()
