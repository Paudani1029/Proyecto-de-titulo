import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TraduccionService {
  final OnDeviceTranslator _traductor = OnDeviceTranslator(  //	OnDeviceTranslator: El modelo de traducción, configurado para inglés → español
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.spanish,
  );

  final _gestorModelos = OnDeviceTranslatorModelManager();   //OnDeviceTranslatorModelManager: Administra la descarga del modelo — verifica si ya está descargado antes de intentar bajarlo de nuevo
  bool _modeloListo = false;

  Future<void> asegurarModeloDescargado() async {
    if (_modeloListo) return;

    final descargado = await _gestorModelos.isModelDownloaded(  //isModelDownloaded(...): Evita descargar el modelo repetidamente cada vez que se abre la app
      TranslateLanguage.spanish.bcpCode,
    );

    if (!descargado) {
      await _gestorModelos.downloadModel(
        TranslateLanguage.spanish.bcpCode,
      );
    }

    _modeloListo = true;
  }

  Future<String> traducir(String textoEnIngles) async {
    await asegurarModeloDescargado();
    return await _traductor.translateText(textoEnIngles);
  }

  void liberar() {
    _traductor.close();
  }
}