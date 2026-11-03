import 'package:flutter/material.dart';

import '../models/aviso_historial.dart';
import '../services/banco_pruebas.dart';
import '../services/detector_onnx.dart';
import '../theme/lumina_tema.dart';
import 'lumina_widgets.dart';

/// Hoja "¿Necesitas ayuda?"
Future<void> mostrarHojaAyuda(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: LuminaColors.claro.overlay,
    constraints: const BoxConstraints(maxWidth: 448),
    builder: (contexto) => const _ContenidoAyuda(),
  );
}

/// Hoja "Ajustes". [camaraVisible] se comparte con la pantalla principal.
Future<void> mostrarHojaAjustes(
  BuildContext context, {
  required ValueNotifier<bool> camaraVisible,
  required List<AvisoHistorial> historial,
  required VoidCallback alActivarCamara,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: LuminaColors.claro.overlay,
    constraints: const BoxConstraints(maxWidth: 448),
    builder: (contexto) => _ContenidoAjustes(
      camaraVisible: camaraVisible,
      historial: historial,
      alActivarCamara: alActivarCamara,
    ),
  );
}

/// Fondo redondeado de las hojas. Pinta su propio color para que cambie al
/// instante si el usuario activa el modo oscuro con la hoja abierta.
class _HojaBase extends StatelessWidget {
  const _HojaBase({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final alturaMaxima = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: alturaMaxima),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: LuminaColors.sombraHoja,
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _BotonCerrar extends StatelessWidget {
  const _BotonCerrar({required this.etiqueta});

  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return Semantics(
      button: true,
      label: etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: 24, color: c.ink),
        ),
      ),
    );
  }
}

class _ContenidoAyuda extends StatelessWidget {
  const _ContenidoAyuda();

  Widget _linea(LuminaColors c, String negrita, String resto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: negrita,
              style: estiloTexto(18, FontWeight.w800, c.ink, altura: 1.5),
            ),
            TextSpan(
              text: resto,
              style: estiloTexto(18, FontWeight.w400, c.ink, altura: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return _HojaBase(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Necesitas ayuda?',
                      style: estiloTexto(24, FontWeight.w800, c.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca el círculo y di una de estas frases.',
                      style: estiloTexto(18, FontWeight.w400, c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const _BotonCerrar(etiqueta: 'Cerrar ayuda'),
            ],
          ),
          const SizedBox(height: 20),
          _linea(c, '“¿Qué tengo enfrente?”', ' describe lo que ve la cámara.'),
          _linea(c, '“¿Dónde está la botella?”', ' busca un objeto y dice dónde está.'),
          _linea(c, '“Guía mi camino”', ' activa el modo guía con avisos de obstáculos.'),
          _linea(c, '“Para”', ' termina la guía.'),
          _linea(c, '“Repite”', ' vuelve a decir el último mensaje.'),
          const SizedBox(height: 12),
          BotonPrimario(
            texto: 'Entendido',
            altura: 56,
            tamanoTexto: 18,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _IconoCaja extends StatelessWidget {
  const _IconoCaja(this.icono);

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.iconSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icono, size: 28, color: c.brand),
    );
  }
}

/// Tarjeta de un ajuste: ícono, título, descripción, interruptor y nota opcional.
class _TarjetaAjuste extends StatelessWidget {
  const _TarjetaAjuste({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.interruptor,
    this.nota,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget interruptor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _IconoCaja(icono),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: estiloTexto(20, FontWeight.w800, c.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            descripcion,
                            style: estiloTexto(
                              16,
                              FontWeight.w400,
                              c.inkMuted,
                              altura: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              interruptor,
            ],
          ),
          if (nota != null) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: c.border),
            const SizedBox(height: 16),
            Text(
              nota!,
              style: estiloTexto(
                16,
                FontWeight.w600,
                c.inkMuted,
                altura: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContenidoAjustes extends StatelessWidget {
  const _ContenidoAjustes({
    required this.camaraVisible,
    required this.historial,
    required this.alActivarCamara,
  });

  final ValueNotifier<bool> camaraVisible;
  final List<AvisoHistorial> historial;
  final VoidCallback alActivarCamara;

  String _hace(DateTime hora) {
    final minutos = DateTime.now().difference(hora).inMinutes;
    if (minutos < 1) return 'Ahora';
    if (minutos == 1) return 'Hace 1 minuto';
    return 'Hace $minutos minutos';
  }

  Widget _tarjetaHistorial(BuildContext context, LuminaColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconoCaja(Icons.history),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de avisos',
                      style: estiloTexto(20, FontWeight.w800, c.ink),
                    ),
                    Text(
                      'Avisos recientes',
                      style: estiloTexto(16, FontWeight.w400, c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (historial.isEmpty)
            Text(
              'Aún no hay avisos. Aparecerán aquí a medida que Lumina los diga.',
              style: estiloTexto(
                18,
                FontWeight.w600,
                c.inkMuted,
                altura: 1.5,
              ),
            ),
          for (var i = 0; i < historial.length; i++) ...[
            if (i > 0) Container(height: 1, color: c.border),
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : 16,
                bottom: i == historial.length - 1 ? 0 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hace(historial[i].hora),
                    style: estiloTexto(
                      14,
                      FontWeight.w700,
                      i == 0 ? c.brand : c.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    historial[i].texto,
                    style: estiloTexto(
                      18,
                      FontWeight.w600,
                      c.ink,
                      altura: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return _HojaBase(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajustes',
                      style: estiloTexto(30, FontWeight.w800, c.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personaliza la aplicación para ti.',
                      style: estiloTexto(18, FontWeight.w400, c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const _BotonCerrar(etiqueta: 'Cerrar ajustes'),
            ],
          ),
          const SizedBox(height: 24),

          // Modo oscuro
          _TarjetaAjuste(
            icono: Icons.dark_mode,
            titulo: 'Modo oscuro',
            descripcion: 'Reduce el brillo de la pantalla.',
            interruptor: ValueListenableBuilder<bool>(
              valueListenable: modoOscuro,
              builder: (context, activo, _) {
                return LuminaToggle(
                  activo: activo,
                  etiqueta: 'Activar modo oscuro',
                  onCambio: () => modoOscuro.value = !activo,
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Ver la cámara
          _TarjetaAjuste(
            icono: Icons.photo_camera,
            titulo: 'Ver la cámara',
            descripcion: 'Muestra lo que está observando.',
            nota: 'Al activarla, la imagen aparecerá en la pantalla principal.',
            interruptor: ValueListenableBuilder<bool>(
              valueListenable: camaraVisible,
              builder: (context, activa, _) {
                return LuminaToggle(
                  activo: activa,
                  etiqueta: 'Mostrar lo que ve la cámara',
                  onCambio: () {
                    if (!activa) {
                      camaraVisible.value = true;
                      Navigator.of(context).pop();
                      alActivarCamara();
                    } else {
                      camaraVisible.value = false;
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Historial
          _tarjetaHistorial(context, c),
          const SizedBox(height: 16),

          // Comparar modelos de detección (herramienta de desarrollo)
          const _TarjetaBanco(),
        ],
      ),
    );
  }
}

/// Banco de pruebas: elegir modelo y acelerador, y ver tiempos y temperatura.
/// Es una herramienta de desarrollo para comparar modelos en el teléfono real.
class _TarjetaBanco extends StatelessWidget {
  const _TarjetaBanco();

  Widget _opcion<T>(
    LuminaColors c, {
    required String texto,
    required T valor,
    required T actual,
    required ValueChanged<T> alElegir,
  }) {
    final elegido = valor == actual;
    return Semantics(
      button: true,
      selected: elegido,
      child: Material(
        color: elegido ? c.brand : c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => alElegir(valor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: elegido ? c.brand : c.border),
            ),
            child: Text(
              texto,
              style: estiloTexto(
                16,
                FontWeight.w700,
                elegido ? c.onBrand : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final banco = BancoPruebas.instancia;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: ValueListenableBuilder<ConfigDeteccion>(
        valueListenable: configDeteccion,
        builder: (context, config, _) {
          void cambiar(ConfigDeteccion nueva) {
            if (nueva == configDeteccion.value) return;
            configDeteccion.value = nueva;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconoCaja(Icons.speed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Banco de pruebas',
                          style: estiloTexto(20, FontWeight.w800, c.ink),
                        ),
                        Text(
                          'Compara modelos de detección.',
                          style: estiloTexto(16, FontWeight.w400, c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Modelo', style: estiloTexto(16, FontWeight.w700, c.inkMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in ModeloDeteccion.values)
                    _opcion<ModeloDeteccion>(
                      c,
                      texto: m.nombre,
                      valor: m,
                      actual: config.modelo,
                      alElegir: (v) =>
                          cambiar(ConfigDeteccion(v, config.acelerador)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Acelerador',
                  style: estiloTexto(16, FontWeight.w700, c.inkMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in Acelerador.values)
                    _opcion<Acelerador>(
                      c,
                      texto: a.nombre,
                      valor: a,
                      actual: config.acelerador,
                      alElegir: (v) => cambiar(ConfigDeteccion(config.modelo, v)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: c.border),
              const SizedBox(height: 16),
              ValueListenableBuilder<ResumenBanco?>(
                valueListenable: banco.resumen,
                builder: (context, r, _) {
                  return Text(
                    r?.texto ??
                        'Sin mediciones todavía. Activa el modo guía y espera '
                            'unos segundos.',
                    style: estiloTexto(16, FontWeight.w600, c.ink, altura: 1.5),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: banco.reiniciar,
                child: Text(
                  'Reiniciar mediciones',
                  style: estiloTexto(16, FontWeight.w700, c.brand),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
