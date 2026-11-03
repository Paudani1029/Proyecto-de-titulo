import '../../../models/deteccion.dart';

/// Contrato de cualquier motor que encuentre objetos en una foto.
/// Hoy: D-FINE o RTMDet con ONNX Runtime (ver detector_onnx.dart).
abstract class DetectorObjetos {
  /// Analiza la foto y devuelve los objetos encontrados (ordenados de mayor a menor tamaño).
  Future<List<Deteccion>> detectar(String rutaFoto);

  /// true si el modelo en uso sabe detectar esta clase. Si no la conoce, buscarla
  /// sería engañoso: "no veo una puerta" sonaría a que no hay ninguna.
  bool conoce(String clase);

  void liberar();
}
