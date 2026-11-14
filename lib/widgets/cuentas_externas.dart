import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/lumina_tema.dart';

/// Servicios con los que el usuario puede entrar sin escribir.
enum ProveedorCuenta { google, correo }

/// Línea divisoria con un texto al centro ("o continúa con").
class SeparadorTexto extends StatelessWidget {
  const SeparadorTexto({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final linea = Expanded(child: Divider(color: c.border, thickness: 2));

    return Row(
      children: [
        linea,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(texto, style: estiloTexto(16, FontWeight.w700, c.inkMuted)),
        ),
        linea,
      ],
    );
  }
}

/// Fila con los botones de Google y Correo (solo el logo, como en otras apps).
///
/// Aunque visualmente solo se ve el logo, cada botón tiene una etiqueta para
/// el lector de pantalla (TalkBack / VoiceOver), p. ej. "Continuar con Google".
class BotonesCuentaExterna extends StatelessWidget {
  const BotonesCuentaExterna({
    super.key,
    required this.accion,
    required this.alElegir,
  });

  /// Verbo que lee el lector de pantalla: "Continuar", "Registrarte", etc.
  final String accion;
  final ValueChanged<ProveedorCuenta> alElegir;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BotonLogo(
            etiqueta: '$accion con Google',
            logo: const LogoGoogle(),
            onTap: () => alElegir(ProveedorCuenta.google),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _BotonLogo(
            etiqueta: '$accion con tu correo Outlook',
            logo: const LogoCorreo(),
            onTap: () => alElegir(ProveedorCuenta.correo),
          ),
        ),
      ],
    );
  }
}

class _BotonLogo extends StatelessWidget {
  const _BotonLogo({
    required this.etiqueta,
    required this.logo,
    required this.onTap,
  });

  final String etiqueta;
  final Widget logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: Tooltip(
        message: etiqueta,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            backgroundColor: c.surface,
            side: BorderSide(color: c.border, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: SizedBox.square(dimension: 32, child: logo),
        ),
      ),
    );
  }
}

/// Logo "G" de Google dibujado con código (sin imágenes ni paquetes extra).
class LogoGoogle extends StatelessWidget {
  const LogoGoogle({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _PintorGoogle());
}

class _PintorGoogle extends CustomPainter {
  const _PintorGoogle();

  static const _azul = Color(0xFF4285F4);
  static const _verde = Color(0xFF34A853);
  static const _amarillo = Color(0xFFFBBC05);
  static const _rojo = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final grosor = lado * 0.2;
    final centro = size.center(Offset.zero);
    final radio = (lado - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    double rad(double grados) => grados * math.pi / 180;

    void arco(Color color, double desde, double hasta) {
      canvas.drawArc(
        rect,
        rad(desde),
        rad(hasta - desde),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor,
      );
    }

    // Ángulos en sentido horario desde las 3 en punto. El hueco queda arriba a la derecha.
    arco(_azul, 0, 45);
    arco(_verde, 45, 155);
    arco(_amarillo, 155, 215);
    arco(_rojo, 215, 318);

    // Barra horizontal de la "G"
    canvas.drawRect(
      Rect.fromLTRB(
        centro.dx,
        centro.dy - grosor / 2,
        centro.dx + radio + grosor / 2,
        centro.dy + grosor / 2,
      ),
      Paint()..color = _azul,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo de correo (sobre azul estilo Outlook), dibujado con código.
class LogoCorreo extends StatelessWidget {
  const LogoCorreo({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _PintorCorreo());
}

class _PintorCorreo extends CustomPainter {
  const _PintorCorreo();

  static const _azul = Color(0xFF0078D4);
  static const _azulOscuro = Color(0xFF0A5BA8);

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width;
    final alto = size.height * 0.72;
    final arriba = (size.height - alto) / 2;
    final sobre = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, arriba, ancho, alto),
      Radius.circular(ancho * 0.12),
    );

    canvas.drawRRect(sobre, Paint()..color = _azul);

    // Solapa del sobre (la "V")
    final solapa = Path()
      ..moveTo(ancho * 0.06, arriba + alto * 0.12)
      ..lineTo(ancho / 2, arriba + alto * 0.58)
      ..lineTo(ancho * 0.94, arriba + alto * 0.12);
    canvas.drawPath(
      solapa,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = ancho * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Borde inferior un poco más oscuro para dar volumen
    canvas.drawRRect(
      sobre,
      Paint()
        ..color = _azulOscuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = ancho * 0.04,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
