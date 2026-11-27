import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/pantalla_bienvenida.dart';
import 'screens/pantalla_guia.dart';
import 'screens/pantalla_login.dart';
import 'screens/pantalla_principal.dart';
import 'screens/pantalla_registro.dart';
import 'services/cuenta_service.dart';
import 'services/preferencias_camara.dart';
import 'services/preferencias_service.dart';
import 'theme/lumina_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La clave "publishable" es pública por diseño: la seguridad de los datos
  // la ponen las políticas RLS de la base. La clave "secret" NUNCA va aquí.
  await Supabase.initialize(
    url: 'https://evmfhovwvwptrowmdzqw.supabase.co',
    publishableKey: 'sb_publishable_LsG9BEZWOCqo39wqG3sxqw_W6SazSif',
  );

  // Cámara elegida e IP de Lumina Cam (se guardan en este teléfono).
  await PreferenciasCamara.cargar();

  // Si ya había una sesión guardada, trae sus ajustes sin bloquear el inicio.
  unawaited(PreferenciasService.cargar());

  runApp(const LuminaApp());
}

class LuminaApp extends StatelessWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se reconstruye cuando el usuario cambia el modo oscuro en Ajustes
    return ValueListenableBuilder<bool>(
      valueListenable: modoOscuro,
      builder: (context, oscuro, _) {
        return MaterialApp(
          title: 'Lumina',
          debugShowCheckedModeBanner: false,
          theme: construirTema(oscuro: false),
          darkTheme: construirTema(oscuro: true),
          themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
          home: const _Raiz(),
        );
      },
    );
  }
}

enum _Etapa { login, registro, bienvenida, guia, principal }

/// Decide qué pantalla mostrar (mismo flujo que el diseño de Figma).
class _Raiz extends StatefulWidget {
  const _Raiz();

  @override
  State<_Raiz> createState() => _RaizState();
}

class _RaizState extends State<_Raiz> {
  // Con sesión guardada se entra directo; si no, se parte en el login.
  _Etapa _etapa =
      CuentaService.sesion != null ? _Etapa.principal : _Etapa.login;

  late final StreamSubscription<AuthState> _suscripcion;

  @override
  void initState() {
    super.initState();
    // Un solo lugar decide la navegación según la sesión: sirve igual para
    // correo y contraseña, Google/Outlook (que vuelven desde el navegador) y
    // el enlace de confirmación del correo.
    _suscripcion = CuentaService.cambios.listen((estado) {
      switch (estado.event) {
        case AuthChangeEvent.signedIn:
          if (_etapa == _Etapa.login || _etapa == _Etapa.registro) {
            _ir(_Etapa.bienvenida);
            PreferenciasService.cargar();
          }
        case AuthChangeEvent.signedOut:
          _ir(_Etapa.login);
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  void _ir(_Etapa etapa) {
    if (mounted) setState(() => _etapa = etapa);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_etapa) {
      _Etapa.login => PantallaLogin(
          alIrARegistro: () => _ir(_Etapa.registro),
        ),
      _Etapa.registro => PantallaRegistro(
          alIrALogin: () => _ir(_Etapa.login),
        ),
      _Etapa.bienvenida => PantallaBienvenida(
          alContinuar: () => _ir(_Etapa.guia),
        ),
      _Etapa.guia => PantallaGuia(
          alVolver: () => _ir(_Etapa.bienvenida),
          alTerminar: () => _ir(_Etapa.principal),
        ),
      _Etapa.principal => const PantallaPrincipal(),
    };
  }
}
