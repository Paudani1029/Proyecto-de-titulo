import 'package:flutter/material.dart';

import '../test/screens/pantalla_bienvenida.dart';
import '../test/screens/pantalla_guia.dart';
import '../test/screens/pantalla_login.dart';
import '../test/screens/pantalla_principal.dart';
import '../test/theme/lumina_tema.dart';

void main() {
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

enum _Etapa { login, bienvenida, guia, principal }

/// Decide qué pantalla mostrar (mismo flujo que el diseño de Figma).
class _Raiz extends StatefulWidget {
  const _Raiz();

  @override
  State<_Raiz> createState() => _RaizState();
}

class _RaizState extends State<_Raiz> {
  _Etapa _etapa = _Etapa.login;

  void _ir(_Etapa etapa) => setState(() => _etapa = etapa);

  @override
  Widget build(BuildContext context) {
    return switch (_etapa) {
      _Etapa.login => PantallaLogin(
          alIniciarSesion: () => _ir(_Etapa.bienvenida),
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
