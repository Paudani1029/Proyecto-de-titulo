"""Etiqueta fotos automáticamente para entrenar el modelo de Lumina.

Usa dos "profesores" y junta sus resultados en un solo archivo COCO:
  1. Grounding DINO (Apache 2.0): busca las clases NUEVAS (puertas, escaleras...)
     a partir de texto. Es lento y pesado, por eso solo corre en el PC.
  2. D-FINE Objects365 (el modelo actual de la app): etiqueta las 365 clases que
     ya conoce. Sin esto, el modelo nuevo OLVIDARÍA esas clases, porque aprendería
     que un basurero sin etiqueta "no es nada".

El resultado NO es perfecto: hay que revisarlo a mano (ver README.md) antes de
entrenar. Corregir es mucho más rápido que dibujar todas las cajas desde cero.

Uso:
  python autoetiquetar.py CARPETA_FOTOS salida.json [--dispositivo cuda]

Las categorías del JSON usan los MISMOS números que el modelo:
  1-365 = Objects365, 366 en adelante = CLASES_NUEVAS (0 está vacía).
"""
import argparse
import json
from pathlib import Path

import torch
from PIL import Image, ImageOps
from transformers import (AutoModelForZeroShotObjectDetection, AutoProcessor,
                          DFineForObjectDetection, RTDetrImageProcessor)

from clases_lumina import CLASES_NUEVAS, MODELO_BASE

MODELO_DINO = 'IDEA-Research/grounding-dino-tiny'
EXTENSIONES = {'.jpg', '.jpeg', '.png', '.webp'}


def categorias(id2label):
    """Lista de categorías COCO: las del modelo base + las nuevas."""
    cats = [{'id': i, 'name': str(n), 'supercategory': 'objects365'}
            for i, n in sorted(id2label.items()) if i > 0]
    base = len(id2label)  # 366: el 0 vacío + 365 clases
    cats += [{'id': base + i, 'name': c['clave'], 'supercategory': 'lumina'}
             for i, c in enumerate(CLASES_NUEVAS)]
    return cats


def caja_coco(x1, y1, x2, y2):
    w, h = x2 - x1, y2 - y1
    return [round(x1, 1), round(y1, 1), round(w, 1), round(h, 1)], round(w * h, 1)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('fotos', type=Path)
    p.add_argument('salida', type=Path)
    p.add_argument('--dispositivo', default='cuda' if torch.cuda.is_available() else 'cpu')
    p.add_argument('--umbral-dino', type=float, default=0.35,
                   help='confianza mínima de Grounding DINO para las clases nuevas')
    p.add_argument('--modelo-dino', default=MODELO_DINO,
                   help='id de Hugging Face o carpeta local con Grounding DINO ya descargado')
    p.add_argument('--umbral-base', type=float, default=0.5,
                   help='confianza mínima de D-FINE para las 365 clases conocidas')
    a = p.parse_args()

    fotos = sorted(f for f in a.fotos.rglob('*') if f.suffix.lower() in EXTENSIONES)
    if not fotos:
        raise SystemExit(f'No hay fotos en {a.fotos}')
    print(f'{len(fotos)} fotos · dispositivo: {a.dispositivo}')

    dev = a.dispositivo
    proc_dino = AutoProcessor.from_pretrained(a.modelo_dino)
    dino = AutoModelForZeroShotObjectDetection.from_pretrained(a.modelo_dino).to(dev).eval()
    proc_base = RTDetrImageProcessor.from_pretrained(MODELO_BASE)
    base = DFineForObjectDetection.from_pretrained(MODELO_BASE).to(dev).eval()
    n_base = len(base.config.id2label)

    # Grounding DINO recibe todas las frases juntas y dice cuál encontró.
    frase_a_clase = {}
    for i, c in enumerate(CLASES_NUEVAS):
        for frase in c['consulta'].split(' . '):
            frase_a_clase[frase.strip().lower()] = n_base + i
    texto = ' . '.join(frase_a_clase) + ' .'

    coco = {'images': [], 'annotations': [], 'categories': categorias(base.config.id2label)}
    contador = {}

    for n, ruta in enumerate(fotos, 1):
        # exif_transpose: las fotos del celular suelen venir giradas en el EXIF
        imagen = ImageOps.exif_transpose(Image.open(ruta)).convert('RGB')
        ancho, alto = imagen.size
        id_imagen = n
        coco['images'].append({'id': id_imagen, 'file_name': str(ruta.relative_to(a.fotos)).replace('\\', '/'),
                               'width': ancho, 'height': alto})

        with torch.no_grad():
            # 1) Clases nuevas
            ent = proc_dino(images=imagen, text=texto, return_tensors='pt').to(dev)
            sal = dino(**ent)
            res = proc_dino.post_process_grounded_object_detection(
                sal, ent.input_ids, threshold=a.umbral_dino, text_threshold=0.25,
                target_sizes=[(alto, ancho)])[0]
            etiquetas_txt = res.get('text_labels', res.get('labels'))
            for caja, puntaje, frase in zip(res['boxes'].tolist(), res['scores'].tolist(), etiquetas_txt):
                clase = frase_a_clase.get(str(frase).strip().lower())
                if clase is None:  # a veces devuelve frases mezcladas
                    clase = next((c for f, c in frase_a_clase.items() if f in str(frase).lower()), None)
                if clase is None:
                    continue
                bbox, area = caja_coco(*caja)
                coco['annotations'].append({'id': len(coco['annotations']) + 1, 'image_id': id_imagen,
                                            'category_id': clase, 'bbox': bbox, 'area': area,
                                            'iscrowd': 0, 'score': round(puntaje, 3), 'origen': 'dino'})
                contador[clase] = contador.get(clase, 0) + 1

            # 2) Las 365 clases conocidas
            ent = proc_base(images=imagen, return_tensors='pt').to(dev)
            sal = base(**ent)
            res = proc_base.post_process_object_detection(
                sal, threshold=a.umbral_base, target_sizes=[(alto, ancho)])[0]
            for caja, puntaje, clase in zip(res['boxes'].tolist(), res['scores'].tolist(), res['labels'].tolist()):
                if clase == 0:
                    continue
                bbox, area = caja_coco(*caja)
                coco['annotations'].append({'id': len(coco['annotations']) + 1, 'image_id': id_imagen,
                                            'category_id': clase, 'bbox': bbox, 'area': area,
                                            'iscrowd': 0, 'score': round(puntaje, 3), 'origen': 'dfine'})

        print(f'  [{n}/{len(fotos)}] {ruta.name}')

    a.salida.parent.mkdir(parents=True, exist_ok=True)
    a.salida.write_text(json.dumps(coco, ensure_ascii=False, indent=1), encoding='utf8')
    nombres = {c['id']: c['name'] for c in coco['categories']}
    print(f'Listo: {a.salida} · {len(coco["annotations"])} cajas')
    print('Clases nuevas encontradas:',
          ', '.join(f'{nombres[c]}={k}' for c, k in sorted(contador.items())) or 'ninguna')


if __name__ == '__main__':
    main()
