import 'dart:async';
import 'dart:math';
import 'camara_service.dart';

class MockCameraService implements CameraService {
  final _controlador = StreamController<String>();
  Timer? _temporizador;

  final List<String> _descripcionesFalsas = [
    'Hay una vereda despejada. A tu derecha, una banca.',
    'Semáforo en rojo a diez metros, frente a ti.',
    'Puerta de entrada a la izquierda, a dos pasos.',
    'Escalón hacia abajo, un metro adelante. Cuidado.',
    'Persona acercándose desde tu derecha.',
  ];

  @override
  Future<bool> conectar() async {
    // Simulamos el tiempo real que tomaría conectar con la cámara
    await Future.delayed(const Duration(seconds: 2));

    // Cada 4 segundos, "emitimos" una descripción nueva al Stream
    _temporizador = Timer.periodic(const Duration(seconds: 4), (_) {
      final aleatoria = _descripcionesFalsas[
          Random().nextInt(_descripcionesFalsas.length)];
      _controlador.add(aleatoria);
    });

    return true; // simulamos que siempre conecta con éxito
  }

  @override
  Stream<String> get descripciones => _controlador.stream;

  @override
  void desconectar() {
    _temporizador?.cancel();
    _controlador.close();
  }
}


// Future<bool> + async/await: conectar() toma tiempo (simulado con Future.delayed), así que la marcamos async y usamos await para "esperar" sin bloquear la app.
// Timer.periodic: ejecuta código repetidamente cada cierto tiempo — así simulamos que van llegando descripciones nuevas.
// StreamController: es como el "emisor" de un Stream. Nosotros metemos datos con .add(...), y quien esté "escuchando" el stream los recibe.