import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class VozService {
  FlutterTts flutterTts = FlutterTts();
  bool _inicializado = false;
  

  Future<void> _inicializar() async {
    
    List<dynamic> idiomas = await flutterTts.getLanguages;
    debugPrint('Idiomas disponibles: $idiomas');

    if (_inicializado) return;

      await flutterTts.setLanguage('es-CL');
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      _inicializado = true;
  }

  Future<void> hablar(String texto) async {
    await _inicializar();
    await flutterTts.stop();
    final resultado = await flutterTts.speak(texto);
    print('Resultado de speak: $resultado');
  }

  Future<void> detener() async {
    await flutterTts.stop();
  }
  
}