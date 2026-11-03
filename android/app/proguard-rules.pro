# ONNX Runtime usa reflexión/JNI: si R8 renombra estas clases, la app se cae en release.
-keep class ai.onnxruntime.** { *; }
