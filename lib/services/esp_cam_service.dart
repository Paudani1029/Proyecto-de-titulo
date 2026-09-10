import 'dart:async';
//import 'dart:convert';
import 'package:http/http.dart' as http;
import 'camara_service.dart';

class EspCamService implements CameraService {
  // La IP la vamos a dejar configurable, porque va a depender
  // de la red a la que se conecte el ESP32-CAM.
  final String direccionIp;

  EspCamService({required this.direccionIp});

  final _controlador = StreamController<String>();
  bool _activo = false;

  @override
  Future<bool> conectar() async {
    try {
      // Probamos que el ESP32-CAM responda antes de seguir.
      // /status es un endpoint de ejemplo — cuando programen el
      // firmware del ESP32-CAM, deben definir una ruta similar.
      final respuesta = await http
          .get(Uri.parse('http://$direccionIp/status'))
          .timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200) {
        _activo = true;
        _iniciarLecturaContinua();
        return true;
      }
      return false;
    } catch (e) {
      // Si no hay respuesta (cámara apagada, IP incorrecta, sin
      // conexión), devolvemos false en vez de romper la app.
      return false;
    }
  }

  void _iniciarLecturaContinua() async {
    // NOTA: esto es un esqueleto. Aquí es donde, más adelante,
    // van a leer el stream MJPEG de /stream, capturar un frame,
    // pasarlo al modelo de IA (local u online), y mandar la
    // descripción resultante al controlador.
    while (_activo) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_activo) break;

      // Por ahora, solo confirmamos que sigue "viva" la conexión.
      _controlador.add('[Pendiente] Analizando imagen de la cámara...');
    }
  }

  @override
  Stream<String> get descripciones => _controlador.stream;

  @override
  void desconectar() {
    _activo = false;
    _controlador.close();
  }
}