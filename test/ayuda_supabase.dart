import 'package:supabase_flutter/supabase_flutter.dart';

bool _iniciado = false;

/// Inicializa Supabase para los tests, sin sesión guardada y apuntando a un
/// servidor ficticio (en `flutter test` toda petición HTTP responde 400).
Future<void> iniciarSupabaseDePrueba() async {
  if (_iniciado) return;
  _iniciado = true;
  await Supabase.initialize(
    url: 'http://localhost:54321',
    publishableKey: 'clave-de-prueba',
    authOptions: FlutterAuthClientOptions(
      localStorage: const EmptyLocalStorage(),
      pkceAsyncStorage: _AlmacenMemoria(),
      detectSessionInUri: false,
    ),
  );
}

class _AlmacenMemoria extends GotrueAsyncStorage {
  final Map<String, String> _datos = {};

  @override
  Future<String?> getItem({required String key}) async => _datos[key];

  @override
  Future<void> removeItem({required String key}) async => _datos.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _datos[key] = value;
}
