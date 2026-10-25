/// De dónde salen las fotos. Hoy: la cámara del teléfono.
/// Cuando llegue la XIAO ESP32-S3 Sense, se agrega otra clase que pida
/// la foto por Wi-Fi (GET /capture) y la app no cambia.
abstract class FuenteImagen {
  /// Abre la cámara. Devuelve false si no se pudo (sin permiso, sin cámara...).
  Future<bool> conectar();

  /// Toma UNA foto y devuelve la ruta del archivo JPEG, o null si falló.
  Future<String?> capturarFoto();

  void desconectar();
}
