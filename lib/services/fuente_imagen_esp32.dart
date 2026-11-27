import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'fuente_imagen.dart';
import 'red_wifi_local.dart';

// Protocolo con el firmware (herramientas/esp32/lumina_camara/lumina_camara.ino).
const int puertoDescubrimiento = 4210;
const String preguntaDescubrimiento = 'LUMINA?';
const String respuestaDescubrimiento = 'LUMINA-CAM';

/// IP de Lumina Cam cuando crea su propia red ("Lumina-Camara").
const String ipRedPropia = '192.168.4.1';

/// Busca Lumina Cam en la red. Devuelve su IP, o null si no responde a tiempo.
typedef BuscadorCamara = Future<String?> Function();

/// IP dentro de la red propia de la cámara (192.168.4.x).
bool esDeRedPropia(String ip) => ip.startsWith('192.168.4.');

/// Toma fotos con Lumina Cam (XIAO ESP32S3 Sense) por Wi-Fi.
///
/// Para conectar prueba, en orden: la última IP conocida, buscarla en la red
/// (UDP) y la IP de su red propia. Así el usuario no tiene que escribir nada.
///
/// Con la red propia ("Lumina-Camara") la app se amarra al Wi-Fi, porque esa
/// red no tiene internet y Android mandaría los datos por la red móvil.
class FuenteImagenEsp32 implements FuenteImagen {
  FuenteImagenEsp32({
    this.ipConocida,
    http.Client? cliente,
    BuscadorCamara? buscador,
    this.alEncontrar,
    Future<bool> Function()? usarWifi,
    Future<void> Function()? soltarWifi,
  })  : _cliente = cliente ?? http.Client(),
        _buscador = buscador ?? buscarCamaraEnRed,
        _usarWifi = usarWifi ?? RedWifiLocal.usarWifi,
        _soltarWifi = soltarWifi ?? RedWifiLocal.soltarWifi;

  final String? ipConocida;
  final http.Client _cliente;
  final BuscadorCamara _buscador;
  final Future<bool> Function() _usarWifi;
  final Future<void> Function() _soltarWifi;
  bool _amarrada = false;

  /// Se llama con la IP cada vez que se encuentra la cámara (para guardarla).
  final ValueChanged<String>? alEncontrar;

  static const Duration _esperaEstado = Duration(seconds: 2);
  static const Duration _esperaFoto = Duration(seconds: 4);

  /// Tras estas fotos fallidas seguidas, se vuelve a buscar (quizás cambió de IP).
  static const int _fallosParaBuscar = 3;
  static const Duration _pausaEntreBusquedas = Duration(seconds: 10);

  String? _ip;
  int _fallos = 0;
  int _numeroFoto = 0;
  bool _buscando = false;
  DateTime _ultimaBusqueda = DateTime.fromMillisecondsSinceEpoch(0);

  /// Dirección actual de la cámara, o null si no está conectada.
  String? get ip => _ip;

  /// Última foto recibida, para la vista previa en pantalla.
  final ValueNotifier<Uint8List?> ultimaFoto = ValueNotifier<Uint8List?>(null);

  @override
  Future<bool> conectar() async {
    final conocida = ipConocida;
    final ultimaVezRedPropia = conocida != null && esDeRedPropia(conocida);

    // Lo más probable primero: donde estaba la última vez
    if (ultimaVezRedPropia) {
      if (await _probarRedPropia()) return true;
    } else if (conocida != null && await _responde(conocida)) {
      return _usar(conocida);
    }

    final encontrada = await _buscador();
    if (encontrada != null && await _responde(encontrada)) {
      return _usar(encontrada);
    }

    if (!ultimaVezRedPropia && await _probarRedPropia()) return true;
    return false;
  }

  /// Red propia: primero amarrar la app al Wi-Fi (si no, no llega).
  /// Si no se pudo amarrar (otro sistema, o sin datos móviles), se prueba igual.
  Future<bool> _probarRedPropia() async {
    _amarrada = await _usarWifi();
    if (await _responde(ipRedPropia)) return _usar(ipRedPropia);
    await _soltar();
    return false;
  }

  Future<void> _soltar() async {
    if (!_amarrada) return;
    _amarrada = false;
    await _soltarWifi();
  }

  bool _usar(String ip) {
    _ip = ip;
    _fallos = 0;
    alEncontrar?.call(ip);
    return true;
  }

  /// true si en esa IP hay una Lumina Cam (y no otro aparato).
  Future<bool> _responde(String ip) async {
    try {
      final r = await _cliente
          .get(Uri.parse('http://$ip/status'))
          .timeout(_esperaEstado);
      return r.statusCode == 200 && r.body.contains('"lumina"');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> capturarFoto() async {
    final ip = _ip;
    if (ip == null) {
      _quizasBuscarDeNuevo();
      return null;
    }

    try {
      final r = await _cliente
          .get(Uri.parse('http://$ip/capture'))
          .timeout(_esperaFoto);
      final bytes = r.bodyBytes;
      if (r.statusCode != 200 || !esJpeg(bytes)) {
        _fallo();
        return null;
      }

      _fallos = 0;
      ultimaFoto.value = bytes;

      // El detector lee la foto desde un archivo; el asistente lo borra después.
      final archivo = File(
        '${Directory.systemTemp.path}/lumina_esp32_${_numeroFoto++ % 100}.jpg',
      );
      await archivo.writeAsBytes(bytes, flush: true);
      return archivo.path;
    } catch (_) {
      _fallo();
      return null;
    }
  }

  void _fallo() {
    _fallos++;
    if (_fallos >= _fallosParaBuscar) _quizasBuscarDeNuevo();
  }

  /// Si el teléfono cambió de red o la cámara se reinició, puede tener otra IP.
  void _quizasBuscarDeNuevo() {
    final ahora = DateTime.now();
    if (_buscando || ahora.difference(_ultimaBusqueda) < _pausaEntreBusquedas) {
      return;
    }
    _buscando = true;
    _ultimaBusqueda = ahora;
    unawaited(() async {
      try {
        final encontrada = await _buscador();
        if (encontrada != null && await _responde(encontrada)) {
          _usar(encontrada);
        }
      } finally {
        _buscando = false;
      }
    }());
  }

  @override
  void desconectar() {
    unawaited(_soltar()); // la app recupera internet
    _ip = null;
    ultimaFoto.value = null;
    _cliente.close();
  }
}

/// Un JPEG siempre empieza con los bytes FF D8.
bool esJpeg(List<int> bytes) =>
    bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

/// true si el paquete UDP es la respuesta (o el anuncio) de Lumina Cam.
bool esRespuestaLumina(List<int> datos) {
  try {
    return utf8.decode(datos).trim() == respuestaDescubrimiento;
  } catch (_) {
    return false;
  }
}

/// Pregunta "LUMINA?" por UDP a toda la red y espera la respuesta.
/// También sirve el anuncio que la cámara envía sola cada 2 segundos.
Future<String?> buscarCamaraEnRed({
  Duration espera = const Duration(seconds: 4),
}) async {
  RawDatagramSocket socket;
  try {
    // En el puerto 4210 también se escuchan los anuncios de la cámara
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      puertoDescubrimiento,
      reuseAddress: true,
    );
  } catch (_) {
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      debugPrint('No se pudo buscar la cámara: $e');
      return null;
    }
  }
  socket.broadcastEnabled = true;

  final destinos = await _direccionesDeDifusion();
  final pregunta = utf8.encode(preguntaDescubrimiento);
  final resultado = Completer<String?>();

  final suscripcion = socket.listen((evento) {
    if (evento != RawSocketEvent.read) return;
    final paquete = socket.receive();
    if (paquete != null &&
        esRespuestaLumina(paquete.data) &&
        !resultado.isCompleted) {
      resultado.complete(paquete.address.address);
    }
  });

  void preguntar() {
    for (final destino in destinos) {
      try {
        socket.send(pregunta, destino, puertoDescubrimiento);
      } catch (_) {}
    }
  }

  preguntar();
  final repetir =
      Timer.periodic(const Duration(milliseconds: 800), (_) => preguntar());

  final ip = await resultado.future.timeout(espera, onTimeout: () => null);
  repetir.cancel();
  await suscripcion.cancel();
  socket.close();
  return ip;
}

/// Dirección de "difusión" de cada red del teléfono (ej. 192.168.43.255).
/// No basta con 255.255.255.255: con datos móviles activos, Android lo mandaría
/// por la red móvil y no por el Wi-Fi/punto de acceso donde está la cámara.
Future<List<InternetAddress>> _direccionesDeDifusion() async {
  final destinos = <InternetAddress>[InternetAddress('255.255.255.255')];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interfaz in interfaces) {
      for (final direccion in interfaz.addresses) {
        final partes = direccion.address.split('.');
        if (partes.length != 4) continue;
        // Las redes de hotspot y de casa casi siempre son /24
        destinos.add(InternetAddress('${partes[0]}.${partes[1]}.${partes[2]}.255'));
      }
    }
  } catch (_) {}
  return destinos;
}
