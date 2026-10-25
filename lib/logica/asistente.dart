import 'dart:async';
import 'dart:io' show File;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/aviso_historial.dart';
import '../models/deteccion.dart';
import '../services/comandos_voz_service.dart';
import '../services/detector_objetos.dart';
import '../services/detector_yolo.dart';
import '../services/fuente_imagen.dart';
import '../services/fuente_imagen_telefono.dart';
import '../services/voz_service.dart';
import 'generador_respuestas.dart';
import 'interprete_comandos.dart';

/// Lo que la pantalla necesita saber para dibujarse.
enum EstadoAsistente { conectando, sinCamara, atento, escuchando, pensando, guiando }

/// Cerebro de Lumina.
///
/// - Se queda EN SILENCIO por defecto.
/// - Habla cuando el usuario toca el círculo y le pregunta algo.
/// - En segundo plano revisa la cámara y avisa SOLO si hay un peligro cercano
///   (vehículos, bicicletas, perros). En modo guía avisa de más cosas.
class Asistente extends ChangeNotifier {
  Asistente({
    FuenteImagen? fuente,
    DetectorObjetos? detector,
    VozService? voz,
    ComandosVozService? comandos,
  })  : _fuente = fuente ?? FuenteImagenTelefono(),
        _detector = detector ?? DetectorYolo(),
        _voz = voz ?? VozService(),
        _comandos = comandos ?? ComandosVozService();

  final FuenteImagen _fuente;
  final DetectorObjetos _detector;
  final VozService _voz;
  final ComandosVozService _comandos;

  // --- Estado visible ---
  bool _camaraLista = false;
  bool _errorCamara = false;
  bool _escuchando = false; // el micrófono está abierto
  bool _pensando = false; // analizando una foto para responder
  bool _modoGuia = false;
  String _ultimoMensaje = 'Toca el círculo y pregúntame algo.';
  final List<AvisoHistorial> _historial = [];

  bool get errorCamara => _errorCamara;
  bool get modoGuia => _modoGuia;
  String get ultimoMensaje => _ultimoMensaje;
  List<AvisoHistorial> get historial => List.unmodifiable(_historial);

  EstadoAsistente get estado {
    if (_errorCamara) return EstadoAsistente.sinCamara;
    if (!_camaraLista) return EstadoAsistente.conectando;
    if (_escuchando) return EstadoAsistente.escuchando;
    if (_pensando) return EstadoAsistente.pensando;
    if (_modoGuia) return EstadoAsistente.guiando;
    return EstadoAsistente.atento;
  }

  /// Para la vista previa (solo existe con la cámara del teléfono).
  CameraController? get controladorCamara {
    final f = _fuente;
    return f is FuenteImagenTelefono ? f.controller : null;
  }

  // --- Interno ---
  bool _activo = true; // pasa a false al cerrar la pantalla
  bool _cancelado = false;
  Future<void> _cola = Future<void>.value();
  final Map<String, DateTime> _ultimasAlertas = {};
  bool _huboAlerta = false;
  int _libres = 0;

  void _notificar() {
    if (_activo) notifyListeners();
  }

  @override
  void dispose() {
    _activo = false;
    _comandos.liberar();
    _fuente.desconectar();
    _detector.liberar();
    _voz.detener();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Arranque
  // ------------------------------------------------------------------

  Future<void> iniciar() async {
    final ok = await _fuente.conectar();
    if (!_activo) {
      _fuente.desconectar();
      return;
    }
    if (!ok) {
      _errorCamara = true;
      _decir('No pude abrir la cámara. Revisa el permiso de la aplicación.');
      return;
    }
    _camaraLista = true;
    _decir('Lumina lista. Toca el círculo para hablarme.');
    unawaited(_bucleVigilancia());
  }

  // ------------------------------------------------------------------
  // Hablar
  // ------------------------------------------------------------------

  /// Dice algo en voz alta y lo deja guardado como último mensaje.
  void _decir(String texto) {
    _ultimoMensaje = texto;
    _historial.insert(0, AvisoHistorial(texto, DateTime.now()));
    if (_historial.length > 20) _historial.removeLast();
    _notificar();
    unawaited(_voz.hablar(texto));
  }

  void repetirUltimo() {
    unawaited(_voz.hablar(_ultimoMensaje));
  }

  // ------------------------------------------------------------------
  // Cámara + detector (una sola foto a la vez)
  // ------------------------------------------------------------------

  Future<T> _enCola<T>(Future<T> Function() tarea) {
    final resultado = Completer<T>();
    _cola = _cola.then((_) async {
      try {
        resultado.complete(await tarea());
      } catch (e, s) {
        resultado.completeError(e, s);
      }
    });
    return resultado.future;
  }

  /// Toma una foto, busca objetos y BORRA la foto (no se guarda nada).
  Future<List<Deteccion>?> _analizar() {
    return _enCola<List<Deteccion>?>(() async {
      final ruta = await _fuente.capturarFoto();
      if (ruta == null) return null;
      try {
        return await _detector.detectar(ruta);
      } catch (e) {
        debugPrint('Error al detectar: $e');
        return null;
      } finally {
        try {
          await File(ruta).delete();
        } catch (_) {}
      }
    });
  }

  // ------------------------------------------------------------------
  // Comandos de voz
  // ------------------------------------------------------------------

  /// El usuario toca el círculo: se abre el micrófono (o se cancela si ya estaba abierto).
  Future<void> tocarCirculo() async {
    if (_errorCamara || _pensando) return;

    if (_escuchando) {
      _cancelado = true;
      await _comandos.cancelar();
      return;
    }

    if (!await _comandos.preparar()) {
      _decir('No puedo usar el micrófono. Revisa el permiso de la aplicación.');
      return;
    }

    await _voz.detener(); // que no se escuche a sí misma
    _cancelado = false;
    _escuchando = true;
    _notificar();

    final frase = await _comandos.escucharUnaVez();

    _escuchando = false;
    if (_cancelado) {
      _cancelado = false;
      _notificar();
      return;
    }
    _notificar();

    if (frase == null) {
      _decir('No te escuché. Toca el círculo y vuelve a intentarlo.');
      return;
    }
    debugPrint('Comando oído: "$frase"');
    await _ejecutar(interpretarComando(frase));
  }

  Future<void> _ejecutar(Comando c) async {
    switch (c.tipo) {
      case TipoComando.queHayEnfrente:
        await _responderConFoto(describirEscena);
      case TipoComando.dondeEsta:
        if (c.clase == null) {
          // Objeto desconocido o no dicho: se responde sin gastar una foto
          _decir(responderBusqueda(
            clase: null,
            objetoPedido: c.objetoPedido,
            detecciones: const [],
          ));
        } else {
          await _responderConFoto((dets) => responderBusqueda(
                clase: c.clase,
                objetoPedido: c.objetoPedido,
                detecciones: dets,
              ));
        }
      case TipoComando.guiarCamino:
        _activarGuia();
      case TipoComando.detenerGuia:
        _desactivarGuia();
      case TipoComando.repetir:
        repetirUltimo();
      case TipoComando.ayuda:
        _decir(textoAyudaVoz);
      case TipoComando.irADestino:
        _decir('Todavía no puedo llevarte a un lugar. '
            'Si quieres, puedo avisarte de obstáculos: di, guía mi camino.');
      case TipoComando.desconocido:
        _decir('No entendí. Puedes decir: qué tengo enfrente, '
            'dónde está la botella, o guía mi camino.');
    }
  }

  Future<void> _responderConFoto(
    String Function(List<Deteccion>) armarRespuesta,
  ) async {
    _pensando = true;
    _notificar();
    final detecciones = await _analizar();
    _pensando = false;

    if (detecciones == null) {
      _decir('No pude tomar la imagen. Inténtalo de nuevo.');
      return;
    }
    _decir(armarRespuesta(detecciones));
  }

  // ------------------------------------------------------------------
  // Modo guía y vigilancia de peligros
  // ------------------------------------------------------------------

  void alternarGuia() {
    if (_modoGuia) {
      _desactivarGuia();
    } else {
      _activarGuia();
    }
  }

  void _activarGuia() {
    if (_errorCamara) return;
    _modoGuia = true;
    _huboAlerta = false;
    _libres = 0;
    _ultimasAlertas.clear();
    _decir(textoActivarGuia);
  }

  void _desactivarGuia() {
    if (!_modoGuia) {
      _decir('La guía no estaba activa.');
      return;
    }
    _modoGuia = false;
    _decir('Guía terminada. Sigo atento a vehículos cercanos.');
  }

  /// Revisa la cámara una y otra vez. Cada vuelta empieza cuando termina la anterior,
  /// así nunca se acumulan análisis aunque el teléfono sea lento.
  Future<void> _bucleVigilancia() async {
    while (_activo) {
      try {
        if (!_pensando) await _revisarPeligros();
      } catch (e) {
        debugPrint('Vigilancia: $e');
      }
      await Future<void>.delayed(
        Duration(milliseconds: _modoGuia ? 400 : 1200),
      );
    }
  }

  Future<void> _revisarPeligros() async {
    final detecciones = await _analizar();
    if (detecciones == null || !_activo) return;

    final alertas = evaluarRiesgos(detecciones, modoGuia: _modoGuia);
    final ahora = DateTime.now();

    // No repetir el mismo aviso durante 8 segundos
    final nuevas = alertas.where((a) {
      final ultima = _ultimasAlertas[a.clave];
      return ultima == null ||
          ahora.difference(ultima) > const Duration(seconds: 8);
    }).toList();

    if (nuevas.isNotEmpty) {
      for (final a in nuevas) {
        _ultimasAlertas[a.clave] = ahora;
      }
      _huboAlerta = true;
      _libres = 0;

      // La seguridad va primero: si estaba escuchando, se corta para avisar
      if (_escuchando) {
        _cancelado = true;
        await _comandos.cancelar();
      }
      _decir(nuevas.take(2).map((a) => a.mensaje).join(' '));
    } else if (alertas.isNotEmpty) {
      _libres = 0; // el peligro sigue ahí, pero ya se avisó
    } else {
      _libres++;
      if (_modoGuia && _huboAlerta && _libres >= 2) {
        _huboAlerta = false;
        _decir('El frente está libre de obstáculos conocidos.');
      }
    }
  }
}
