import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/cuentas_externas.dart';

/// Error con un mensaje listo para mostrar (y leer en voz alta) al usuario.
class ErrorCuenta implements Exception {
  const ErrorCuenta(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Todo lo relacionado con la cuenta: registrarse, entrar y salir.
///
/// El correo y la contraseña los maneja Supabase Auth (con hash seguro);
/// la app nunca guarda la contraseña.
class CuentaService {
  CuentaService._();

  /// Dirección a la que vuelve el navegador después de entrar con Google u
  /// Outlook, o de confirmar el correo. Debe coincidir con el intent-filter
  /// de AndroidManifest.xml y estar en Supabase → Authentication →
  /// URL Configuration → Redirect URLs.
  static const String redireccion = 'io.lumina.app://login-callback';

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static Session? get sesion => _auth.currentSession;

  static User? get usuario => _auth.currentUser;

  static Stream<AuthState> get cambios => _auth.onAuthStateChange;

  /// Crea la cuenta. Devuelve `true` si ya quedó con la sesión iniciada, o
  /// `false` si Supabase pide confirmar el correo antes de entrar.
  static Future<bool> registrar({
    required String nombre,
    required String correo,
    required String clave,
  }) {
    return _intentar(() async {
      final respuesta = await _auth.signUp(
        email: correo.trim(),
        password: clave,
        data: {'nombre_completo': nombre.trim()},
        emailRedirectTo: redireccion,
      );
      return respuesta.session != null;
    });
  }

  static Future<void> iniciarSesion({
    required String correo,
    required String clave,
  }) {
    return _intentar(
      () => _auth.signInWithPassword(email: correo.trim(), password: clave),
    );
  }

  /// Abre el navegador para entrar con Google u Outlook. La sesión llega
  /// después por [cambios], cuando el navegador vuelve a la app.
  static Future<void> iniciarConProveedor(ProveedorCuenta proveedor) {
    return _intentar(() async {
      final abierto = await _auth.signInWithOAuth(
        switch (proveedor) {
          ProveedorCuenta.google => OAuthProvider.google,
          ProveedorCuenta.correo => OAuthProvider.azure,
        },
        redirectTo: redireccion,
        // Microsoft no entrega el correo si no se pide explícitamente.
        scopes: proveedor == ProveedorCuenta.correo ? 'email' : null,
      );
      if (!abierto) {
        throw const ErrorCuenta('No se pudo abrir el navegador.');
      }
    });
  }

  static Future<void> cerrarSesion() => _intentar(_auth.signOut);

  /// Ejecuta [accion] y convierte cualquier error en un [ErrorCuenta]
  /// con un mensaje en español claro.
  static Future<T> _intentar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorCuenta {
      rethrow;
    } on AuthRetryableFetchException {
      throw const ErrorCuenta(_sinConexion);
    } on AuthException catch (e) {
      throw ErrorCuenta(_traducir(e));
    } on SocketException {
      throw const ErrorCuenta(_sinConexion);
    } catch (_) {
      throw const ErrorCuenta('Ocurrió un problema. Inténtalo de nuevo.');
    }
  }

  static const String _sinConexion =
      'No hay conexión a internet. Revisa tu conexión e inténtalo de nuevo.';

  static String _traducir(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'El correo o la contraseña no son correctos.';
      case 'email_not_confirmed':
        return 'Aún no confirmas tu correo. Revisa tu bandeja de entrada.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Ya existe una cuenta con ese correo. Inicia sesión.';
      case 'weak_password':
        return 'La contraseña es muy fácil de adivinar. Usa una más larga.';
      case 'email_address_invalid':
        return 'Ese correo no es válido.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'signup_disabled':
        return 'El registro está desactivado por ahora.';
      case 'provider_disabled':
        return 'Ese método de ingreso aún no está habilitado.';
    }
    return 'No se pudo completar. Inténtalo de nuevo.';
  }
}
