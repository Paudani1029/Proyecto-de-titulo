import 'package:flutter/material.dart';

import '../theme/lumina_tema.dart';

/// Marco común de las pantallas: fondo, ancho máximo de 448 px (como en Figma)
/// y, opcionalmente, scroll para que el teclado no tape nada.
class ContenedorPantalla extends StatelessWidget {
  const ContenedorPantalla({
    super.key,
    required this.child,
    this.fondo,
    this.padding = EdgeInsets.zero,
    this.desplazable = true,
    this.decoracion,
  });

  final Widget child;
  final Color? fondo;
  final EdgeInsetsGeometry padding;
  final bool desplazable;

  /// Debe ser un widget Positioned (círculo decorativo de la bienvenida).
  final Widget? decoracion;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    Widget contenido = Padding(padding: padding, child: child);

    if (desplazable) {
      contenido = LayoutBuilder(
        builder: (context, restricciones) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: IntrinsicHeight(
                child: Padding(padding: padding, child: child),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: fondo ?? c.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  boxShadow: LuminaColors.sombraApp,
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      ?decoracion,
                      Positioned.fill(child: contenido),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo: cuadrado azul con el ícono de oreja y el puntito rojo.
class LuminaLogo extends StatelessWidget {
  const LuminaLogo({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final lado = compacto ? 48.0 : 64.0;

    return Semantics(
      label: 'Lumina',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: lado,
                  height: lado,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: LuminaColors.sombraControl,
                  ),
                  child: Icon(
                    Icons.hearing,
                    size: compacto ? 28 : 36,
                    color: c.onBrand,
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: LuminaColors.live,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              'Lumina',
              style: estiloTexto(
                compacto ? 24 : 36,
                FontWeight.w800,
                c.ink,
                espaciado: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón azul grande. Si onPressed es null, se ve deshabilitado (gris).
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.altura = 64,
    this.tamanoTexto = 20,
  });

  final String texto;
  final VoidCallback? onPressed;
  final double altura;
  final double tamanoTexto;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null ? null : LuminaColors.sombraControl,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.toggle,
          disabledForegroundColor: c.onBrand,
          minimumSize: Size.fromHeight(altura),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontSize: tamanoTexto,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(texto, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Botón de la barra inferior (Pausar, Repetir, Ayuda, Ajustes).
class BotonAccion extends StatelessWidget {
  const BotonAccion({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.activo = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final color = activo ? c.brand : c.inkMuted;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: activo,
        child: Material(
          color: activo ? c.brandPale : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icono, size: 28, color: color),
                    const SizedBox(height: 6),
                    // FittedBox: si el usuario agranda la letra del sistema,
                    // la etiqueta se achica en vez de desbordarse.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        etiqueta,
                        style: estiloTexto(16, FontWeight.w700, color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interruptor (switch) del diseño: 64 x 36 con área táctil de 48.
class LuminaToggle extends StatelessWidget {
  const LuminaToggle({
    super.key,
    required this.activo,
    required this.onCambio,
    required this.etiqueta,
  });

  final bool activo;
  final VoidCallback onCambio;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return Semantics(
      label: etiqueta,
      toggled: activo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCambio,
        child: SizedBox(
          width: 64,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: activo ? c.brand : c.toggle,
                borderRadius: BorderRadius.circular(18),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    activo ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: LuminaColors.sombraInterruptor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dos anillos que "laten" detrás del botón de escucha (animación pulse-ring).
class AnilloPulso extends StatefulWidget {
  const AnilloPulso({super.key, required this.color, required this.tamano});

  final Color color;
  final double tamano;

  @override
  State<AnilloPulso> createState() => _AnilloPulsoState();
}

class _AnilloPulsoState extends State<AnilloPulso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  // Misma curva que el CSS: del 0% al 75% crece y se desvanece; el resto, invisible.
  double _opacidad(double p) => p >= 0.75 ? 0.0 : 0.8 * (1 - p / 0.75);
  double _escala(double p) => p >= 0.75 ? 1.0 : 0.72 + 0.28 * (p / 0.75);

  Widget _anillo(double p) {
    return Opacity(
      opacity: _opacidad(p),
      child: Transform.scale(
        scale: _escala(p),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.tamano,
      height: widget.tamano,
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, _) {
          final p1 = _controlador.value;
          final p2 = (_controlador.value + 0.5) % 1.0;
          return Stack(
            fit: StackFit.expand,
            children: [_anillo(p1), _anillo(p2)],
          );
        },
      ),
    );
  }
}
