import 'package:flutter/material.dart';

import '../logica/validaciones.dart';
import '../theme/lumina_tema.dart';
import '../widgets/cuentas_externas.dart';
import '../widgets/lumina_widgets.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({
    super.key,
    required this.alRegistrarse,
    required this.alIrALogin,
    required this.alUsarCuentaExterna,
  });

  final VoidCallback alRegistrarse;
  final VoidCallback alIrALogin;
  final ValueChanged<ProveedorCuenta> alUsarCuentaExterna;

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();
  final TextEditingController _repetirClave = TextEditingController();

  // Los errores solo se muestran después de presionar "Crear cuenta",
  // para no regañar al usuario mientras todavía está escribiendo.
  bool _intentoEnviar = false;

  bool get _completo =>
      _nombre.text.trim().isNotEmpty &&
      _correo.text.trim().isNotEmpty &&
      _clave.text.isNotEmpty &&
      _repetirClave.text.isNotEmpty;

  String? get _errorCorreo => validarCorreo(_correo.text);

  String? get _errorClave => validarClave(_clave.text);

  String? get _errorRepetir => _repetirClave.text == _clave.text
      ? null
      : 'Las contraseñas no coinciden.';

  bool get _valido =>
      _errorCorreo == null && _errorClave == null && _errorRepetir == null;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    _repetirClave.dispose();
    super.dispose();
  }

  // Aquí es donde más adelante se conectaría el registro real (Firebase, API...).
  void _enviar() {
    setState(() => _intentoEnviar = true);
    if (_completo && _valido) widget.alRegistrarse();
  }

  void _actualizar(String _) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    // El botón "atrás" de Android vuelve al login en vez de cerrar la app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) {
        if (!yaSalio) widget.alIrALogin();
      },
      child: ContenedorPantalla(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LuminaLogo(),
            const SizedBox(height: 40),
            Text(
              'Crear cuenta',
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
              'Usa tu cuenta de Google o de correo para registrarte sin escribir.',
              style: estiloTexto(20, FontWeight.w500, c.inkMuted, altura: 1.5),
            ),
            const SizedBox(height: 24),
            BotonesCuentaExterna(
              accion: 'Registrarte',
              alElegir: widget.alUsarCuentaExterna,
            ),
            const SizedBox(height: 28),
            const SeparadorTexto(texto: 'o completa tus datos'),
            const SizedBox(height: 28),
            CampoLumina(
              etiqueta: 'Nombre',
              controlador: _nombre,
              pista: '¿Cómo te llamas?',
              teclado: TextInputType.name,
              autocompletar: const [AutofillHints.name],
              accionTeclado: TextInputAction.next,
              capitalizacion: TextCapitalization.words,
              alCambiar: _actualizar,
            ),
            const SizedBox(height: 20),
            CampoLumina(
              etiqueta: 'Correo electrónico',
              controlador: _correo,
              pista: 'nombre@correo.com',
              teclado: TextInputType.emailAddress,
              autocompletar: const [AutofillHints.email],
              accionTeclado: TextInputAction.next,
              error: _intentoEnviar ? _errorCorreo : null,
              alCambiar: _actualizar,
            ),
            const SizedBox(height: 20),
            CampoLumina(
              etiqueta: 'Contraseña',
              controlador: _clave,
              pista: 'Mínimo $largoMinimoClave caracteres',
              oculto: true,
              autocompletar: const [AutofillHints.newPassword],
              accionTeclado: TextInputAction.next,
              error: _intentoEnviar ? _errorClave : null,
              alCambiar: _actualizar,
            ),
            const SizedBox(height: 20),
            CampoLumina(
              etiqueta: 'Repite la contraseña',
              controlador: _repetirClave,
              pista: 'Escríbela otra vez',
              oculto: true,
              autocompletar: const [AutofillHints.newPassword],
              accionTeclado: TextInputAction.done,
              error: _intentoEnviar ? _errorRepetir : null,
              alCambiar: _actualizar,
            ),
            const SizedBox(height: 24),
            BotonPrimario(
              texto: 'Crear cuenta',
              onPressed: _completo ? _enviar : null,
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '¿Ya tienes cuenta?',
                  style: estiloTexto(18, FontWeight.w600, c.inkMuted),
                ),
                const SizedBox(width: 4),
                EnlaceLumina(
                  texto: 'Inicia sesión',
                  onPressed: widget.alIrALogin,
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 24),
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
      ),
    );
  }
}
