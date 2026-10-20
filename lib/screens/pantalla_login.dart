import 'package:flutter/material.dart';

import '../theme/lumina_tema.dart';
import '../widgets/lumina_widgets.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key, required this.alIniciarSesion});

  final VoidCallback alIniciarSesion;

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}
 
class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  bool get _completo =>
      _correo.text.trim().isNotEmpty && _clave.text.isNotEmpty;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  // Por ahora solo avanza si ambos campos tienen texto (igual que el diseño).
  // Aquí es donde más adelante se conectaría la autenticación real.
  void _enviar() {
    if (_completo) widget.alIniciarSesion();
  }

  Widget _campo({
    required LuminaColors c,
    required String etiqueta,
    required TextEditingController controlador,
    required String pista,
    bool oculto = false,
    TextInputType? teclado,
    Iterable<String>? autocompletar,
  }) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c.border, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: estiloTexto(18, FontWeight.w800, c.ink)),
        const SizedBox(height: 8),
        TextField(
          controller: controlador,
          obscureText: oculto,
          keyboardType: teclado,
          autofillHints: autocompletar,
          onChanged: (_) => setState(() {}),
          style: estiloTexto(18, FontWeight.w600, c.ink),
          decoration: InputDecoration(
            hintText: pista,
            hintStyle: estiloTexto(18, FontWeight.w600, c.inkMuted),
            filled: true,
            fillColor: c.surface,
            constraints: const BoxConstraints(minHeight: 64),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            border: borde,
            enabledBorder: borde,
            focusedBorder: borde.copyWith(
              borderSide: BorderSide(color: c.brand, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return ContenedorPantalla(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LuminaLogo(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido',
                    style: estiloTexto(
                      36,
                      FontWeight.w800,
                      c.ink,
                      altura: 1.15,
                      espaciado: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Inicia sesión para que Lumina pueda acompañarte.',
                    style: estiloTexto(
                      20,
                      FontWeight.w500,
                      c.inkMuted,
                      altura: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _campo(
                    c: c,
                    etiqueta: 'Correo electrónico',
                    controlador: _correo,
                    pista: 'nombre@correo.com',
                    teclado: TextInputType.emailAddress,
                    autocompletar: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 20),
                  _campo(
                    c: c,
                    etiqueta: 'Contraseña',
                    controlador: _clave,
                    pista: 'Escribe tu contraseña',
                    oculto: true,
                    autocompletar: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 20),
                  BotonPrimario(
                    texto: 'Iniciar sesión',
                    onPressed: _completo ? _enviar : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        foregroundColor: c.brandStrong,
                      ),
                      child: Text(
                        '¿Olvidaste tu contraseña?',
                        style: estiloTexto(
                          18,
                          FontWeight.w700,
                          c.brandStrong,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 20, color: c.success),
              const SizedBox(width: 8),
              Text(
                'Tus datos están protegidos',
                style: estiloTexto(14, FontWeight.w600, c.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
