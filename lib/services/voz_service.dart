import 'package:flutter_tts/flutter_tts.dart';

class VozService {
  final FlutterTts _tts = FlutterTts();
  bool _inicializado = false;

  Future<void> _inicializar() async {
    if (_inicializado) return;

    try {
      final dynamic idiomas = await _tts.getLanguages;
      // ignore: avoid_print
      print('Idiomas disponibles: $idiomas');

      final dynamic motores = await _tts.getEngines;
      // ignore: avoid_print
      print('Motores de voz disponibles: $motores');
    } catch (e) {
      // ignore: avoid_print
      print('Error al consultar idiomas/motores: $e');
    }

    try {
      final resultadoIdioma = await _tts.setLanguage('es-US');
      // ignore: avoid_print
      print('Resultado setLanguage es-CL: $resultadoIdioma');
    } catch (e) {
      // ignore: avoid_print
      print('Error al configurar idioma es-CL: $e');
    }

    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _inicializado = true;
  }

  Future<void> hablar(String texto) async {
    await _inicializar();

    try {
      await _tts.stop();
      final resultado = await _tts.speak(texto);
      // ignore: avoid_print
      print('Resultado de speak("$texto"): $resultado');
    } catch (e) {
      // ignore: avoid_print
      print('Error al hablar: $e');
    }
  }

  Future<void> detener() async {
    await _tts.stop();
  }
}