import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/logica/generador_respuestas.dart';
import 'package:lumina/models/catalogo_clases.dart';
import 'package:lumina/models/clases_coco.dart';
import 'package:lumina/models/clases_obj365.dart';
import 'package:lumina/models/deteccion.dart';

void main() {
  test('cada clase de cada modelo tiene nombre en español', () {
    for (final clave in [...clasesCoco80, ...clasesObj365, ...clasesLumina]) {
      expect(nombreDeClase(clave), isNotNull, reason: clave);
    }
  });

  test('los modelos tienen la cantidad de clases que entregan', () {
    expect(clasesCoco80.length, 80);
    expect(clasesObj365.length, 365);
    expect(clasesLumina.length, greaterThan(365));
    expect(clasesLumina.toSet().length, clasesLumina.length, reason: 'sin repetidas');
    expect(clasesCoco80, nombresCoco.keys.toList());
  });

  test('todo sinónimo apunta a una clase que algún modelo conoce', () {
    final conocidas = {...clasesCoco80, ...clasesObj365, ...clasesLumina};
    for (final e in {...sinonimosCoco, ...sinonimosObj365}.entries) {
      expect(conocidas, contains(e.value), reason: e.key);
      expect(e.key, isNot(contains('ñ')), reason: 'normalizar() quita la ñ');
      expect(e.key.split(' ').length, lessThanOrEqualTo(3), reason: e.key);
    }
  });

  test('la ropa que lleva puesta alguien no se nombra al describir', () {
    final texto = describirEscena(const [
      Deteccion(clase: 'person', confianza: 0.9, centroX: 0.5, alto: 0.5),
      Deteccion(clase: 'sneakers', confianza: 0.9, centroX: 0.5, alto: 0.05),
      Deteccion(clase: 'trash bin can', confianza: 0.8, centroX: 0.8, alto: 0.2),
    ]);
    expect(texto, contains('una persona'));
    expect(texto, contains('un basurero'));
    expect(texto, isNot(contains('zapatillas')));
  });

  test('solo ropa = no hay nada que describir', () {
    expect(
      describirEscena(const [
        Deteccion(clase: 'belt', confianza: 0.9, centroX: 0.5, alto: 0.1),
      ]),
      'No detecto objetos conocidos frente a ti.',
    );
  });

  test('se puede buscar una clase nueva', () {
    final r = responderBusqueda(
      clase: 'glasses',
      objetoPedido: 'lentes',
      detecciones: const [
        Deteccion(clase: 'glasses', confianza: 0.8, centroX: 0.1, alto: 0.05),
      ],
    );
    expect(r, 'Los lentes están a tu izquierda.');
  });

  test('un cono adelante y muy cerca avisa en modo guía', () {
    final alertas = evaluarRiesgos(const [
      Deteccion(clase: 'traffic cone', confianza: 0.8, centroX: 0.5, alto: 0.5),
    ], modoGuia: true);
    expect(alertas.map((a) => a.mensaje), ['Hay un cono frente a ti.']);
  });
}
