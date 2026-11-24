import 'package:flutter/material.dart';

import '../logica/validaciones.dart';
import '../services/cuenta_service.dart';
import '../theme/lumina_tema.dart';
import '../widgets/cuentas_externas.dart';
import '../widgets/lumina_widgets.dart';

/// Igual que el login: al quedar con sesión iniciada, la raíz de la app
/// detecta el cambio y pasa a la bienvenida.
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key, required this.alIrALogin});

  final VoidCallback alIrALogin;

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
  bool _cargando = false;
  String? _errorServidor;

  /// Se muestra cuando Supabase pide confirmar el correo antes de entrar.
  String? _avisoConfirmacion;

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

  Future<void> _enviar() async {
    setState(() => _intentoEnviar = true);
    if (!_completo || !_valido) return;

    await _conCarga(() async {
      final conSesion = await CuentaService.registrar(
        nombre: _nombre.text,
        correo: _correo.text,
        clave: _clave.text,
      );
      if (!conSesion && mounted) {
        setState(() {
          _avisoConfirmacion =
              'Te enviamos un correo a ${_correo.text.trim()}. '
              'Ábrelo y toca el enlace para activar tu cuenta.';
        });
      }
    });
  }

  Future<void> _usarCuentaExterna(ProveedorCuenta proveedor) =>
      _conCarga(() => CuentaService.iniciarConProveedor(proveedor));

  Future<void> _conCarga(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _errorServidor = null;
      _avisoConfirmacion = null;
    });
    try {
      await accion();
    } on ErrorCuenta catch (e) {
      if (mounted) setState(() => _errorServidor = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
              alElegir: _usarCuentaExterna,
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
            if (_errorServidor != null) ...[
              const SizedBox(height: 24),
              MensajeFormulario(texto: _errorServidor!),
            ],
            if (_avisoConfirmacion != null) ...[
              const SizedBox(height: 24),
              MensajeFormulario(texto: _avisoConfirmacion!, exito: true),
            ],
            const SizedBox(height: 24),
            BotonPrimario(
              texto: _cargando ? 'Creando cuenta…' : 'Crear cuenta',
              onPressed: _completo && !_cargando ? _enviar : null,
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
