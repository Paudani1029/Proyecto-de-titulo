import 'package:flutter/material.dart';

import '../theme/lumina_tema.dart';
import '../widgets/lumina_widgets.dart';

class _PasoGuia {
  const _PasoGuia(this.icono, this.etiqueta, this.titulo, this.descripcion);

  final IconData icono;
  final String etiqueta;
  final String titulo;
  final String descripcion;
} 
 
const List<_PasoGuia> _pasos = [
  _PasoGuia(
    Icons.photo_camera,
    'Paso 1 de 3',
    'Apunta la cámara',
    'Sostén el teléfono hacia el frente. Lumina observará el camino y todo lo que haya a tu alrededor.',
  ),
  _PasoGuia(
    Icons.document_scanner_outlined,
    'Paso 2 de 3',
    'Lumina reconoce y lee',
    'Identifica objetos y personas, y puede leer en voz alta carteles o señales importantes.',
  ),
  _PasoGuia(
    Icons.verified_user,
    'Paso 3 de 3',
    'Recibe avisos de peligro',
    'Te avisará de obstáculos, escalones, cruces y semáforos en rojo para ayudarte a avanzar con seguridad.',
  ),
];

class PantallaGuia extends StatefulWidget {
  const PantallaGuia({
    super.key,
    required this.alTerminar,
    required this.alVolver,
  });

  final VoidCallback alTerminar;
  final VoidCallback alVolver;

  @override
  State<PantallaGuia> createState() => _PantallaGuiaState();
}

class _PantallaGuiaState extends State<PantallaGuia> {
  int _paso = 0;

  @override
  Widget build(BuildContext context) {
    final c = LuminaColors.of(context);
    final actual = _pasos[_paso];
    final esUltimo = _paso == _pasos.length - 1;

    return ContenedorPantalla(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          // Logo + Omitir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const LuminaLogo(compacto: true),
              TextButton(
                onPressed: widget.alTerminar,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.brandStrong,
                ),
                child: Text(
                  'Omitir',
                  style: estiloTexto(16, FontWeight.w800, c.brandStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Barra de progreso
          Semantics(
            label: actual.etiqueta,
            child: Row(
              children: [
                for (var i = 0; i < _pasos.length; i++)
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: i <= _paso ? c.brand : c.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Contenido del paso
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 192,
                    height: 192,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.brandPale,
                      shape: BoxShape.circle,
                      boxShadow: LuminaColors.sombraTarjeta,
                    ),
                    child: Icon(actual.icono, size: 64, color: c.brand),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    actual.etiqueta.toUpperCase(),
                    style: estiloTexto(
                      16,
                      FontWeight.w800,
                      c.brandStrong,
                      espaciado: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    actual.titulo,
                    textAlign: TextAlign.center,
                    style: estiloTexto(
                      30,
                      FontWeight.w800,
                      c.ink,
                      altura: 1.2,
                      espaciado: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    actual.descripcion,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.successSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.volume_up, size: 28, color: c.successStrong),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Los avisos se escuchan en voz alta y también aparecen en pantalla.',
                            style: estiloTexto(
                              16,
                              FontWeight.w700,
                              c.successStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Atrás / Siguiente
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  if (_paso == 0) {
                    widget.alVolver();
                  } else {
                    setState(() => _paso--);
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  foregroundColor: c.ink,
                  side: BorderSide(color: c.border, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Atrás'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BotonPrimario(
                  texto: esUltimo ? 'Comenzar a usar Lumina' : 'Siguiente',
                  onPressed: () {
                    if (esUltimo) {
                      widget.alTerminar();
                    } else {
                      setState(() => _paso++);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
