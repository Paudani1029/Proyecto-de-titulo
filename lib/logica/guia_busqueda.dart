import '../models/catalogo_clases.dart';
import '../models/clases_coco.dart' show NombreClase;
import '../models/deteccion.dart';
import 'generador_respuestas.dart' show umbralCerca, umbralLejos, umbralMuyCerca;

/// Lo que la guía quiere hacer después de mirar una foto.
class PasoGuia {
  const PasoGuia({this.mensaje, this.terminada = false});

  /// Texto a decir en voz alta, o null si conviene quedarse callada.
  final String? mensaje;

  /// true cuando la búsqueda acabó (se encontró el objeto o se rindió).
  final bool terminada;
}

/// Pulso tipo "sensor de retroceso": más rápido mientras más cerca está el objeto.
class SenalProximidad {
  const SenalProximidad({required this.intervalo, required this.centrado});

  /// Tiempo entre un pulso y el siguiente.
  final Duration intervalo;

  /// true si el objeto está al centro: pulso fuerte y agudo.
  /// false si está a un lado: pulso suave y grave.
  final bool centrado;

  /// Pulso más lento (objeto lejos) y más rápido (objeto al alcance).
  static const int msLejos = 1000;
  static const int msCerca = 150;

  /// Convierte el tamaño del objeto en la foto en un ritmo de pulsos.
  factory SenalProximidad.desde({required double alto, required double x}) {
    final p = ((alto - umbralLejos) / (umbralMuyCerca - umbralLejos))
        .clamp(0.0, 1.0);
    return SenalProximidad(
      intervalo: Duration(milliseconds: (msLejos - (msLejos - msCerca) * p).round()),
      centrado: x >= 0.4 && x <= 0.6,
    );
  }
}

/// Guía continua para encontrar un objeto: "un poco a la izquierda",
/// "sigue derecho", "extiende la mano"...
///
/// No toca la cámara ni la voz: recibe las detecciones de cada foto y la hora,
/// y devuelve qué decir. Así se puede probar sin teléfono.
class GuiaBusqueda {
  GuiaBusqueda({required this.clase, required DateTime inicio})
      : nombre = nombreDeClase(clase) ?? NombreClase(clase, 'el'),
        _ultimoAvistamiento = inicio,
        _ultimoHablado = inicio;

  /// Clase del detector que se busca (ej. 'bottle').
  final String clase;
  final NombreClase nombre;

  // --- Ajustes (calibrar con pruebas reales) ---

  /// Fotos seguidas sin verlo antes de decir "ya no lo veo" (evita falsas alarmas).
  static const int fallosParaPerderlo = 3;

  /// Fotos seguidas "centrado y muy cerca" para darlo por encontrado.
  static const int confirmacionesParaEncontrar = 2;

  /// Pausa mínima entre dos instrucciones distintas (la voz es lenta).
  static const Duration pausaEntreMensajes = Duration(milliseconds: 2500);

  /// Cada cuánto repetir la MISMA instrucción, para que sepa que sigo guiando.
  static const Duration repetirInstruccion = Duration(seconds: 5);

  /// Cada cuánto dar una pista mientras todavía no lo ve.
  static const Duration repetirPista = Duration(seconds: 7);

  /// Si pasa este tiempo sin verlo, la búsqueda se termina.
  static const Duration tiempoMaximoSinVerlo = Duration(seconds: 45);

  // --- Estado ---
  bool _visto = false;
  int _fallos = 0;
  int _confirmaciones = 0;
  double? _ultimaX;
  DateTime _ultimoAvistamiento;
  DateTime _ultimoHablado;
  String? _ultimaInstruccion;
  int _pista = 0;
  SenalProximidad? _senal;
  bool _encontrado = false;

  /// true si la búsqueda terminó porque lo encontró (y no porque se rindió).
  bool get encontrado => _encontrado;

  /// Ritmo de vibración/pitido según la última foto, o null si no lo ve.
  SenalProximidad? get senal => _senal;

  String get _el => nombre.conArticulo;

  /// Lo primero que se dice al empezar.
  String get mensajeInicial =>
      'Busco $_el. Apunta el teléfono hacia adelante y gíralo despacio. '
      'Di: para, cuando quieras terminar.';

  /// Analiza una foto nueva.
  PasoGuia procesar(List<Deteccion> detecciones, DateTime ahora) {
    final objetivo = _elegir(detecciones);

    if (objetivo == null) return _sinVerlo(ahora);

    final primeraVez = !_visto;
    final recuperado = _visto && _fallos >= fallosParaPerderlo;
    _visto = true;
    _fallos = 0;
    _ultimaX = objetivo.centroX;
    _ultimoAvistamiento = ahora;

    final x = objetivo.centroX ?? 0.5;
    final centrado = x >= 0.4 && x <= 0.6;
    _senal = SenalProximidad.desde(alto: objetivo.alto, x: x);

    // ¿Ya lo tiene al alcance?
    if (centrado && objetivo.alto >= umbralMuyCerca) {
      _confirmaciones++;
      if (_confirmaciones >= confirmacionesParaEncontrar) {
        _senal = null;
        _encontrado = true;
        return PasoGuia(
          mensaje: 'Encontraste $_el. Está justo frente a ti, '
              'al alcance de tu mano.',
          terminada: true,
        );
      }
    } else {
      _confirmaciones = 0;
    }

    final instruccion = _instruccion(x, objetivo.alto);

    // Al verlo por primera vez (o al recuperarlo) se avisa de inmediato
    if (primeraVez || recuperado) {
      return _hablar('Veo $_el. $instruccion', instruccion, ahora);
    }

    final distinta = instruccion != _ultimaInstruccion;
    final espera = ahora.difference(_ultimoHablado);
    if ((distinta && espera >= pausaEntreMensajes) ||
        (!distinta && espera >= repetirInstruccion)) {
      return _hablar(instruccion, instruccion, ahora);
    }
    return const PasoGuia();
  }

  /// Si hay varios, se guía hacia el más grande (normalmente el más cercano).
  Deteccion? _elegir(List<Deteccion> detecciones) {
    Deteccion? mejor;
    for (final d in detecciones) {
      if (d.clase != clase) continue;
      if (mejor == null || d.area > mejor.area) mejor = d;
    }
    return mejor;
  }

  /// Qué hacer según dónde está en la foto y qué tan grande se ve.
  /// Si está a la izquierda de la foto, hay que girar el teléfono a la izquierda.
  String _instruccion(double x, double alto) {
    if (x < 0.2) return 'Gira a la izquierda.';
    if (x < 0.4) return 'Un poco a la izquierda.';
    if (x > 0.8) return 'Gira a la derecha.';
    if (x > 0.6) return 'Un poco a la derecha.';

    if (alto >= umbralMuyCerca) return 'Está justo enfrente. Extiende la mano.';
    if (alto >= umbralCerca) return 'Está enfrente, cerca. Avanza despacio.';
    return 'Está enfrente, más lejos. Camina derecho despacio.';
  }

  PasoGuia _sinVerlo(DateTime ahora) {
    _confirmaciones = 0;
    _fallos++;
    // Una foto fallida suelta no corta el pulso (el detector a veces parpadea)
    if (_fallos >= fallosParaPerderlo) _senal = null;

    if (ahora.difference(_ultimoAvistamiento) >= tiempoMaximoSinVerlo) {
      _senal = null;
      return PasoGuia(
        mensaje: 'No logré encontrar $_el. Puedes buscar en otro lugar '
            'y pedirme de nuevo que lo busque.',
        terminada: true,
      );
    }

    // Lo tenía y lo perdió: que vuelva hacia donde estaba
    if (_visto && _fallos == fallosParaPerderlo) {
      final x = _ultimaX ?? 0.5;
      final hacia = x < 0.4
          ? 'Vuelve despacio hacia la izquierda.'
          : x > 0.6
              ? 'Vuelve despacio hacia la derecha.'
              : 'Vuelve a apuntar donde estaba.';
      return _hablar('Ya no veo $_el. $hacia', null, ahora);
    }

    // Todavía no lo ve: pistas de vez en cuando
    if ((!_visto || _fallos > fallosParaPerderlo) &&
        ahora.difference(_ultimoHablado) >= repetirPista) {
      const pistas = [
        'Gira el teléfono despacio de un lado a otro.',
        'Prueba apuntando más abajo, hacia la mesa o el suelo.',
        'Aleja un poco el teléfono para ver más espacio.',
      ];
      final pista = pistas[_pista++ % pistas.length];
      return _hablar('Todavía no veo $_el. $pista', null, ahora);
    }
    return const PasoGuia();
  }

  PasoGuia _hablar(String mensaje, String? instruccion, DateTime ahora) {
    _ultimaInstruccion = instruccion;
    _ultimoHablado = ahora;
    return PasoGuia(mensaje: mensaje);
  }
}
