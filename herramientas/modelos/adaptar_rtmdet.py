"""Adapta el ONNX de RTMDet (bukuroo/RTMDet-ONNX, Apache 2.0) al formato común de Lumina.

Entrada:  'imagen'  uint8 [1, 640, 640, 3]  RGB, con letterbox: la foto se escala sin
          deformar y se pega arriba a la izquierda; el resto queda en negro.
Salidas:  'cajas'    float32 [1, N, 4]  x1,y1,x2,y2 en píxeles de la entrada (0-640)
          'puntajes' float32 [1, N]
          'clases'   int64   [1, N]     índice COCO-80 (0 = person)
La normalización (media/desviación) y el NMS quedan dentro del modelo.

Uso: python adaptar_rtmdet.py rtmdet-s-coco.onnx salida.onnx
"""
import sys
import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto

origen, destino = sys.argv[1], sys.argv[2]
m = onnx.load(origen)
g = m.graph
entrada_vieja = g.input[0].name  # 'input' float32 [1,3,640,640]

media = numpy_helper.from_array(np.array([123.675, 116.28, 103.53], np.float32).reshape(1, 3, 1, 1), 'lumina_media')
desv = numpy_helper.from_array(np.array([58.395, 57.12, 57.375], np.float32).reshape(1, 3, 1, 1), 'lumina_desv')
g.initializer.extend([media, desv])

pre = [
    helper.make_node('Cast', ['imagen'], ['lumina_f'], to=TensorProto.FLOAT),
    helper.make_node('Transpose', ['lumina_f'], ['lumina_nchw'], perm=[0, 3, 1, 2]),
    helper.make_node('Sub', ['lumina_nchw', 'lumina_media'], ['lumina_centrada']),
    helper.make_node('Div', ['lumina_centrada', 'lumina_desv'], [entrada_vieja]),
]

dets, labels = g.output[0].name, g.output[1].name
eje = numpy_helper.from_array(np.array([2], np.int64), 'lumina_eje')
g.initializer.append(eje)
post = [
    helper.make_node('Slice', [dets, 'lumina_ini_c', 'lumina_fin_c', 'lumina_eje'], ['cajas']),
    helper.make_node('Slice', [dets, 'lumina_ini_p', 'lumina_fin_p', 'lumina_eje'], ['lumina_p3']),
    helper.make_node('Squeeze', ['lumina_p3'], ['puntajes'], axes=[2]),  # opset 11: axes es atributo
    helper.make_node('Identity', [labels], ['clases']),
]
g.initializer.extend([
    numpy_helper.from_array(np.array([0], np.int64), 'lumina_ini_c'),
    numpy_helper.from_array(np.array([4], np.int64), 'lumina_fin_c'),
    numpy_helper.from_array(np.array([4], np.int64), 'lumina_ini_p'),
    numpy_helper.from_array(np.array([5], np.int64), 'lumina_fin_p'),
])

nodos = pre + list(g.node) + post
del g.node[:]
g.node.extend(nodos)
del g.input[:]
g.input.append(helper.make_tensor_value_info('imagen', TensorProto.UINT8, [1, 640, 640, 3]))
del g.output[:]
g.output.extend([
    helper.make_tensor_value_info('cajas', TensorProto.FLOAT, [1, 'n', 4]),
    helper.make_tensor_value_info('puntajes', TensorProto.FLOAT, [1, 'n']),
    helper.make_tensor_value_info('clases', TensorProto.INT64, [1, 'n']),
])
onnx.checker.check_model(m)
onnx.save(m, destino)
print('Listo:', destino)
