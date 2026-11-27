import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lumina/services/fuente_imagen_esp32.dart';

/// Un JPEG mínimo (empieza con FF D8, termina con FF D9).
final List<int> jpegFalso = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 0xFF, 0xD9];

/// Simula una Lumina Cam en [ipCamara]; cualquier otra IP no responde.
MockClient camaraFalsa(String ipCamara, {bool fotoRota = false}) {
  return MockClient((pedido) async {
    if (pedido.url.host != ipCamara) {
      throw const SocketException('Sin respuesta');
    }
    switch (pedido.url.path) {
      case '/status':
        return http.Response('{"lumina":"camara","version":1}', 200);
      case '/capture':
        return fotoRota
            ? http.Response('error', 200)
            : http.Response.bytes(jpegFalso, 200);
    }
    return http.Response('', 404);
  });
}

void main() {
  test('Usa la IP conocida si responde, sin buscar en la red', () async {
    var busco = false;
    final camara = FuenteImagenEsp32(
      ipConocida: '192.168.43.20',
      cliente: camaraFalsa('192.168.43.20'),
      buscador: () async {
        busco = true;
        return null;
      },
    );
    expect(await camara.conectar(), isTrue);
    expect(camara.ip, '192.168.43.20');
    expect(busco, isFalse);
  });

  test('Si la IP conocida no responde, la busca y avisa la nueva', () async {
    String? guardada;
    final camara = FuenteImagenEsp32(
      ipConocida: '192.168.43.20',
      cliente: camaraFalsa('192.168.43.77'),
      buscador: () async => '192.168.43.77',
      alEncontrar: (ip) => guardada = ip,
    );
    expect(await camara.conectar(), isTrue);
    expect(camara.ip, '192.168.43.77');
    expect(guardada, '192.168.43.77');
  });

  test('Al final prueba la red propia de la cámara (192.168.4.1)', () async {
    final camara = FuenteImagenEsp32(
      cliente: camaraFalsa(ipRedPropia),
      buscador: () async => null,
    );
    expect(await camara.conectar(), isTrue);
    expect(camara.ip, ipRedPropia);
  });

  test('No conecta si no hay ninguna Lumina Cam', () async {
    final camara = FuenteImagenEsp32(
      cliente: camaraFalsa('10.0.0.1'),
      buscador: () async => null,
    );
    expect(await camara.conectar(), isFalse);
    expect(await camara.capturarFoto(), isNull);
  });

  test('Ignora aparatos que no son Lumina Cam', () async {
    final otro = MockClient((_) async => http.Response('<html>router</html>', 200));
    final camara = FuenteImagenEsp32(cliente: otro, buscador: () async => null);
    expect(await camara.conectar(), isFalse);
  });

  test('Guarda la foto en un archivo y la deja para la vista previa', () async {
    final camara = FuenteImagenEsp32(
      ipConocida: '192.168.43.20',
      cliente: camaraFalsa('192.168.43.20'),
      buscador: () async => null,
    );
    await camara.conectar();

    final ruta = await camara.capturarFoto();
    expect(ruta, isNotNull);
    expect(await File(ruta!).readAsBytes(), jpegFalso);
    expect(camara.ultimaFoto.value, jpegFalso);
    await File(ruta).delete();
  });

  test('Descarta respuestas que no son JPEG', () async {
    final camara = FuenteImagenEsp32(
      ipConocida: '192.168.43.20',
      cliente: camaraFalsa('192.168.43.20', fotoRota: true),
      buscador: () async => null,
    );
    await camara.conectar();
    expect(await camara.capturarFoto(), isNull);
  });

  test('Reconoce el mensaje de Lumina Cam', () {
    expect(esRespuestaLumina(utf8.encode('LUMINA-CAM')), isTrue);
    expect(esRespuestaLumina(utf8.encode('LUMINA?')), isFalse);
    expect(esRespuestaLumina([0xFF, 0xFE]), isFalse);
  });

  test('La búsqueda por UDP encuentra el anuncio de la cámara', () async {
    final busqueda = buscarCamaraEnRed(espera: const Duration(seconds: 3));

    // Hace de cámara: se anuncia al puerto 4210 de este computador
    final camara = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    camara.send(
      utf8.encode(respuestaDescubrimiento),
      InternetAddress.loopbackIPv4,
      puertoDescubrimiento,
    );

    expect(await busqueda, '127.0.0.1');
    camara.close();
  });

  test('Con la red propia amarra la app al Wi-Fi y la suelta al desconectar',
      () async {
    var amarrada = false;
    final camara = FuenteImagenEsp32(
      cliente: camaraFalsa(ipRedPropia),
      buscador: () async => null,
      usarWifi: () async => amarrada = true,
      soltarWifi: () async => amarrada = false,
    );
    expect(await camara.conectar(), isTrue);
    expect(amarrada, isTrue);

    camara.desconectar();
    await Future<void>.delayed(Duration.zero);
    expect(amarrada, isFalse);
  });

  test('Si la red propia no responde, suelta el Wi-Fi', () async {
    var amarrada = false;
    final camara = FuenteImagenEsp32(
      cliente: camaraFalsa('10.0.0.1'),
      buscador: () async => null,
      usarWifi: () async => amarrada = true,
      soltarWifi: () async => amarrada = false,
    );
    expect(await camara.conectar(), isFalse);
    expect(amarrada, isFalse);
  });

  test('Si la última vez estaba en la red propia, la prueba antes de buscar',
      () async {
    var busco = false;
    final camara = FuenteImagenEsp32(
      ipConocida: ipRedPropia,
      cliente: camaraFalsa(ipRedPropia),
      buscador: () async {
        busco = true;
        return null;
      },
      usarWifi: () async => true,
      soltarWifi: () async {},
    );
    expect(await camara.conectar(), isTrue);
    expect(busco, isFalse);
  });

  test('Con la cámara en otra red no amarra el Wi-Fi', () async {
    var amarrada = false;
    final camara = FuenteImagenEsp32(
      ipConocida: '192.168.43.20',
      cliente: camaraFalsa('192.168.43.20'),
      buscador: () async => null,
      usarWifi: () async => amarrada = true,
      soltarWifi: () async => amarrada = false,
    );
    expect(await camara.conectar(), isTrue);
    expect(amarrada, isFalse);
  });
}
