import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/logica/guia_busqueda.dart';
import 'package:lumina/models/deteccion.dart';
import 'package:lumina/services/pulso_proximidad.dart';

final DateTime t0 = DateTime(2026, 1, 1, 12);
DateTime seg(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

Deteccion botella(double x, double alto) =>
    Deteccion(clase: 'bottle', confianza: 0.9, centroX: x, alto: alto, ancho: 0.1);

void main() {
  late GuiaBusqueda guia;
  setUp(() => guia = GuiaBusqueda(clase: 'bottle', inicio: t0));

  test('El mensaje inicial nombra el objeto', () {
    expect(guia.mensajeInicial, contains('la botella'));
  });

  test('Al verlo por primera vez avisa de inmediato y da la dirección', () {
    final paso = guia.procesar([botella(0.1, 0.1)], seg(0.3));
    expect(paso.mensaje, 'Veo la botella. Gira a la izquierda.');
    expect(paso.terminada, isFalse);
  });

  test('Ignora otros objetos', () {
    final paso = guia.procesar(
      [const Deteccion(clase: 'cup', confianza: 0.9, centroX: 0.5, alto: 0.5)],
      seg(0.3),
    );
    expect(paso.mensaje, isNull);
  });

  test('No repite instrucciones demasiado seguido', () {
    guia.procesar([botella(0.3, 0.1)], seg(0.3));
    // Cambió la dirección, pero pasó poco tiempo: se queda callada
    expect(guia.procesar([botella(0.7, 0.1)], seg(1)).mensaje, isNull);
    // Ya pasó la pausa: ahora sí habla
    expect(guia.procesar([botella(0.7, 0.1)], seg(3)).mensaje,
        'Un poco a la derecha.');
    // Misma instrucción: espera más antes de repetirla
    expect(guia.procesar([botella(0.7, 0.1)], seg(6)).mensaje, isNull);
    expect(guia.procesar([botella(0.7, 0.1)], seg(8.5)).mensaje,
        'Un poco a la derecha.');
  });

  test('Centrado indica la distancia', () {
    expect(guia.procesar([botella(0.5, 0.03)], seg(0.3)).mensaje,
        contains('Camina derecho'));
    expect(guia.procesar([botella(0.5, 0.15)], seg(3)).mensaje,
        contains('Avanza despacio'));
  });

  test('Lo da por encontrado tras confirmarlo centrado y muy cerca', () {
    final primero = guia.procesar([botella(0.5, 0.5)], seg(0.3));
    expect(primero.terminada, isFalse);
    expect(primero.mensaje, contains('Extiende la mano'));

    final segundo = guia.procesar([botella(0.5, 0.5)], seg(0.8));
    expect(segundo.terminada, isTrue);
    expect(segundo.mensaje, contains('Encontraste la botella'));
  });

  test('Si lo pierde, le dice hacia dónde volver', () {
    guia.procesar([botella(0.1, 0.1)], seg(0.3));
    expect(guia.procesar([], seg(1)).mensaje, isNull);
    expect(guia.procesar([], seg(1.5)).mensaje, isNull);
    expect(guia.procesar([], seg(2)).mensaje,
        'Ya no veo la botella. Vuelve despacio hacia la izquierda.');

    // Al recuperarlo avisa de inmediato
    expect(guia.procesar([botella(0.5, 0.1)], seg(2.5)).mensaje,
        startsWith('Veo la botella.'));
  });

  test('Da pistas mientras no lo ve y se rinde a los 45 segundos', () {
    expect(guia.procesar([], seg(3)).mensaje, isNull);
    expect(guia.procesar([], seg(7.5)).mensaje,
        startsWith('Todavía no veo la botella.'));

    final fin = guia.procesar([], seg(46));
    expect(fin.terminada, isTrue);
    expect(fin.mensaje, contains('No logré encontrar la botella'));
  });

  group('Pulso de proximidad', () {
    test('Más rápido mientras más cerca', () {
      final lejos = SenalProximidad.desde(alto: 0.03, x: 0.5).intervalo;
      final medio = SenalProximidad.desde(alto: 0.2, x: 0.5).intervalo;
      final cerca = SenalProximidad.desde(alto: 0.5, x: 0.5).intervalo;
      expect(lejos.inMilliseconds, SenalProximidad.msLejos);
      expect(cerca.inMilliseconds, SenalProximidad.msCerca);
      expect(medio < lejos && medio > cerca, isTrue);
    });

    test('Distingue centrado de a un lado', () {
      expect(SenalProximidad.desde(alto: 0.2, x: 0.5).centrado, isTrue);
      expect(SenalProximidad.desde(alto: 0.2, x: 0.15).centrado, isFalse);
    });

    test('La guía pulsa al verlo, aguanta un parpadeo y calla al perderlo', () {
      expect(guia.senal, isNull);
      guia.procesar([botella(0.5, 0.2)], seg(0.3));
      expect(guia.senal, isNotNull);
      guia.procesar([], seg(0.6));
      expect(guia.senal, isNotNull, reason: 'una foto fallida no corta el pulso');
      guia.procesar([], seg(0.9));
      guia.procesar([], seg(1.2));
      expect(guia.senal, isNull);
    });

    test('Al encontrarlo marca encontrado y deja de pulsar', () {
      guia.procesar([botella(0.5, 0.5)], seg(0.3));
      guia.procesar([botella(0.5, 0.5)], seg(0.6));
      expect(guia.encontrado, isTrue);
      expect(guia.senal, isNull);
    });

    test('El pitido es un WAV válido', () {
      final wav = generarPitidoWav(frecuencia: 880);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, 44 + 22050 * 70 ~/ 1000 * 2);
    });
  });
}
