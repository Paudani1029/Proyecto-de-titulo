import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// true si el usuario prefiere Lumina Cam (XIAO ESP32S3 Sense) en vez de la
/// cámara del teléfono. Si Lumina Cam no responde, la app usa la del teléfono.
final ValueNotifier<bool> usarCamaraEsp32 = ValueNotifier<bool>(false);

/// Última dirección donde se encontró Lumina Cam (se prueba primero al conectar).
final ValueNotifier<String?> ipCamaraEsp32 = ValueNotifier<String?>(null);

/// Estos ajustes se guardan EN EL TELÉFONO y no en la nube (a diferencia de
/// PreferenciasService): la cámara y su IP dependen de este teléfono y su red.
class PreferenciasCamara {
  PreferenciasCamara._();

  static const String _claveUsar = 'camara_usar_esp32';
  static const String _claveIp = 'camara_ip_esp32';
  static bool _escuchando = false;

  /// Lee lo guardado y empieza a guardar los cambios. Llamar antes de runApp.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      usarCamaraEsp32.value = prefs.getBool(_claveUsar) ?? false;
      ipCamaraEsp32.value = prefs.getString(_claveIp);

      if (_escuchando) return;
      _escuchando = true;
      usarCamaraEsp32.addListener(
        () => prefs.setBool(_claveUsar, usarCamaraEsp32.value),
      );
      ipCamaraEsp32.addListener(() {
        final ip = ipCamaraEsp32.value;
        ip == null ? prefs.remove(_claveIp) : prefs.setString(_claveIp, ip);
      });
    } catch (e) {
      debugPrint('No se pudieron cargar los ajustes de cámara: $e');
    }
  }
}
