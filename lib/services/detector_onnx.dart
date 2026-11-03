import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/clases_coco.dart';
import '../models/clases_obj365.dart';
import '../models/deteccion.dart';
import 'banco_pruebas.dart';
import 'detector_objetos.dart';

// ---------------------------------------------------------------------------
// Modelos disponibles. Todos tienen licencia Apache 2.0 (uso comercial permitido)
// y fueron preparados con los scripts de herramientas/modelos/ para que tengan
// la MISMA entrada y salida:
//
//   entrada  'imagen'   uint8   [1, 640, 640, 3]  RGB
//   salidas  'cajas'    float32 [1, N, 4]  x1,y1,x2,y2 en píxeles de la entrada
//            'puntajes' float32 [1, N]
//            'clases'   int64   [1, N]     índice en [ModeloDeteccion.clases]
//
// La normalización y el NMS van dentro del modelo, así Dart solo copia píxeles.
// ---------------------------------------------------------------------------

enum ModeloDeteccion {
  /// D-FINE-S entrenado con Objects365: 365 clases (basureros, conos, postes,
  /// señales, muebles, llaves, lentes...). El que usa la app por defecto.
  dfineSObj365(
    nombre: 'D-FINE-S 365',
    asset: 'assets/modelos/dfine-s-obj365-v1.onnx',
    clases: clasesObj365,
    letterbox: false,
    umbral: 0.45,
  ),

  /// D-FINE-S entrenado con COCO: solo 80 clases, pero más preciso en ellas (~48 AP).
  dfineS(
    nombre: 'D-FINE-S 80',
    asset: 'assets/modelos/dfine-s-coco-v2.onnx',
    clases: clasesCoco80,
    letterbox: false, // se entrenó con la foto estirada a 640x640
    umbral: 0.5,
  ),

  /// RTMDet-s: red convolucional clásica, ~44 AP en COCO.
  rtmdetS(
    nombre: 'RTMDet-s',
    asset: 'assets/modelos/rtmdet-s-coco-v1.onnx',
    clases: clasesCoco80,
    letterbox: true, // se entrenó sin deformar la foto (relleno negro)
    umbral: 0.4,
  );

  const ModeloDeteccion({
    required this.nombre,
    required this.asset,
    required this.clases,
    required this.letterbox,
    required this.umbral,
  });

  final String nombre;
  final String asset;

  /// Nombre (clave) de cada índice que entrega el modelo.
  final List<String> clases;

  /// true: la foto se escala sin deformar y se pega arriba a la izquierda.
  /// false: la foto se estira a 640x640.
  final bool letterbox;

  /// Confianza mínima para aceptar un objeto. Cada modelo calibra distinto.
  final double umbral;
}

enum Acelerador {
  /// CPU optimizada (XNNPACK). Funciona en todos los teléfonos.
  cpu('CPU', [OrtProvider.XNNPACK, OrtProvider.CPU]),

  /// NNAPI: usa GPU/NPU si el teléfono la expone. Lo que no soporte cae a CPU.
  nnapi('NNAPI', [OrtProvider.NNAPI, OrtProvider.CPU]);

  const Acelerador(this.nombre, this.proveedores);

  final String nombre;
  final List<OrtProvider> proveedores;
}

/// Qué modelo y acelerador usar. Se puede cambiar en vivo desde Ajustes:
/// el detector lo nota en la siguiente foto y recarga la sesión.
class ConfigDeteccion {
  const ConfigDeteccion(this.modelo, this.acelerador);

  final ModeloDeteccion modelo;
  final Acelerador acelerador;

  String get etiqueta => '${modelo.nombre} + ${acelerador.nombre}';

  @override
  bool operator ==(Object other) =>
      other is ConfigDeteccion &&
      other.modelo == modelo &&
      other.acelerador == acelerador;

  @override
  int get hashCode => Object.hash(modelo, acelerador);
}

final ValueNotifier<ConfigDeteccion> configDeteccion = ValueNotifier(
  const ConfigDeteccion(ModeloDeteccion.dfineSObj365, Acelerador.cpu),
);

/// Detector de objetos con ONNX Runtime, 100 % offline.
class DetectorOnnx implements DetectorObjetos {
  DetectorOnnx({ValueNotifier<ConfigDeteccion>? config, BancoPruebas? banco})
      : _config = config ?? configDeteccion,
        _banco = banco ?? BancoPruebas.instancia;

  static const int _lado = 640;

  final ValueNotifier<ConfigDeteccion> _config;
  final BancoPruebas _banco;
  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _sesion;
  ConfigDeteccion? _cargada;

  /// Reutilizado entre fotos para no pedir 1,2 MB de memoria cada vez.
  final Uint8List _entrada = Uint8List(_lado * _lado * 3);

  Future<OrtSession> _sesionPara(ConfigDeteccion config) async {
    final actual = _sesion;
    if (actual != null && _cargada == config) return actual;

    await actual?.close();
    _sesion = null;

    final reloj = Stopwatch()..start();
    OrtSession nueva;
    try {
      nueva = await _ort.createSessionFromAsset(
        config.modelo.asset,
        options: OrtSessionOptions(
          // Pocos hilos = menos calor. Subir solo si el banco muestra que conviene.
          intraOpNumThreads: 2,
          providers: config.acelerador.proveedores,
        ),
      );
    } catch (e) {
      if (config.acelerador == Acelerador.cpu) rethrow;
      // Algunos teléfonos no soportan NNAPI con este modelo: se vuelve a CPU.
      debugPrint('No se pudo usar ${config.acelerador.nombre} ($e). Uso CPU.');
      nueva = await _ort.createSessionFromAsset(
        config.modelo.asset,
        options: OrtSessionOptions(
          intraOpNumThreads: 2,
          providers: Acelerador.cpu.proveedores,
        ),
      );
    }
    debugPrint('Modelo ${config.etiqueta} cargado en '
        '${reloj.elapsedMilliseconds} ms');
    _sesion = nueva;
    _cargada = config;
    return nueva;
  }

  /// Decodifica la foto directamente al tamaño que necesita el modelo (lo hace el
  /// motor de Flutter en código nativo, mucho más rápido que en Dart) y copia los
  /// píxeles RGB a [_entrada]. Devuelve qué parte de los 640x640 ocupa la foto.
  Future<({double ancho, double alto})> _prepararEntrada(
    Uint8List bytes,
    ModeloDeteccion modelo,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);

    int anchoDestino = _lado;
    int altoDestino = _lado;
    if (modelo.letterbox) {
      final escala = _lado / (descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height);
      anchoDestino = (descriptor.width * escala).round().clamp(1, _lado);
      altoDestino = (descriptor.height * escala).round().clamp(1, _lado);
    }

    final codec = await descriptor.instantiateCodec(
      targetWidth: anchoDestino,
      targetHeight: altoDestino,
    );
    final cuadro = await codec.getNextFrame();
    final imagen = cuadro.image;
    final rgba = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
    // Se usan las medidas REALES de la imagen decodificada: si la foto venía
    // girada (EXIF), Flutter ya la enderezó y el ancho/alto pueden haberse cruzado.
    final ancho = imagen.width.clamp(1, _lado);
    final alto = imagen.height.clamp(1, _lado);
    final anchoFila = imagen.width;
    imagen.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    if (rgba == null) throw StateError('No se pudo leer la imagen');
    final origen = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);

    if (ancho < _lado || alto < _lado) _entrada.fillRange(0, _entrada.length, 0);
    for (var y = 0; y < alto; y++) {
      var o = y * anchoFila * 4;
      var d = y * _lado * 3;
      for (var x = 0; x < ancho; x++) {
        _entrada[d] = origen[o];
        _entrada[d + 1] = origen[o + 1];
        _entrada[d + 2] = origen[o + 2];
        o += 4;
        d += 3;
      }
    }
    return (ancho: ancho.toDouble(), alto: alto.toDouble());
  }

  @override
  Future<List<Deteccion>> detectar(String rutaFoto) async {
    final config = _config.value;
    final sesion = await _sesionPara(config);
    final modelo = config.modelo;

    final reloj = Stopwatch()..start();
    final bytes = await File(rutaFoto).readAsBytes();
    final ocupado = await _prepararEntrada(bytes, modelo);
    final msPreparar = reloj.elapsedMilliseconds;

    final tensor = await OrtValue.fromList(_entrada, [1, _lado, _lado, 3]);
    Map<String, OrtValue>? salidas;
    final List<dynamic> cajas;
    final List<dynamic> puntajes;
    final List<dynamic> clases;
    try {
      salidas = await sesion.run({'imagen': tensor});
      cajas = await salidas['cajas']!.asFlattenedList();
      puntajes = await salidas['puntajes']!.asFlattenedList();
      clases = await salidas['clases']!.asFlattenedList();
    } finally {
      await tensor.dispose();
      for (final s in salidas?.values ?? const <OrtValue>[]) {
        await s.dispose();
      }
    }
    final msInferencia = reloj.elapsedMilliseconds - msPreparar;

    // Las cajas vienen en píxeles de la entrada de 640x640. Se pasan a fracciones
    // de la FOTO (0 a 1), que es lo que usa el resto de la app.
    final escalaX = modelo.letterbox ? ocupado.ancho : _lado.toDouble();
    final escalaY = modelo.letterbox ? ocupado.alto : _lado.toDouble();
    double fraccion(dynamic v, double escala) =>
        ((v as num).toDouble() / escala).clamp(0.0, 1.0);

    final detecciones = <Deteccion>[];
    for (var i = 0; i < puntajes.length; i++) {
      final confianza = (puntajes[i] as num).toDouble();
      if (confianza < modelo.umbral) continue;
      final indice = (clases[i] as num).toInt();
      if (indice < 0 || indice >= modelo.clases.length) continue;

      final x1 = fraccion(cajas[i * 4], escalaX);
      final y1 = fraccion(cajas[i * 4 + 1], escalaY);
      final x2 = fraccion(cajas[i * 4 + 2], escalaX);
      final y2 = fraccion(cajas[i * 4 + 3], escalaY);
      if (x2 <= x1 || y2 <= y1) continue;

      detecciones.add(Deteccion(
        clase: modelo.clases[indice],
        confianza: confianza,
        centroX: (x1 + x2) / 2,
        alto: y2 - y1,
        ancho: x2 - x1,
      ));
    }
    detecciones.sort((a, b) => b.area.compareTo(a.area));

    await _banco.registrar(
      config: config,
      msPreparar: msPreparar,
      msInferencia: msInferencia,
      msTotal: reloj.elapsedMilliseconds,
      objetos: detecciones.length,
    );
    return detecciones;
  }

  @override
  bool conoce(String clase) => _config.value.modelo.clases.contains(clase);

  @override
  void liberar() {
    _sesion?.close();
    _sesion = null;
    _cargada = null;
  }
}
