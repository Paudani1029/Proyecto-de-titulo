import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camara_service.dart';
import '../services/phone_camera_service.dart';
import '../services/voz_service.dart';
import '../theme/lumina_tema.dart';
import '../widgets/hojas.dart';
import '../widgets/lumina_widgets.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
 
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  // --- Servicios (los mismos que ya tenías) ---
  final VozService _voz = VozService();
  final CameraService _servicioCamara = PhoneCameraService();
  StreamSubscription<String>? _suscripcion;

  // --- Estado de la pantalla ---
  bool _escuchando = true;
  bool _errorCamara = false;
  String _ultimoAviso = 'Conectando con la cámara...';
  final List<AvisoHistorial> _historial = [];

  // Se comparte con la hoja de Ajustes
  final ValueNotifier<bool> _camaraVisible = ValueNotifier<bool>(false);

  // Mensaje flotante breve ("Escucha pausada", etc.)
  String _anuncio = '';
  Timer? _temporizadorAnuncio;

  @override
  void initState() {
    super.initState();
    _iniciarConexion();
  }

  Future<void> _iniciarConexion() async {
    final exito = await _servicioCamara.conectar();
    if (!mounted) return;

    if (!exito) {
      setState(() {
        _errorCamara = true;
        _ultimoAviso = 'No se pudo conectar con la cámara.';
      });
      _voz.hablar(_ultimoAviso);
      return;
    }

    setState(() {
      _ultimoAviso = 'Cámara conectada. Esperando datos...';
    });
    _suscripcion = _servicioCamara.descripciones.listen(_alRecibirDescripcion);
  }

  void _alRecibirDescripcion(String texto) {
    if (!_escuchando || !mounted) return;

    setState(() {
      _ultimoAviso = texto;
      _historial.insert(0, AvisoHistorial(texto, DateTime.now()));
      if (_historial.length > 20) _historial.removeLast();
    });
    _voz.hablar(texto);
  }

  void _alternarEscucha() {
    setState(() => _escuchando = !_escuchando);
    if (!_escuchando) _voz.detener();
    _mostrarAnuncio(_escuchando ? 'Escucha reanudada' : 'Escucha pausada');
  }

  void _repetir() {
    _mostrarAnuncio('Repitiendo el último mensaje');
    _voz.hablar(_ultimoAviso);
  }

  void _mostrarAnuncio(String texto) {
    _temporizadorAnuncio?.cancel();
    setState(() => _anuncio = texto);
    _temporizadorAnuncio = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _anuncio = '');
    });
  }

  void _abrirAyuda() => mostrarHojaAyuda(context);

  void _abrirAjustes() {
    mostrarHojaAjustes(
      context,
      camaraVisible: _camaraVisible,
      historial: List<AvisoHistorial>.of(_historial),
      alActivarCamara: () =>
          _mostrarAnuncio('Cámara visible en la pantalla principal'),
    );
  }

  @override
  void dispose() {
    _temporizadorAnuncio?.cancel();
    _suscripcion?.cancel();
    _servicioCamara.desconectar();
    _voz.detener();
    _camaraVisible.dispose();
    super.dispose();
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
            child: ValueListenableBuilder<bool>(
              valueListenable: _camaraVisible,
              builder: (context, camaraVisible, _) {
                return Column(
                  children: [
                    _encabezado(c),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          children: [
                            if (camaraVisible) _tarjetaCamara(c),
                            Expanded(child: _botonEscucha(c, camaraVisible)),
                            _tarjetaUltimoAviso(c),
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
            'Escucha',
            style: estiloTexto(20, FontWeight.w800, c.ink, espaciado: -0.3),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _escuchando ? c.successSoft : c.warningSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _escuchando ? c.success : c.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _escuchando ? 'Activo' : 'En pausa',
                  style: estiloTexto(
                    14,
                    FontWeight.w700,
                    _escuchando ? c.successStrong : c.warningStrong,
                  ),
                ),
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
    // Por ahora la vista previa solo existe para la cámara del teléfono.
    // Cuando llegue la ESP32-S3 habrá que mostrar su imagen de otra forma.
    final servicio = _servicioCamara;
    final controlador =
        servicio is PhoneCameraService ? servicio.controller : null;
    final listo = controlador != null && controlador.value.isInitialized;

    Widget contenido;
    if (_errorCamara) {
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

  Widget _botonEscucha(LuminaColors c, bool camaraVisible) {
    final tamAnillo = camaraVisible ? 128.0 : 176.0;
    final tamBoton = camaraVisible ? 96.0 : 144.0;
    final tamIcono = camaraVisible ? 44.0 : 64.0;

    // Igual que el CSS: sin anillos si el usuario pidió menos animaciones
    // o si la pantalla es baja.
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.sizeOf(context).height < 720;

    return Semantics(
      button: true,
      label: _escuchando
          ? 'Pausar la escucha del entorno'
          : 'Reanudar la escucha del entorno',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _alternarEscucha,
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
                        if (_escuchando && !sinAnimaciones)
                          AnilloPulso(color: c.brandSoft, tamano: tamAnillo),
                        Container(
                          width: tamBoton,
                          height: tamBoton,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _escuchando ? c.brand : c.surfaceMuted,
                            shape: BoxShape.circle,
                            boxShadow: LuminaColors.sombraControl,
                          ),
                          child: Icon(
                            _escuchando ? Icons.mic : Icons.play_arrow,
                            size: tamIcono,
                            color: _escuchando ? c.onBrand : c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: camaraVisible ? 12 : 32),
                  Text(
                    _escuchando ? 'Escuchando' : 'Escucha pausada',
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
                      _escuchando
                          ? 'Toca el círculo para pausar'
                          : 'Toca el círculo para continuar',
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

  Widget _tarjetaUltimoAviso(LuminaColors c) {
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
                'ÚLTIMO AVISO',
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
            _ultimoAviso,
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
              icono: _escuchando ? Icons.pause : Icons.play_arrow,
              etiqueta: _escuchando ? 'Pausar' : 'Continuar',
              onTap: _alternarEscucha,
              activo: !_escuchando,
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
