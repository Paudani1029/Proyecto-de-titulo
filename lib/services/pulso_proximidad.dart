import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../logica/guia_busqueda.dart';

/// Preferencias del usuario (las cambia la hoja de Ajustes).
final ValueNotifier<bool> vibracionBusqueda = ValueNotifier<bool>(true);
final ValueNotifier<bool> pitidoBusqueda = ValueNotifier<bool>(true);

/// Vibración y pitido tipo "sensor de retroceso" mientras se busca un objeto:
/// mientras más cerca, más rápido. Al centro: fuerte y agudo. A un lado: suave y grave.
class PulsoProximidad {
  SenalProximidad? _senal;
  Timer? _reloj;
  DateTime _ultimoPulso = DateTime.fromMillisecondsSinceEpoch(0);

  bool _preparado = false;
  bool _hayVibrador = false;
  bool _hayAmplitud = false;
  AudioPlayer? _agudo;
  AudioPlayer? _grave;

  /// Cambia el ritmo. null = silencio (no ve el objeto, o se terminó la búsqueda).
  void actualizar(SenalProximidad? senal) {
    _senal = senal;
    if (senal == null) {
      _reloj?.cancel();
      _reloj = null;
      return;
    }
    unawaited(_preparar());
    // Un reloj corto revisa si ya toca el siguiente pulso; así el ritmo
    // cambia al instante cuando llega una foto nueva.
    _reloj ??= Timer.periodic(const Duration(milliseconds: 40), (_) => _tic());
  }

  void detener() => actualizar(null);

  /// Vibración de festejo al encontrar el objeto.
  Future<void> exito() async {
    detener();
    await _preparar();
    if (vibracionBusqueda.value && _hayVibrador) {
      unawaited(Vibration.vibrate(pattern: [0, 120, 80, 120, 80, 350]));
    }
  }

  Future<void> liberar() async {
    detener();
    await _agudo?.dispose();
    await _grave?.dispose();
  }

  void _tic() {
    final senal = _senal;
    if (senal == null) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoPulso) < senal.intervalo) return;
    _ultimoPulso = ahora;
    _pulsar(senal.centrado);
  }

  void _pulsar(bool centrado) {
    if (vibracionBusqueda.value && _hayVibrador) {
      unawaited(Vibration.vibrate(
        duration: centrado ? 60 : 35,
        amplitude: _hayAmplitud ? (centrado ? 255 : 90) : -1,
      ));
    }
    if (pitidoBusqueda.value) {
      final reproductor = centrado ? _agudo : _grave;
      if (reproductor != null) {
        unawaited(reproductor.stop().then((_) => reproductor.resume()));
      }
    }
  }

  Future<void> _preparar() async {
    if (_preparado) return;
    _preparado = true;

    try {
      _hayVibrador = await Vibration.hasVibrator();
      _hayAmplitud = _hayVibrador && await Vibration.hasAmplitudeControl();
    } catch (e) {
      debugPrint('Vibración no disponible: $e');
    }

    try {
      _agudo = await _crearPitido('lumina_pitido_agudo.wav', frecuencia: 1320);
      _grave = await _crearPitido('lumina_pitido_grave.wav', frecuencia: 660);
    } catch (e) {
      debugPrint('Pitido no disponible: $e');
    }
  }

  /// Genera el pitido como archivo WAV temporal (no hace falta incluir audios en la app).
  Future<AudioPlayer> _crearPitido(String nombre, {required double frecuencia}) async {
    final archivo = File('${Directory.systemTemp.path}/$nombre');
    await archivo.writeAsBytes(generarPitidoWav(frecuencia: frecuencia));

    final reproductor = AudioPlayer();
    // Mezclarse con la voz de Lumina y con TalkBack, sin pausarlos.
    await reproductor.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await reproductor.setPlayerMode(PlayerMode.lowLatency);
    await reproductor.setVolume(0.6);
    await reproductor.setSource(DeviceFileSource(archivo.path));
    return reproductor;
  }
}

/// Tono corto (WAV, 16 bits, mono) con entrada y salida suaves para que no "chasquee".
Uint8List generarPitidoWav({
  required double frecuencia,
  int milisegundos = 70,
  int muestrasPorSegundo = 22050,
}) {
  final muestras = muestrasPorSegundo * milisegundos ~/ 1000;
  final datos = ByteData(44 + muestras * 2);

  void texto(int pos, String s) {
    for (var i = 0; i < s.length; i++) {
      datos.setUint8(pos + i, s.codeUnitAt(i));
    }
  }

  // Cabecera WAV
  texto(0, 'RIFF');
  datos.setUint32(4, 36 + muestras * 2, Endian.little);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  datos.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  datos.setUint16(20, 1, Endian.little); // PCM
  datos.setUint16(22, 1, Endian.little); // mono
  datos.setUint32(24, muestrasPorSegundo, Endian.little);
  datos.setUint32(28, muestrasPorSegundo * 2, Endian.little);
  datos.setUint16(32, 2, Endian.little);
  datos.setUint16(34, 16, Endian.little);
  texto(36, 'data');
  datos.setUint32(40, muestras * 2, Endian.little);

  final rampa = muestras ~/ 8;
  for (var i = 0; i < muestras; i++) {
    var volumen = 1.0;
    if (i < rampa) volumen = i / rampa;
    if (i > muestras - rampa) volumen = (muestras - i) / rampa;
    final onda = math.sin(2 * math.pi * frecuencia * i / muestrasPorSegundo);
    datos.setInt16(44 + i * 2, (onda * volumen * 0.8 * 32767).round(), Endian.little);
  }
  return datos.buffer.asUint8List();
}
