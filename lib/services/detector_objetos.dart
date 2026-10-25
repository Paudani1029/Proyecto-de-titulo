import '../../../models/deteccion.dart';

/// Contrato de cualquier motor que encuentre objetos en una foto.
/// Hoy: YOLO. Mañana podría ser otro modelo sin tocar el resto de la app.
abstract class DetectorObjetos {
  /// Analiza la foto y devuelve los objetos encontrados (ordenados de mayor a menor tamaño).
  Future<List<Deteccion>> detectar(String rutaFoto);

  void liberar();
}
