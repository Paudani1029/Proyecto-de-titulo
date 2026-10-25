import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/deteccion.dart';
import 'detector_objetos.dart';

/// Detecta objetos con YOLO (modelo "nano", el más liviano).
///
/// OJO: el formato exacto de lo que devuelve `predict` no está documentado en el
/// README del plugin, así que aquí se lee de forma tolerante y la primera vez se
/// imprime el resultado crudo en la consola ("YOLO resultado crudo: ...").
/// Si las posiciones salen raras, ese log dice qué ajustar.
class DetectorYolo implements DetectorObjetos {
  DetectorYolo({this.confianzaMinima = 0.5});

  final double confianzaMinima;

  final YOLO _yolo = YOLO(modelPath: 'yolo26n');
  bool _modeloCargado = false;
  bool _primeraVez = true;

  Future<void> _cargarModelo() async {
    if (_modeloCargado) return;
    // La primera vez descarga el modelo (necesita Internet); luego queda en caché.
    await _yolo.loadModel();
    _modeloCargado = true;
  }

  /// Lee un campo de un mapa probando varios nombres posibles.
  dynamic _campo(dynamic dato, List<String> claves) {
    if (dato is! Map) return null;
    for (final clave in claves) {
      if (dato.containsKey(clave)) return dato[clave];
    }
    return null;
  }

  double? _numero(dynamic valor) => valor is num ? valor.toDouble() : null;

  double _entre0y1(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  Future<({double ancho, double alto})> _medidas(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final cuadro = await codec.getNextFrame();
    final medidas = (
      ancho: cuadro.image.width.toDouble(),
      alto: cuadro.image.height.toDouble(),
    );
    cuadro.image.dispose();
    codec.dispose();
    return medidas;
  }

  @override
  Future<List<Deteccion>> detectar(String rutaFoto) async {
    final reloj = Stopwatch()..start();
    await _cargarModelo();

    final bytes = await File(rutaFoto).readAsBytes();
    final resultado = await _yolo.predict(bytes);

    if (_primeraVez) {
      debugPrint('YOLO resultado crudo: $resultado');
      _primeraVez = false;
    }

    final cajas = resultado['boxes'];
    if (cajas is! List) {
      debugPrint('YOLO: formato de resultado inesperado');
      return const [];
    }

    ({double ancho, double alto})? medidas; // solo si hace falta (coordenadas en píxeles)
    final detecciones = <Deteccion>[];

    for (final caja in cajas) {
      final nombre = _campo(caja, ['class', 'className', 'label', 'name']);
      final confianza = _numero(_campo(caja, ['confidence', 'conf']));
      if (nombre == null || confianza == null) continue;
      if (confianza < confianzaMinima) continue;

      // 1) Coordenadas normalizadas (0 a 1), si el plugin las entrega
      double? x1 = _numero(_campo(caja, ['x1_norm']));
      double? y1 = _numero(_campo(caja, ['y1_norm']));
      double? x2 = _numero(_campo(caja, ['x2_norm']));
      double? y2 = _numero(_campo(caja, ['y2_norm']));

      // 2) Si no, coordenadas en píxeles -> se dividen por el tamaño de la foto
      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        final px1 = _numero(_campo(caja, ['x1']));
        final py1 = _numero(_campo(caja, ['y1']));
        final px2 = _numero(_campo(caja, ['x2']));
        final py2 = _numero(_campo(caja, ['y2']));

        if (px1 != null && py1 != null && px2 != null && py2 != null) {
          final yaNormalizadas = [px1, py1, px2, py2].every((v) => v <= 1.5);
          if (yaNormalizadas) {
            x1 = px1;
            y1 = py1;
            x2 = px2;
            y2 = py2;
          } else {
            medidas ??= await _medidas(bytes);
            x1 = px1 / medidas.ancho;
            x2 = px2 / medidas.ancho;
            y1 = py1 / medidas.alto;
            y2 = py2 / medidas.alto;
          }
        }
      }

      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        // Sin posición: igual sirve para "¿qué hay?", no para alertas.
        detecciones.add(Deteccion(
          clase: nombre.toString().toLowerCase(),
          confianza: confianza,
        ));
        continue;
      }

      x1 = _entre0y1(x1);
      x2 = _entre0y1(x2);
      y1 = _entre0y1(y1);
      y2 = _entre0y1(y2);

      detecciones.add(Deteccion(
        clase: nombre.toString().toLowerCase(),
        confianza: confianza,
        centroX: (x1 + x2) / 2,
        alto: (y2 - y1).abs(),
        ancho: (x2 - x1).abs(),
      ));
    }

    debugPrint('YOLO tardó ${reloj.elapsedMilliseconds} ms, '
        '${detecciones.length} objetos');

    detecciones.sort((a, b) => b.area.compareTo(a.area));
    return detecciones;
  }

  @override
  void liberar() {}
}
