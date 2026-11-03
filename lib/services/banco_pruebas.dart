import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'detector_onnx.dart';

/// Temperatura del teléfono, leída desde Android (ver MainActivity.kt).
class LecturaTermica {
  const LecturaTermica({
    required this.estado,
    required this.margen,
    required this.bateriaC,
  });

  /// PowerManager.getCurrentThermalStatus(): 0 = normal ... 6 = apagado.
  /// -1 si el teléfono no lo informa (Android < 10).
  final int estado;

  /// PowerManager.getThermalHeadroom(10 s): 1.0 = a punto de limitar velocidad.
  /// null si el teléfono no lo informa (Android < 11 o sin soporte).
  final double? margen;

  /// Temperatura de la batería en °C. Disponible en todos los teléfonos.
  final double? bateriaC;

  static const _nombresEstado = [
    'normal',
    'leve',
    'moderado',
    'severo',
    'crítico',
    'emergencia',
    'apagado',
  ];

  String get estadoTexto =>
      estado >= 0 && estado < _nombresEstado.length ? _nombresEstado[estado] : '?';
}

/// Estadísticas de una combinación modelo + acelerador.
class ResumenBanco {
  const ResumenBanco({
    required this.etiqueta,
    required this.muestras,
    required this.promedioMs,
    required this.medianaMs,
    required this.p90Ms,
    required this.inferenciaMs,
    required this.prepararMs,
    required this.termica,
    required this.bateriaInicialC,
  });

  final String etiqueta;
  final int muestras;
  final int promedioMs;
  final int medianaMs;
  final int p90Ms;
  final int inferenciaMs;
  final int prepararMs;
  final LecturaTermica? termica;

  /// Temperatura de batería al empezar a medir esta combinación.
  final double? bateriaInicialC;

  String get texto {
    final t = termica;
    final partes = <String>[
      '$etiqueta · $muestras fotos',
      'Total: $promedioMs ms (mediana $medianaMs, p90 $p90Ms)',
      'Modelo: $inferenciaMs ms · Preparar foto: $prepararMs ms',
    ];
    if (t != null) {
      final bat = t.bateriaC;
      final subida = (bat != null && bateriaInicialC != null)
          ? ' (${bat - bateriaInicialC! >= 0 ? '+' : ''}'
              '${(bat - bateriaInicialC!).toStringAsFixed(1)} °C)'
          : '';
      partes.add('Batería: ${bat?.toStringAsFixed(1) ?? '?'} °C$subida · '
          'Estado térmico: ${t.estadoTexto}'
          '${t.margen != null ? ' · margen ${t.margen!.toStringAsFixed(2)}' : ''}');
    }
    return partes.join('\n');
  }
}

/// Mide cuánto tarda cada detección y cómo se calienta el teléfono, para
/// comparar modelos en el teléfono real.
///
/// - Cada 20 fotos imprime un resumen en la consola ("BANCO ...").
/// - Guarda cada medición en un CSV dentro de la caché de la app. Para sacarlo:
///   adb shell run-as com.example.lumina cat cache/lumina_banco.csv > banco.csv
///
/// IMPORTANTE: medir con `flutter run --profile` (o --release). En modo debug
/// Dart corre sin optimizar y los tiempos no sirven para comparar.
class BancoPruebas {
  BancoPruebas._();

  static final BancoPruebas instancia = BancoPruebas._();

  static const MethodChannel _canal = MethodChannel('lumina/termico');
  static const int _maxMuestras = 200;

  /// Último resumen, para mostrarlo en Ajustes.
  final ValueNotifier<ResumenBanco?> resumen = ValueNotifier(null);

  final Map<ConfigDeteccion, List<_Muestra>> _muestras = {};
  final Map<ConfigDeteccion, double?> _bateriaInicial = {};
  LecturaTermica? _ultimaTermica;
  DateTime _ultimaLecturaTermica = DateTime.fromMillisecondsSinceEpoch(0);
  File? _csv;

  Future<LecturaTermica?> leerTermica() async {
    try {
      final m = await _canal.invokeMapMethod<String, dynamic>('estado');
      if (m == null) return null;
      final margen = (m['margen'] as num?)?.toDouble();
      return LecturaTermica(
        estado: (m['estado'] as num?)?.toInt() ?? -1,
        margen: (margen == null || margen.isNaN || margen < 0) ? null : margen,
        bateriaC: (m['bateria'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null; // p. ej. en pruebas o en otra plataforma
    }
  }

  Future<void> registrar({
    required ConfigDeteccion config,
    required int msPreparar,
    required int msInferencia,
    required int msTotal,
    required int objetos,
  }) async {
    // La temperatura cambia lento: basta leerla cada 5 segundos.
    final ahora = DateTime.now();
    if (ahora.difference(_ultimaLecturaTermica) > const Duration(seconds: 5)) {
      _ultimaLecturaTermica = ahora;
      _ultimaTermica = await leerTermica();
    }
    final termica = _ultimaTermica;

    final lista = _muestras.putIfAbsent(config, () => []);
    _bateriaInicial.putIfAbsent(config, () => termica?.bateriaC);
    lista.add(_Muestra(msPreparar, msInferencia, msTotal));
    if (lista.length > _maxMuestras) lista.removeAt(0);

    final r = _resumir(config, lista, termica);
    resumen.value = r;
    if (lista.length % 20 == 0) debugPrint('BANCO ${r.texto.replaceAll('\n', ' | ')}');

    await _escribirCsv(ahora, config, msPreparar, msInferencia, msTotal, objetos, termica);
  }

  /// Borra las mediciones (por ejemplo, al empezar una prueba nueva).
  void reiniciar() {
    _muestras.clear();
    _bateriaInicial.clear();
    resumen.value = null;
  }

  ResumenBanco _resumir(
    ConfigDeteccion config,
    List<_Muestra> lista,
    LecturaTermica? termica,
  ) {
    final totales = lista.map((m) => m.total).toList()..sort();
    int prom(Iterable<int> v) => (v.reduce((a, b) => a + b) / v.length).round();
    int percentil(double p) =>
        totales[((totales.length - 1) * p).round().clamp(0, totales.length - 1)];

    return ResumenBanco(
      etiqueta: config.etiqueta,
      muestras: lista.length,
      promedioMs: prom(totales),
      medianaMs: percentil(0.5),
      p90Ms: percentil(0.9),
      inferenciaMs: prom(lista.map((m) => m.inferencia)),
      prepararMs: prom(lista.map((m) => m.preparar)),
      termica: termica,
      bateriaInicialC: _bateriaInicial[config],
    );
  }

  Future<void> _escribirCsv(
    DateTime hora,
    ConfigDeteccion config,
    int msPreparar,
    int msInferencia,
    int msTotal,
    int objetos,
    LecturaTermica? t,
  ) async {
    try {
      var csv = _csv;
      if (csv == null) {
        csv = File('${Directory.systemTemp.path}/lumina_banco.csv');
        if (!await csv.exists()) {
          await csv.writeAsString(
            'hora,modelo,acelerador,ms_preparar,ms_modelo,ms_total,objetos,'
            'estado_termico,margen_termico,bateria_c\n',
          );
        }
        _csv = csv;
      }
      await csv.writeAsString(
        '${hora.toIso8601String()},${config.modelo.nombre},'
        '${config.acelerador.nombre},$msPreparar,$msInferencia,$msTotal,'
        '$objetos,${t?.estado ?? ''},${t?.margen ?? ''},${t?.bateriaC ?? ''}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('Banco: no se pudo escribir el CSV ($e)');
    }
  }
}

class _Muestra {
  const _Muestra(this.preparar, this.inferencia, this.total);

  final int preparar;
  final int inferencia;
  final int total;
}
