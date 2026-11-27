import 'dart:async';
import 'dart:io' show File;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/aviso_historial.dart';
import '../models/deteccion.dart';
import '../services/comandos_voz_service.dart';
import '../services/detector_objetos.dart';
import '../services/detector_onnx.dart';
import '../services/fuente_imagen.dart';
import '../services/fuente_imagen_esp32.dart';
import '../services/fuente_imagen_telefono.dart';
import '../services/preferencias_camara.dart';
import '../services/pulso_proximidad.dart';
import '../services/voz_service.dart';
import 'generador_respuestas.dart';
import 'guia_busqueda.dart';
import 'interprete_comandos.dart';

/// Lo que la pantalla necesita saber para dibujarse.
enum EstadoAsistente {
  conectando,
  sinCamara,
  atento,
  escuchando,
  pensando,
  buscando,
  guiando,
}

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
    PulsoProximidad? pulso,
  })  : _fuente = fuente ?? FuenteImagenTelefono(),
        _fuenteFija = fuente != null,
        _pulso = pulso ?? PulsoProximidad(),
        _detector = detector ?? DetectorOnnx(),
        _voz = voz ?? VozService(),
        _comandos = comandos ?? ComandosVozService();

  FuenteImagen _fuente; // cambia si el usuario elige otra cámara en Ajustes
  final bool _fuenteFija; // la pasaron al crear el asistente (pruebas)
  final DetectorObjetos _detector;
  final VozService _voz;
  final ComandosVozService _comandos;
  final PulsoProximidad _pulso;

  // --- Estado visible ---
  bool _camaraLista = false;
  bool _errorCamara = false;
  bool _escuchando = false; // el micrófono está abierto
  bool _pensando = false; // analizando una foto para responder
  bool _modoGuia = false;
  GuiaBusqueda? _busqueda; // no es null mientras guía hacia un objeto
  String _ultimoMensaje = 'Toca el círculo y pregúntame algo.';
  final List<AvisoHistorial> _historial = [];

  bool get errorCamara => _errorCamara;
  bool get modoGuia => _modoGuia;
  bool get buscando => _busqueda != null;

  /// Nombre de lo que se está buscando ("la botella"), o null.
  String? get objetoBuscado => _busqueda?.nombre.conArticulo;
  String get ultimoMensaje => _ultimoMensaje;
  List<AvisoHistorial> get historial => List.unmodifiable(_historial);

  EstadoAsistente get estado {
    if (_errorCamara) return EstadoAsistente.sinCamara;
    if (!_camaraLista) return EstadoAsistente.conectando;
    if (_escuchando) return EstadoAsistente.escuchando;
    if (_pensando) return EstadoAsistente.pensando;
    if (_busqueda != null) return EstadoAsistente.buscando;
    if (_modoGuia) return EstadoAsistente.guiando;
    return EstadoAsistente.atento;
  }

  /// Lumina Cam (XIAO ESP32S3 Sense), si es la cámara en uso.
  FuenteImagenEsp32? get camaraEsp32 {
    final f = _fuente;
    return f is FuenteImagenEsp32 ? f : null;
  }

  /// true mientras se conecta o cambia de cámara.
  bool get cambiandoCamara => _cambiandoCamara;

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
  bool _bucleIniciado = false;
  bool _cambiandoCamara = false;
  int _fotosFallidas = 0; // seguidas; sirve para notar si se cayó la cámara
  bool _avisoSinConexion = false;

  void _notificar() {
    if (_activo) notifyListeners();
  }

  @override
  void dispose() {
    _activo = false;
    unawaited(_pulso.liberar());
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
    if (!_fuenteFija && usarCamaraEsp32.value) {
      await usarCamara(esp32: true, alIniciar: true);
      return;
    }

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
    _iniciarBucle();
  }

  void _iniciarBucle() {
    if (_bucleIniciado) return;
    _bucleIniciado = true;
    unawaited(_bucleVigilancia());
  }

  // ------------------------------------------------------------------
  // Elegir cámara: la del teléfono o Lumina Cam (XIAO ESP32S3 Sense)
  // ------------------------------------------------------------------

  /// Cambia de cámara. Si Lumina Cam no responde, sigue con la del teléfono
  /// (sin cámara la app no sirve, y el usuario podría no notar el problema).
  /// La preferencia se guarda igual, para volver a intentarlo la próxima vez.
  Future<void> usarCamara({required bool esp32, bool alIniciar = false}) async {
    if (_cambiandoCamara || _fuenteFija) return;
    usarCamaraEsp32.value = esp32;

    _cambiandoCamara = true;
    _camaraLista = false;
    _errorCamara = false;
    _notificar();

    final FuenteImagen nueva = esp32
        ? FuenteImagenEsp32(
            ipConocida: ipCamaraEsp32.value,
            alEncontrar: (ip) => ipCamaraEsp32.value = ip,
          )
        : FuenteImagenTelefono();
    await _reemplazarFuente(nueva);

    var ok = await nueva.conectar();
    if (!_activo) return;

    String mensaje;
    if (ok) {
      mensaje = esp32
          ? 'Cámara Lumina conectada.'
          : 'Usando la cámara del teléfono.';
    } else if (esp32) {
      mensaje = 'No encontré la cámara Lumina. Revisa que esté encendida y '
          'conectada al punto de acceso de tu teléfono. '
          'Mientras tanto uso la cámara del teléfono.';
      final telefono = FuenteImagenTelefono();
      await _reemplazarFuente(telefono);
      ok = await telefono.conectar();
      if (!_activo) return;
    } else {
      mensaje = 'No pude abrir la cámara. Revisa el permiso de la aplicación.';
    }
    if (alIniciar && ok) mensaje += ' Lumina lista. Toca el círculo para hablarme.';

    _cambiandoCamara = false;
    _camaraLista = ok;
    _errorCamara = !ok;
    _fotosFallidas = 0;
    _avisoSinConexion = false;
    _decir(mensaje);
    if (ok) _iniciarBucle();
  }

  /// Cambia la fuente dentro de la cola, así ninguna foto queda a medio tomar.
  Future<void> _reemplazarFuente(FuenteImagen nueva) async {
    final anterior = await _enCola(() async {
      final a = _fuente;
      _fuente = nueva;
      return a;
    });
    anterior.desconectar();
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
      _registrarCaptura(ruta != null);
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

  /// Avisa si la cámara deja de mandar fotos (p. ej. Lumina Cam se apagó o quedó
  /// lejos del teléfono) y también cuando vuelve.
  void _registrarCaptura(bool ok) {
    if (!_camaraLista || _cambiandoCamara) return;
    if (ok) {
      _fotosFallidas = 0;
      if (_avisoSinConexion) {
        _avisoSinConexion = false;
        _decir('La cámara volvió a conectarse.');
      }
      return;
    }
    _fotosFallidas++;
    if (_fotosFallidas == 5 && !_avisoSinConexion) {
      _avisoSinConexion = true;
      _decir(camaraEsp32 != null
          ? 'Perdí la conexión con la cámara Lumina. Revisa que esté encendida '
              'y cerca del teléfono. Te aviso cuando vuelva.'
          : 'No puedo tomar fotos con la cámara. Te aviso cuando vuelva.');
    }
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
    _pulso.detener(); // ni los pitidos; vuelven con la próxima foto
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
        if (c.clase == null || !_detector.conoce(c.clase!)) {
          // Objeto desconocido, no dicho o que el modelo actual no sabe detectar:
          // se responde sin gastar una foto
          _decir(responderBusqueda(
            clase: null,
            objetoPedido: c.objetoPedido,
            detecciones: const [],
          ));
        } else {
          _iniciarBusqueda(c.clase!);
        }
      case TipoComando.guiarCamino:
        _activarGuia();
      case TipoComando.detenerGuia:
        // "Para" corta primero la búsqueda; si no había, la guía de camino
        if (_busqueda != null) {
          detenerBusqueda();
        } else {
          _desactivarGuia();
        }
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
  // Guía para encontrar un objeto ("¿dónde está la botella?")
  // ------------------------------------------------------------------

  void _iniciarBusqueda(String clase) {
    // Una búsqueda nueva reemplaza a la anterior
    final guia = GuiaBusqueda(clase: clase, inicio: DateTime.now());
    _busqueda = guia;
    _pulso.detener();
    _decir(guia.mensajeInicial);
  }

  /// Termina la búsqueda (comando "para" o botón de la pantalla).
  void detenerBusqueda() {
    if (_busqueda == null) return;
    _busqueda = null;
    _pulso.detener();
    _decir('Búsqueda terminada.');
  }

  void _avanzarBusqueda(List<Deteccion> detecciones) {
    final guia = _busqueda;
    if (guia == null) return;

    final paso = guia.procesar(detecciones, DateTime.now());
    if (paso.terminada) {
      _busqueda = null;
      if (guia.encontrado) {
        unawaited(_pulso.exito());
      } else {
        _pulso.detener();
      }
    } else {
      _pulso.actualizar(guia.senal);
    }
    if (paso.mensaje != null) {
      _decir(paso.mensaje!);
    } else if (paso.terminada) {
      _notificar();
    }
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
        if (!_pensando) await _revisarEscena();
      } catch (e) {
        debugPrint('Vigilancia: $e');
      }
      final pausa = _busqueda != null
          ? 250
          : _modoGuia
              ? 400
              : 1200;
      await Future<void>.delayed(Duration(milliseconds: pausa));
    }
  }

  /// Una sola foto sirve para los peligros y para la búsqueda.
  Future<void> _revisarEscena() async {
    final detecciones = await _analizar();
    if (detecciones == null || !_activo) return;

    // La seguridad va primero: si hubo aviso de peligro, esta foto no guía
    final avisoPeligro = await _revisarPeligros(detecciones);

    // Mientras el usuario habla no se le dan instrucciones (el micrófono las oiría)
    if (!avisoPeligro && !_escuchando && !_pensando) {
      _avanzarBusqueda(detecciones);
    } else if (_escuchando) {
      _pulso.detener();
    }
  }

  /// Devuelve true si dijo un aviso de peligro.
  Future<bool> _revisarPeligros(List<Deteccion> detecciones) async {

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
      return true;
    } else if (alertas.isNotEmpty) {
      _libres = 0; // el peligro sigue ahí, pero ya se avisó
    } else {
      _libres++;
      if (_modoGuia && _huboAlerta && _libres >= 2) {
        _huboAlerta = false;
        _decir('El frente está libre de obstáculos conocidos.');
        return true;
      }
    }
    return false;
  }
}
