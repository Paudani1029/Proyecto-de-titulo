import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Escucha UNA frase del usuario (cuando toca el círculo) y la devuelve como texto.
///
/// Notas del paquete speech_to_text en Android:
/// - Suena un pitido corto al empezar y al terminar de escuchar. Le sirve de aviso
///   sonoro al usuario ("ya te escucho").
/// - Por defecto usa el reconocedor de Google, que normalmente necesita Internet.
///   Para que funcione sin conexión hay que descargar el idioma español para
///   reconocimiento de voz sin conexión en la configuración de voz del teléfono.
class ComandosVozService {
  final SpeechToText _stt = SpeechToText();

  bool _inicializado = false;
  bool _disponible = false;
  String? _idioma;
  String _ultimasPalabras = '';
  Completer<String?>? _espera;

  /// Prepara el reconocedor y pide el permiso del micrófono (solo la primera vez).
  /// Devuelve false si no hay permiso o el teléfono no tiene reconocimiento de voz.
  Future<bool> preparar() async {
    if (_inicializado) return _disponible;
    _inicializado = true;

    try {
      _disponible = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('Voz: error ${error.errorMsg}');
          _terminar(null);
        },
        onStatus: (String estado) {
          debugPrint('Voz: estado $estado');
          // 'done' llega cuando ya terminó de entregar resultados
          if (estado == 'done') _terminar(_ultimasPalabras);
        },
      );
      if (_disponible) await _elegirIdioma();
    } catch (e) {
      debugPrint('Voz: no se pudo inicializar: $e');
      _disponible = false;
    }
    return _disponible;
  }

  /// Prefiere español de Chile; si no hay, otro español.
  Future<void> _elegirIdioma() async {
    final locales = await _stt.locales();

    String? buscar(bool Function(String) condicion) {
      for (final l in locales) {
        final id = l.localeId.replaceAll('-', '_').toLowerCase();
        if (condicion(id)) return l.localeId;
      }
      return null;
    }

    _idioma = buscar((id) => id == 'es_cl') ??
        buscar((id) => id == 'es_us') ??
        buscar((id) => id == 'es_419') ??
        buscar((id) => id.startsWith('es'));

    debugPrint('Voz: idioma de reconocimiento = $_idioma');
  }

  void _terminar(String? texto) {
    final espera = _espera;
    if (espera == null || espera.isCompleted) return;
    final limpio = texto?.trim();
    espera.complete((limpio == null || limpio.isEmpty) ? null : limpio);
  }

  /// Escucha una frase. Devuelve null si no se entendió nada o se canceló.
  Future<String?> escucharUnaVez() async {
    if (!await preparar()) return null;
    if (_stt.isListening) await _stt.cancel();

    _ultimasPalabras = '';
    final espera = Completer<String?>();
    _espera = espera;

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          _ultimasPalabras = r.recognizedWords;
          if (r.finalResult) _terminar(r.recognizedWords);
        },
        localeId: _idioma,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Voz: error al escuchar: $e');
      _terminar(null);
    }

    return espera.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _stt.cancel();
        return _ultimasPalabras.trim().isEmpty ? null : _ultimasPalabras;
      },
    );
  }

  /// Corta la escucha en curso (el usuario tocó de nuevo o hubo una alerta).
  Future<void> cancelar() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    _terminar(null);
  }

  void liberar() {
    _stt.cancel();
  }
}
