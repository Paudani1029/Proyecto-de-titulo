"""Prueba los ONNX de Lumina en el PC, con la misma preparación que hace la app.

Uso: python probar_modelos.py foto1.jpg [foto2.jpg ...]
(se ejecuta desde la raíz del proyecto; lee assets/modelos/)
"""
import sys
import time

import numpy as np
import onnxruntime as ort
from PIL import Image

COCO = ['person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
        'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog',
        'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella',
        'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
        'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
        'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich',
        'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
        'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
        'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book',
        'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush']

# (archivo, letterbox, umbral) — igual que ModeloDeteccion en lib/services/detector_onnx.dart
MODELOS = [
    ('assets/modelos/dfine-s-coco-v2.onnx', False, 0.5),
    ('assets/modelos/rtmdet-s-coco-v1.onnx', True, 0.4),
]
LADO = 640


def preparar(im, letterbox):
    w, h = im.size
    if letterbox:
        r = LADO / max(w, h)
        nw, nh = round(w * r), round(h * r)
        a = np.zeros((LADO, LADO, 3), np.uint8)
        a[:nh, :nw] = np.asarray(im.resize((nw, nh), Image.BILINEAR))
        return a[None], (nw, nh)
    return np.asarray(im.resize((LADO, LADO), Image.BILINEAR))[None], (LADO, LADO)


for archivo, letterbox, umbral in MODELOS:
    sesion = ort.InferenceSession(archivo)
    print('==', archivo)
    for foto in sys.argv[1:]:
        im = Image.open(foto).convert('RGB')
        x, (ancho, alto) = preparar(im, letterbox)
        sesion.run(None, {'imagen': x})  # calentamiento
        t = time.time()
        cajas, puntajes, clases = sesion.run(None, {'imagen': x})
        print(f'  {foto}: {int((time.time() - t) * 1000)} ms')
        for c, p, k in sorted(zip(cajas[0], puntajes[0], clases[0]), key=lambda z: -z[1]):
            if p >= umbral:
                # fracciones de la foto (0-1), como Deteccion en la app
                x1, y1, x2, y2 = c[0] / ancho, c[1] / alto, c[2] / ancho, c[3] / alto
                print(f'    {COCO[k]:<14} {p:.2f}  centroX={(x1 + x2) / 2:.2f} alto={y2 - y1:.2f}')
