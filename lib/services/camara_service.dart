// Esta es la "forma" que debe tener cualquier fuente de datos de la cámara,
// sin importar si es real o simulada.
abstract class CameraService {
  // Intenta conectar con la cámara. Devuelve true si tuvo éxito.
  Future<bool> conectar();

  // Un flujo (Stream) de descripciones de texto que van llegando con el tiempo,
  // como si fueran las narraciones generadas por la IA.
  Stream<String> get descripciones;

  // Libera recursos cuando ya no se necesita (cerrar sockets, temporizadores, etc.)
  void desconectar();
}


//Un Stream en Dart es como una "tubería" de datos que van llegando de a poco en el tiempo (a diferencia de un Future, que entrega un solo valor una vez).