import 'package:camera/camera.dart';

import 'fuente_imagen.dart';

/// Toma fotos con la cámara trasera del teléfono.
class FuenteImagenTelefono implements FuenteImagen {
  CameraController? _controller;

  /// Para mostrar la vista previa en pantalla (Ajustes -> Ver la cámara).
  CameraController? get controller => _controller;

  @override
  Future<bool> conectar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) return false;

      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );

      final controlador = CameraController(
        trasera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controlador.initialize(); // también pide el permiso de cámara
      _controller = controlador;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> capturarFoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    try {
      final foto = await c.takePicture();
      return foto.path;
    } catch (_) {
      return null;
    }
  }

  @override
  void desconectar() {
    _controller?.dispose();
    _controller = null;
  }
}
