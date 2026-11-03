# Modelos de detección de Lumina

La app usa ONNX Runtime (`flutter_onnxruntime`) con uno de estos dos modelos, ambos
con licencia **Apache 2.0** (uso comercial permitido):

| Archivo en `assets/modelos/` | Modelo | Origen |
|---|---|---|
| `dfine-s-coco-v2.onnx` | D-FINE-S (COCO) | Pesos oficiales `ustc-community/dfine-small-coco` (Hugging Face), exportados con `exportar_dfine.py` |
| `rtmdet-s-coco-v1.onnx` | RTMDet-s (COCO) | `bukuroo/RTMDet-ONNX` → `rtmdet-s-coco.onnx`, adaptado con `adaptar_rtmdet.py` |

Los dos quedan con la misma entrada y salida, así la app los trata igual:

- entrada `imagen`: uint8 `[1, 640, 640, 3]`, RGB
- salidas `cajas` (float32 `[1, N, 4]`, x1 y1 x2 y2 en píxeles de la entrada),
  `puntajes` (float32 `[1, N]`), `clases` (int64 `[1, N]`, índice COCO-80)

## Regenerarlos

Requiere Python con `torch`, `transformers`, `onnx`, `onnxruntime` y `pillow`.

```bash
# D-FINE-S
python herramientas/modelos/exportar_dfine.py small assets/modelos/dfine-s-coco-v2.onnx

# RTMDet-s
curl -L -o rtmdet-s-coco.onnx https://huggingface.co/bukuroo/RTMDet-ONNX/resolve/main/rtmdet-s-coco.onnx
python herramientas/modelos/adaptar_rtmdet.py rtmdet-s-coco.onnx assets/modelos/rtmdet-s-coco-v1.onnx

# Comprobar que detectan bien
python herramientas/modelos/probar_modelos.py foto.jpg
```

Si cambias un modelo, **súbele la versión al nombre** (`-v2.onnx`) y actualiza
`lib/services/detector_onnx.dart`: el plugin guarda una copia en caché por nombre de
archivo y, si el nombre no cambia, seguiría usando la versión vieja.

## Comparar en el teléfono

1. `flutter run --profile` (en modo debug los tiempos no sirven).
2. Ajustes → *Banco de pruebas*: elige modelo y acelerador.
3. Deja la app en modo guía unos 5 minutos con cada combinación (misma escena,
   batería parecida al empezar). Ajustes muestra los tiempos y la temperatura.
4. Para el detalle: `adb shell run-as com.example.lumina cat cache/lumina_banco.csv > banco.csv`
