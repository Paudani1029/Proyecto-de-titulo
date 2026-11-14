import 'package:flutter/material.dart';

import '../logica/validaciones.dart';
import '../theme/lumina_tema.dart';
import '../widgets/cuentas_externas.dart';
import '../widgets/lumina_widgets.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({
    super.key,
    required this.alIniciarSesion,
    required this.alIrARegistro,
    required this.alUsarCuentaExterna,
  });

  final VoidCallback alIniciarSesion;
  final VoidCallback alIrARegistro;
  final ValueChanged<ProveedorCuenta> alUsarCuentaExterna;

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  // Los errores solo se muestran después de presionar "Iniciar sesión",
  // para no regañar al usuario mientras todavía está escribiendo.
  bool _intentoEnviar = false;

  bool get _completo =>
      _correo.text.trim().isNotEmpty && _clave.text.isNotEmpty;

  String? get _errorCorreo => validarCorreo(_correo.text);
  String? get _errorClave => validarClave(_clave.text);

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  // Solo avanza si el correo tiene formato válido y la contraseña el largo mínimo.
  // Aquí es donde más adelante se conectaría la autenticación real.
  void _enviar() {
    setState(() => _intentoEnviar = true);
    if (_completo && _errorCorreo == null && _errorClave == null) {
      widget.alIniciarSesion();
    }
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
                  CampoLumina(
                    etiqueta: 'Correo electrónico',
                    controlador: _correo,
                    pista: 'nombre@correo.com',
                    teclado: TextInputType.emailAddress,
                    autocompletar: const [AutofillHints.email],
                    accionTeclado: TextInputAction.next,
                    error: _intentoEnviar ? _errorCorreo : null,
                    alCambiar: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  CampoLumina(
                    etiqueta: 'Contraseña',
                    controlador: _clave,
                    pista: 'Escribe tu contraseña',
                    oculto: true,
                    autocompletar: const [AutofillHints.password],
                    accionTeclado: TextInputAction.done,
                    error: _intentoEnviar ? _errorClave : null,
                    alCambiar: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  BotonPrimario(
                    texto: 'Iniciar sesión',
                    onPressed: _completo ? _enviar : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: EnlaceLumina(
                      texto: '¿Olvidaste tu contraseña?',
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SeparadorTexto(texto: 'o continúa con'),
                  const SizedBox(height: 20),
                  BotonesCuentaExterna(
                    accion: 'Iniciar sesión',
                    alElegir: widget.alUsarCuentaExterna,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '¿No tienes cuenta?',
                        style: estiloTexto(18, FontWeight.w600, c.inkMuted),
                      ),
                      const SizedBox(width: 4),
                      EnlaceLumina(
                        texto: 'Regístrate',
                        onPressed: widget.alIrARegistro,
                      ),
                    ],
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
