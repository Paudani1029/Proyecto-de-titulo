"""Exporta un modelo D-FINE (formato Hugging Face) a ONNX listo para Lumina.

Sirve para los pesos oficiales (Apache 2.0) y para los modelos propios entrenados
con entrenar_dfine.py.

Entrada:  'imagen'  uint8 [1, 640, 640, 3]  RGB (estirada a 640x640, sin barras)
Salidas:  'cajas'    float32 [1, 300, 4]  x1,y1,x2,y2 en píxeles de la entrada (0-640)
          'puntajes' float32 [1, 300]
          'clases'   int64   [1, 300]     índice en la lista de clases del modelo
Además escribe <salida>.clases.txt con los nombres en orden (una por línea), para
copiarlos a la app.

Uso: python exportar_dfine.py MODELO salida.onnx
  MODELO: id de Hugging Face (ustc-community/dfine-small-coco,
          ustc-community/dfine-small-obj365) o carpeta local con un modelo propio.
"""
import sys
import torch
from transformers import DFineForObjectDetection

origen = sys.argv[1]
salida = sys.argv[2]
LADO = 640

modelo = DFineForObjectDetection.from_pretrained(origen).eval()
etiquetas = [modelo.config.id2label[i] for i in range(len(modelo.config.id2label))]
# Los pesos de Objects365 traen una clase 0 vacía ("None"): se descarta dentro del
# modelo para que nunca le gane a una clase real.
saltar = 1 if str(etiquetas[0]) in ('None', 'background', '') else 0
etiquetas = etiquetas[saltar:]


class Envoltura(torch.nn.Module):
    def __init__(self, modelo):
        super().__init__()
        self.modelo = modelo

    def forward(self, imagen):
        x = imagen.permute(0, 3, 1, 2).float() / 255.0  # NHWC uint8 -> NCHW [0,1]
        out = self.modelo(pixel_values=x)
        prob = out.logits[..., saltar:].sigmoid()    # [1, 300, clases]
        puntajes, clases = prob.max(dim=-1)          # mejor clase por consulta
        cx, cy, w, h = out.pred_boxes.unbind(-1)     # normalizadas 0-1
        cajas = torch.stack([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], -1) * LADO
        return cajas, puntajes, clases


crudo = salida + '.crudo.onnx'  # export directo de PyTorch, antes de plegar constantes
ejemplo = torch.zeros(1, LADO, LADO, 3, dtype=torch.uint8)
with torch.no_grad():
    torch.onnx.export(
        Envoltura(modelo), (ejemplo,), crudo,
        input_names=['imagen'], output_names=['cajas', 'puntajes', 'clases'],
        opset_version=17, dynamo=False,
    )

# El "position embedding" de D-FINE se calcula en float64 (double) en cada ejecución,
# y el ONNX Runtime de Android no tiene Cos/Sin para double (falla al cargar con
# ORT_NOT_IMPLEMENTED). Como la entrada es fija (640x640), ese cálculo siempre da lo
# mismo: se pliega a constantes con ONNX Runtime del PC. El nivel BASIC solo hace
# optimizaciones con operadores ONNX estándar, así el archivo sirve en cualquier lado.
import os
import onnx
import onnxruntime as ort
from onnx import TensorProto, shape_inference

opciones = ort.SessionOptions()
opciones.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
opciones.optimized_model_filepath = salida
ort.InferenceSession(crudo, opciones, providers=['CPUExecutionProvider'])
os.remove(crudo)

modelo_onnx = shape_inference.infer_shapes(onnx.load(salida))
tipos = {v.name: v.type.tensor_type.elem_type
         for v in list(modelo_onnx.graph.value_info) + list(modelo_onnx.graph.input)}
con_double = sorted({n.op_type for n in modelo_onnx.graph.node
                     if any(tipos.get(t) == TensorProto.DOUBLE
                            for t in list(n.input) + list(n.output))})
if con_double:
    raise SystemExit(f'Quedaron operaciones en float64 (fallarán en Android): {con_double}')
with open(salida + '.clases.txt', 'w', encoding='utf8') as f:
    f.write('\n'.join(map(str, etiquetas)) + '\n')
print(f'Listo: {salida} ({len(etiquetas)} clases)')
