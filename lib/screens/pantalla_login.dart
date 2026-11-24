import 'package:flutter/material.dart';

import '../logica/validaciones.dart';
import '../services/cuenta_service.dart';
import '../theme/lumina_tema.dart';
import '../widgets/cuentas_externas.dart';
import '../widgets/lumina_widgets.dart';

/// Al entrar, no navega por sí misma: la raíz de la app escucha el cambio
/// de sesión de Supabase y pasa a la siguiente pantalla.
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key, required this.alIrARegistro});

  final VoidCallback alIrARegistro;

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  // Los errores solo se muestran después de presionar "Iniciar sesión",
  // para no regañar al usuario mientras todavía está escribiendo.
  bool _intentoEnviar = false;
  bool _cargando = false;
  String? _errorServidor;

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

  // Solo consulta al servidor si el correo y la contraseña tienen buen formato.
  Future<void> _enviar() async {
    setState(() {
      _intentoEnviar = true;
      _errorServidor = null;
    });
    if (!_completo || _errorCorreo != null || _errorClave != null) return;

    await _conCarga(
      () => CuentaService.iniciarSesion(
        correo: _correo.text,
        clave: _clave.text,
      ),
    );
  }

  Future<void> _usarCuentaExterna(ProveedorCuenta proveedor) =>
      _conCarga(() => CuentaService.iniciarConProveedor(proveedor));

  Future<void> _conCarga(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _errorServidor = null;
    });
    try {
      await accion();
    } on ErrorCuenta catch (e) {
      if (mounted) setState(() => _errorServidor = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
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
                  if (_errorServidor != null) ...[
                    const SizedBox(height: 20),
                    MensajeFormulario(texto: _errorServidor!),
                  ],
                  const SizedBox(height: 20),
                  BotonPrimario(
                    texto: _cargando ? 'Entrando…' : 'Iniciar sesión',
                    onPressed: _completo && !_cargando ? _enviar : null,
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
                    alElegir: _usarCuentaExterna,
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
