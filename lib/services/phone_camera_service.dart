import 'dart:async';
import 'package:camera/camera.dart';
import 'camara_service.dart';
import 'reconocimiento_service.dart';

class PhoneCameraService implements CameraService {
  CameraController? _controller;
  final _controlador = StreamController<String>();
  Timer? _temporizador;
  bool _activo = false;
  bool _procesando = false; // evita superponer análisis

  final ReconocimientoService _ia = ReconocimientoService();

  CameraController? get controller => _controller;

  @override
  Future<bool> conectar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) return false;

      final camaraTrasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );

      _controller = CameraController(
        camaraTrasera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      _activo = true;
      _iniciarCapturaPeriodica();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _iniciarCapturaPeriodica() {
    _temporizador = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_activo || _procesando || _controller == null ||
          !_controller!.value.isInitialized) {
        return;
      }

      _procesando = true;
      try {
        final XFile foto = await _controller!.takePicture();
        final descripcion = await _ia.analizarImagen(foto.path);
        _controlador.add(descripcion);
      } catch (e) {
        _controlador.add('Error al analizar imagen: $e');
      } finally {
        _procesando = false;
      }
    });
  }

  @override
  Stream<String> get descripciones => _controlador.stream;

  @override
  void desconectar() {
    _activo = false;
    _temporizador?.cancel();
    _controller?.dispose();
    _ia.liberar();
    _controlador.close();
  }
}