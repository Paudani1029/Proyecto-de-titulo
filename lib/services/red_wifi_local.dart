import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hace que la app use el Wi-Fi aunque esa red no tenga internet.
///
/// Por qué: cuando el teléfono se conecta a la red propia de Lumina Cam
/// ("Lumina-Camara"), Android ve que no hay internet y sigue mandando los datos
/// de las apps por la red móvil. Así la app nunca llega a 192.168.4.1.
///
/// Mientras está "amarrada", ESTA app no tiene internet (Supabase no sincroniza),
/// pero la detección, la voz y el reconocimiento de voz siguen funcionando.
/// Ver MainActivity.kt.
class RedWifiLocal {
  RedWifiLocal._();

  static const MethodChannel _canal = MethodChannel('lumina/red');

  /// true si quedó amarrada al Wi-Fi. false si no hay Wi-Fi o no es Android.
  static Future<bool> usarWifi() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _canal.invokeMethod<bool>('usarWifi') ?? false;
    } catch (e) {
      debugPrint('No se pudo usar el Wi-Fi local: $e');
      return false;
    }
  }

  /// Vuelve a la red normal del teléfono (con internet).
  static Future<void> soltarWifi() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _canal.invokeMethod<void>('soltarWifi');
    } catch (_) {}
  }
}
