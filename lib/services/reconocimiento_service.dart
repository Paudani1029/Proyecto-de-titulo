import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ReconocimientoService {
  final ImageLabeler _etiquetador = ImageLabeler(  //ImageLabeler El modelo de IA de ML Kit ya entrenado, listo para usar sin conexión
    options: ImageLabelerOptions(confidenceThreshold: 0.6), //confidenceThreshold: 0.6 Solo acepta detecciones con 60% o más de seguridad — filtra resultados dudosos
  );

  // Recibe la ruta de una foto y devuelve una descripción en texto
  Future<String> analizarImagen(String rutaFoto) async {
    final entrada = InputImage.fromFilePath(rutaFoto);   //InputImage.fromFilePath(...) Convierte el archivo de la foto al formato que el modelo espera
    final etiquetas = await _etiquetador.processImage(entrada);  //.processImage(...)  Ejecuta el modelo sobre la imagen y devuelve una lista de etiquetas detectadas

    if (etiquetas.isEmpty) {
      return 'No se detectaron elementos reconocibles.';
    }

    // Tomamos hasta 3 elementos con mayor confianza
    final principales = etiquetas.take(3).map((e) => e.label).join(', ');
    return 'Detecto: $principales.';
  }

  void liberar() {
    _etiquetador.close();
  }
}