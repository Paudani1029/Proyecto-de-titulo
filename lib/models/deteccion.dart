/// Un objeto encontrado en una foto.
class Deteccion {
  const Deteccion({
    required this.clase,
    required this.confianza,
    this.centroX,
    this.alto = 0,
    this.ancho = 0,
  });

  /// Nombre de la clase COCO en inglés y minúsculas (ej. 'cell phone').
  final String clase;

  /// Seguridad del modelo, de 0 a 1.
  final double confianza;

  /// Posición horizontal del centro: 0 = extremo izquierdo, 1 = extremo derecho.
  /// Es null si el detector no entregó coordenadas.
  final double? centroX;

  /// Alto del recuadro como fracción de la altura de la foto (0 a 1).
  /// Un objeto más grande en la foto suele estar más cerca.
  final double alto;

  /// Ancho del recuadro como fracción del ancho de la foto (0 a 1).
  final double ancho;

  double get area => alto * ancho;
}
