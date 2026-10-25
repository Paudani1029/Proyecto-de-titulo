import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../logica/asistente.dart';
import '../theme/lumina_tema.dart';
import '../widgets/hojas.dart';
import '../widgets/lumina_widgets.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  // El "cerebro": cámara, detector, voz y comandos viven en Asistente.
  final Asistente _asistente = Asistente();

  // Se comparte con la hoja de Ajustes
  final ValueNotifier<bool> _camaraVisible = ValueNotifier<bool>(false);

  // Mensaje flotante breve ("Modo guía activado", etc.)
  String _anuncio = '';
  Timer? _temporizadorAnuncio;

  @override
  void initState() {
    super.initState();
    unawaited(_asistente.iniciar());
  }

  void _mostrarAnuncio(String texto) {
    _temporizadorAnuncio?.cancel();
    setState(() => _anuncio = texto);
    _temporizadorAnuncio = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _anuncio = '');
    });
  }

  void _alternarGuia() {
    _asistente.alternarGuia();
    _mostrarAnuncio(
      _asistente.modoGuia ? 'Modo guía activado' : 'Modo guía desactivado',
    );
  }

  void _repetir() {
    _asistente.repetirUltimo();
    _mostrarAnuncio('Repitiendo el último mensaje');
  }

  void _abrirAyuda() => mostrarHojaAyuda(context);

  void _abrirAjustes() {
    mostrarHojaAjustes(
      context,
      camaraVisible: _camaraVisible,
      historial: _asistente.historial,
      alActivarCamara: () =>
          _mostrarAnuncio('Cámara visible en la pantalla principal'),
    );
  }

  @override
  void dispose() {
    _temporizadorAnuncio?.cancel();
    _asistente.dispose();
    _camaraVisible.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Textos e íconos según lo que está haciendo Lumina
  // ------------------------------------------------------------------

  ({String titulo, String pista, IconData icono, String etiquetaBoton})
      _textos(EstadoAsistente e) {
    switch (e) {
      case EstadoAsistente.conectando:
        return (
          titulo: 'Preparando…',
          pista: 'Abriendo la cámara',
          icono: Icons.hourglass_top,
          etiquetaBoton: 'Lumina se está preparando',
        );
      case EstadoAsistente.sinCamara:
        return (
          titulo: 'Sin cámara',
          pista: 'Revisa el permiso de la cámara',
          icono: Icons.videocam_off,
          etiquetaBoton: 'La cámara no está disponible',
        );
      case EstadoAsistente.atento:
        return (
          titulo: 'Toca para hablar',
          pista: 'Pregúntame: “¿Qué tengo enfrente?”',
          icono: Icons.mic,
          etiquetaBoton: 'Toca para hablar con Lumina',
        );
      case EstadoAsistente.escuchando:
        return (
          titulo: 'Te escucho',
          pista: 'Habla ahora. Toca de nuevo para cancelar',
          icono: Icons.mic,
          etiquetaBoton: 'Cancelar escucha',
        );
      case EstadoAsistente.pensando:
        return (
          titulo: 'Mirando…',
          pista: 'Un momento',
          icono: Icons.visibility,
          etiquetaBoton: 'Lumina está mirando',
        );
      case EstadoAsistente.guiando:
        return (
          titulo: 'Modo guía',
          pista: 'Toca para hablar. Di “para” para terminar',
          icono: Icons.mic,
          etiquetaBoton: 'Modo guía activo. Toca para hablar con Lumina',
        );
    }
  }

  // ------------------------------------------------------------------
  // Construcción de la interfaz
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return ContenedorPantalla(
      desplazable: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: Listenable.merge([_asistente, _camaraVisible]),
              builder: (context, _) {
                final camaraVisible = _camaraVisible.value;
                return Column(
                  children: [
                    _encabezado(c),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          children: [
                            if (camaraVisible) _tarjetaCamara(c),
                            Expanded(child: _botonHablar(c, camaraVisible)),
                            _tarjetaUltimoMensaje(c),
                            _barraControles(c),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_anuncio.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 112,
              child: Center(child: _mensajeFlotante(c)),
            ),
        ],
      ),
    );
  }

  Widget _encabezado(LuminaColors c) {
    final estado = _asistente.estado;

    // Valores iniciales (los del estado "atento"); el switch los cambia si hace falta
    String etiqueta = 'Atento';
    Color fondo = c.successSoft;
    Color punto = c.success;
    Color texto = c.successStrong;
    switch (estado) {
      case EstadoAsistente.atento:
        etiqueta = 'Atento';
        fondo = c.successSoft;
        punto = c.success;
        texto = c.successStrong;
      case EstadoAsistente.sinCamara:
        etiqueta = 'Sin cámara';
        fondo = c.warningSoft;
        punto = c.warning;
        texto = c.warningStrong;
      case EstadoAsistente.escuchando:
        etiqueta = 'Te escucho';
        fondo = c.brandPale;
        punto = c.brand;
        texto = c.brandStrong;
      case EstadoAsistente.pensando:
        etiqueta = 'Mirando';
        fondo = c.brandPale;
        punto = c.brand;
        texto = c.brandStrong;
      case EstadoAsistente.guiando:
        etiqueta = 'Guiando';
        fondo = c.brandPale;
        punto = c.brand;
        texto = c.brandStrong;
      case EstadoAsistente.conectando:
        etiqueta = 'Preparando';
        fondo = c.brandPale;
        punto = c.brand;
        texto = c.brandStrong;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hearing, size: 24, color: c.onBrand),
          ),
          const SizedBox(width: 10),
          Text(
            'Lumina',
            style: estiloTexto(20, FontWeight.w800, c.ink, espaciado: -0.3),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(etiqueta, style: estiloTexto(14, FontWeight.w700, texto)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeCamara(String texto) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 176),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_camera, size: 40, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: estiloTexto(16, FontWeight.w600, Colors.white, altura: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCamara(LuminaColors c) {
    final controlador = _asistente.controladorCamara;
    final listo = controlador != null && controlador.value.isInitialized;

    Widget contenido;
    if (_asistente.errorCamara) {
      contenido = _mensajeCamara(
        'No pudimos abrir la cámara. Revisa el permiso de cámara del dispositivo.',
      );
    } else if (!listo) {
      contenido = _mensajeCamara('Conectando con la cámara...');
    } else {
      contenido = _vistaEnVivo(controlador);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LuminaColors.camera,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.brandBorder),
        boxShadow: LuminaColors.sombraTarjeta,
      ),
      child: contenido,
    );
  }

  Widget _vistaEnVivo(CameraController controlador) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // "Cover": llena el recuadro recortando lo que sobre
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 100,
                height: 100 * controlador.value.aspectRatio,
                child: CameraPreview(controlador),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LuminaColors.cameraLabel,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: LuminaColors.live,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cámara en vivo',
                    style: estiloTexto(14, FontWeight.w800, Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Semantics(
              button: true,
              label: 'Ocultar cámara',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _camaraVisible.value = false,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: LuminaColors.cameraLabel,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonHablar(LuminaColors c, bool camaraVisible) {
    final estado = _asistente.estado;
    final textos = _textos(estado);
    final sinCamara = estado == EstadoAsistente.sinCamara;

    final tamAnillo = camaraVisible ? 128.0 : 176.0;
    final tamBoton = camaraVisible ? 96.0 : 144.0;
    final tamIcono = camaraVisible ? 44.0 : 64.0;

    // Los anillos que "laten" significan: el micrófono está abierto.
    // Se omiten si el usuario pidió menos animaciones o la pantalla es baja.
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.sizeOf(context).height < 720;

    return Semantics(
      button: true,
      label: textos.etiquetaBoton,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _asistente.tocarCirculo,
        child: Center(
          // FittedBox: si falta espacio, el bloque se achica en vez de desbordarse
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: tamAnillo,
                    height: tamAnillo,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (estado == EstadoAsistente.escuchando &&
                            !sinAnimaciones)
                          AnilloPulso(color: c.brandSoft, tamano: tamAnillo),
                        Container(
                          width: tamBoton,
                          height: tamBoton,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sinCamara ? c.surfaceMuted : c.brand,
                            shape: BoxShape.circle,
                            boxShadow: LuminaColors.sombraControl,
                          ),
                          child: Icon(
                            textos.icono,
                            size: tamIcono,
                            color: sinCamara ? c.inkMuted : c.onBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: camaraVisible ? 12 : 32),
                  Text(
                    textos.titulo,
                    textAlign: TextAlign.center,
                    style: estiloTexto(
                      camaraVisible ? 24 : 30,
                      FontWeight.w800,
                      c.ink,
                      espaciado: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      textos.pista,
                      textAlign: TextAlign.center,
                      style: estiloTexto(
                        18,
                        FontWeight.w500,
                        c.inkMuted,
                        altura: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaUltimoMensaje(LuminaColors c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.brandPale,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.brandBorder),
        boxShadow: LuminaColors.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up, size: 20, color: c.brandStrong),
              const SizedBox(width: 8),
              Text(
                'ÚLTIMO MENSAJE',
                style: estiloTexto(
                  14,
                  FontWeight.w800,
                  c.brandStrong,
                  espaciado: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _asistente.ultimoMensaje,
            style: estiloTexto(18, FontWeight.w600, c.ink, altura: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _barraControles(LuminaColors c) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: BotonAccion(
              icono: Icons.explore,
              etiqueta: 'Guía',
              onTap: _alternarGuia,
              activo: _asistente.modoGuia,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonAccion(
              icono: Icons.repeat,
              etiqueta: 'Repetir',
              onTap: _repetir,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonAccion(
              icono: Icons.help_outline,
              etiqueta: 'Ayuda',
              onTap: _abrirAyuda,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonAccion(
              icono: Icons.settings,
              etiqueta: 'Ajustes',
              onTap: _abrirAjustes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeFlotante(LuminaColors c) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(999),
          boxShadow: LuminaColors.sombraToast,
        ),
        child: Text(
          _anuncio,
          textAlign: TextAlign.center,
          // c.surface: blanco en modo claro, oscuro en modo oscuro (siempre legible sobre c.ink)
          style: estiloTexto(16, FontWeight.w700, c.surface),
        ),
      ),
    );
  }
}
