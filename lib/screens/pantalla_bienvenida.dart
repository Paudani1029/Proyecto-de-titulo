import 'package:flutter/material.dart';

import '../theme/lumina_tema.dart';
import '../widgets/lumina_widgets.dart';

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key, required this.alContinuar});

  final VoidCallback alContinuar;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);

    return ContenedorPantalla(
      fondo: c.welcome,
      decoracion: Positioned(
        right: -96,
        top: -80,
        child: Container(
          width: 288,
          height: 288,
          decoration: BoxDecoration(color: c.brandPale, shape: BoxShape.circle),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: LuminaLogo(compacto: true),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ilustración: cámara con escudo
                  SizedBox(
                    width: 224,
                    height: 224,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.5,
                          child: Container(
                            width: 224,
                            height: 224,
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            color: c.brandPale,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 128,
                          height: 128,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.brand,
                            shape: BoxShape.circle,
                            boxShadow: LuminaColors.sombraControl,
                          ),
                          child: Icon(
                            Icons.photo_camera,
                            size: 64,
                            color: c.onBrand,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 16,
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 4),
                              boxShadow: LuminaColors.sombraTarjeta,
                            ),
                            child: Icon(
                              Icons.verified_user,
                              size: 36,
                              color: c.onBrand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '¡Bienvenido a Lumina!',
                    textAlign: TextAlign.center,
                    style: estiloTexto(
                      36,
                      FontWeight.w800,
                      c.ink,
                      altura: 1.15,
                      espaciado: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu asistente visual para moverte con mayor seguridad e independencia.',
                    textAlign: TextAlign.center,
                    style: estiloTexto(
                      20,
                      FontWeight.w500,
                      c.inkMuted,
                      altura: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.brandPale,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.brandBorder),
                    ),
                    child: Text(
                      'Lumina observa el entorno con la cámara y te avisa mediante mensajes de voz.',
                      style: estiloTexto(
                        18,
                        FontWeight.w700,
                        c.ink,
                        altura: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BotonPrimario(
            texto: 'Conocer cómo funciona',
            onPressed: alContinuar,
          ),
        ],
      ),
    );
  }
}
 