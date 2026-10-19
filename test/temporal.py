from ultralytics import YOLO

# 1. Carga el modelo YOLOv8 Nano preentrenado (se descarga solo si no existe)
model = YOLO("yolov8n.pt")

# 2. Expórtalo al formato TFLite (LiteRT)
# Nota: Puedes añadir 'quantize=8' si necesitas la versión optimizada en INT8
model.export(format="litert") 