import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/lumina_tema.dart';
import 'pulso_proximidad.dart';

/// Guarda los ajustes de la app en la tabla config_accesibilidad, para que
/// el usuario los recupere al entrar desde otro teléfono.
///
/// Si no hay internet, la app sigue funcionando con los valores locales.
class PreferenciasService {
  PreferenciasService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static const String _tabla = 'config_accesibilidad';

  /// Mientras se aplican los valores de la nube no se vuelven a guardar.
  static bool _aplicando = false;
  static bool _escuchando = false;

  static List<ValueNotifier<bool>> get _ajustes =>
      [modoOscuro, vibracionBusqueda, pitidoBusqueda];

  /// Trae los ajustes del usuario actual y empieza a guardar los cambios.
  static Future<void> cargar() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return;

    try {
      final fila = await _db
          .from(_tabla)
          .select('modo_oscuro, modo_haptico_activo, pitido_activo')
          .eq('id_usuario', id)
          .maybeSingle();

      if (fila != null) {
        _aplicando = true;
        modoOscuro.value = fila['modo_oscuro'] as bool;
        vibracionBusqueda.value = fila['modo_haptico_activo'] as bool;
        pitidoBusqueda.value = fila['pitido_activo'] as bool;
      }
    } catch (e) {
      debugPrint('No se pudieron cargar los ajustes: $e');
    } finally {
      _aplicando = false;
    }

    if (!_escuchando) {
      _escuchando = true;
      for (final ajuste in _ajustes) {
        ajuste.addListener(_guardar);
      }
    }
  }

  static Future<void> _guardar() async {
    if (_aplicando) return;
    final id = _db.auth.currentUser?.id;
    if (id == null) return;

    try {
      await _db.from(_tabla).update({
        'modo_oscuro': modoOscuro.value,
        'modo_haptico_activo': vibracionBusqueda.value,
        'pitido_activo': pitidoBusqueda.value,
      }).eq('id_usuario', id);
    } catch (e) {
      debugPrint('No se pudieron guardar los ajustes: $e');
    }
  }
}
