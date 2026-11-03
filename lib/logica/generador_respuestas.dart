import '../models/catalogo_clases.dart';
import '../models/deteccion.dart';

// ---------------------------------------------------------------------------
// Umbrales. Son una APROXIMACIÓN: sin sensor de distancia, "cerca" se estima
// por el tamaño del objeto en la foto. Hay que calibrarlos con pruebas reales.
// ---------------------------------------------------------------------------

/// Un objeto "muy cerca" ocupa al menos esta fracción de la altura de la foto.
const double umbralMuyCerca = 0.35;

/// Vehículos y animales: alerta si el alto del recuadro supera esto.
const double umbralVehiculoVigilancia = 0.20;
const double umbralVehiculoGuia = 0.20;

// PERSONAS 
/// Persona muy cerca (solo en modo guía).
const double umbralPersonaGuia = 0.40;

// Rel cerca = 0.25
const double umbralPersonaCerca = 0.25;

// Lejos = 0.2
const double umbralPersonaLejos = 0.20;

// Muy Lejos = 0.15
const double umbralPersonaMuyLejos = 0.15;


// OBJETOS
/// Obstáculo fijo (banca, silla...) adelante (solo en modo guía).
const double umbralObstaculoGuia = 0.40;

// 1.5 metros = 12%
// 2 metros = 10%
const double umbralCerca = 0.10;

// 4.5 metros = 6.75%
// unos 5 metros = 5% aprox
const double umbralLejos = 0.05; 


/// Lo que se mueve y puede atropellar o empujar: avisa aunque no esté en modo guía.
const Set<String> _vehiculosYAnimales = {
  // COCO
  'car',
  'truck',
  'bus',
  'motorcycle',
  'bicycle',
  'train',
  'dog',
  'horse',
  // Objects365
  'suv',
  'van',
  'pickup truck',
  'sports car',
  'heavy truck',
  'fire truck',
  'ambulance',
  'machinery vehicle',
  'formula 1',
  'scooter',
  'hoverboard',
  'tricycle',
  'rickshaw',
  'carriage',
  'crane',
};

/// Obstáculos para el modo guía. Solo sirven nombres que el modelo activo de
/// verdad entrega (ver clases_coco.dart y clases_obj365.dart).
///
/// Las clases propias de Lumina (escaleras, puertas, soleras...) solo aparecen con
/// el modelo entrenado en herramientas/entrenamiento/. Con los modelos públicos
/// nunca llegan, así que tenerlas aquí no cambia nada hasta entonces.
const Set<String> _obstaculosFijos = {
  // Propias de Lumina (modelo entrenado)
  'stairs',
  'escalator',
  'door',
  'curb',
  'pole',
  'bollard',
  'pothole',
  'manhole',
  'barrier',
  'ramp',
  'scaffolding',
  'wet floor sign',
  // Muebles
  'bench',
  'chair',
  'stool',
  'couch',
  'dining table',
  'desk',
  'coffee table',
  'side table',
  'nightstand',
  'cabinet/shelf',
  'bed',
  'piano',
  // Calle
  'fire hydrant',
  'parking meter',
  'trash bin can',
  'traffic cone',
  'street lights',
  'traffic sign',
  'stop sign',
  'speed limit sign',
  'crosswalk sign',
  'hurdle',
  'barrel/bucket',
  'potted plant',
  'awning',
  'tent',
  // Cosas en el camino
  'ladder',
  'wheelchair',
  'stroller',
  'trolley',
  'suitcase',
  'storage box',
  'tripod',
  'swing',
  'slide',
  'fan',
  'radiator',
  // Cocina y baño
  'refrigerator',
  'oven',
  'gas stove',
  'washing machine/drying machine',
  'toilet',
  'sink',
  'bathtub',
  // Objetos chicos (solo avisan cuando están muy cerca)
  'sports ball',
  'pen/pencil',
  'bottle',
  'cup',
  'wine glass',
  'plate',
  'bowl',
  'fork',
  'knife',
  'spoon',
  'glasses',
  'teddy bear',
};

/// Dónde está algo respecto al usuario.
String posicionTexto(double? centroX) {
  if (centroX == null) return '';
  if (centroX < 0.33) return 'a tu izquierda';
  if (centroX > 0.66) return 'a tu derecha';
  return 'frente a ti';
}

String _unir(List<String> partes) {
  if (partes.length == 1) return partes.first;
  if (partes.length == 2) return '${partes[0]} y ${partes[1]}';
  final inicio = partes.sublist(0, partes.length - 1).join(', ');
  return '$inicio y ${partes.last}';
}

/// "¿Qué tengo enfrente?"
/// String describirEscena(List<Deteccion> detecciones, {int maximo = 4}) {
String describirEscena(List<Deteccion> detecciones) {
  if (detecciones.isEmpty) {
    return 'No detecto objetos conocidos frente a ti.';
  }

  final ordenadas = [...detecciones]..sort((a, b) => b.area.compareTo(a.area));
  final frases = <String>[];

///  for (final d in ordenadas.take(maximo)) {
  for (final d in ordenadas) {
    // Zapatillas, cinturones... que lleva puestos alguien: solo meten ruido
    if (prendasYAccesorios.contains(d.clase)) continue;
    final base = nombreDeClase(d.clase)?.conIndefinido ?? d.clase;
    final cerca = d.alto >= umbralMuyCerca ? ' muy cerca' : '';
    final relCerca = d.alto >= umbralCerca ? ' cerca' : '';
    final lejos = d.alto <= umbralLejos ? ' a lo lejos' : '';
    final pos = posicionTexto(d.centroX);
    frases.add((pos.isEmpty ? '$base$cerca' : '$base$cerca $pos') 
        + (relCerca.isNotEmpty ? relCerca : '') 
        + (lejos.isNotEmpty ? lejos : ''));
  }

  // Quita frases repetidas (dos botellas en el mismo lugar)
  final unicas = <String>[];
  for (final f in frases) {
    if (!unicas.contains(f)) unicas.add(f);
  }
  if (unicas.isEmpty) return 'No detecto objetos conocidos frente a ti.';
  return 'Veo ${_unir(unicas)}.';
}

/// "¿Dónde está la botella?"
String responderBusqueda({
  required String? clase,
  required String? objetoPedido,
  required List<Deteccion> detecciones,
}) {
  if (objetoPedido == null) {
    return '¿Qué objeto quieres que busque? Por ejemplo: dónde está la botella.';
  }

  final nombre = clase == null ? null : nombreDeClase(clase);
  if (clase == null || nombre == null) {
    return 'Todavía no sé buscar $objetoPedido. '
        'Puedo buscar objetos comunes, como botella, silla, celular o taza.';
  }

  final encontradas = detecciones.where((d) => d.clase == clase).toList()
    ..sort((a, b) => b.area.compareTo(a.area));

  if (encontradas.isEmpty) {
    return 'No veo ${nombre.conArticulo} en este momento. '
        'Mueve la cámara despacio y vuelve a preguntarme.';
  }

  final mejor = encontradas.first;
  final pos = posicionTexto(mejor.centroX);
  final lugar = pos.isEmpty ? 'delante de ti' : pos;
  final cerca = mejor.alto >= umbralMuyCerca ? ' Está muy cerca.' : '';
  final verbo = nombre.esPlural ? 'están' : 'está';

  if (encontradas.length > 1) {
    final grande = nombre.articulo[0].toUpperCase() + nombre.articulo.substring(1);
    return 'Veo más de uno. $grande de mayor tamaño $verbo $lugar.$cerca';
  }

  final articulo = nombre.articulo[0].toUpperCase() + nombre.articulo.substring(1);
  return '$articulo ${nombre.nombre} $verbo $lugar.$cerca';
}

/// Un aviso de peligro.
class Alerta {
  const Alerta(this.clave, this.mensaje, {this.urgente = false});

  /// Identifica el aviso para no repetirlo seguido (ej. 'car:a tu derecha').
  final String clave;
  final String mensaje;
  final bool urgente;
}

/// Revisa las detecciones y devuelve los avisos de peligro.
///
/// - Modo vigilancia (por defecto): solo vehículos, bicicletas y perros cerca.
/// - Modo guía: además personas muy cerca y obstáculos fijos al frente.
List<Alerta> evaluarRiesgos(
  List<Deteccion> detecciones, {
  required bool modoGuia,
}) {
  final alertas = <Alerta>[];

  for (final d in detecciones) {
    final x = d.centroX;
    if (x == null) continue;

    final nombre = nombreDeClase(d.clase);
    final sujeto = nombre?.conIndefinido ?? d.clase;
    final pos = posicionTexto(x);
    final enCentro = x > 0.25 && x < 0.75;

    if (_vehiculosYAnimales.contains(d.clase)) {
      final amplio = x > 0.15 && x < 0.85;
      final umbral = modoGuia ? umbralVehiculoGuia : umbralVehiculoVigilancia;
      if (amplio && d.alto >= umbral) {
        alertas.add(Alerta(
          '${d.clase}:$pos',
          'Cuidado, $sujeto muy cerca, $pos.',
          urgente: true,
        ));
      }
    } else if (modoGuia && d.clase == 'person') {
      if (enCentro && d.alto >= umbralPersonaGuia) {
        alertas.add(Alerta('person:$pos', 'Persona muy cerca, $pos.'));
      }
      // AGREGAR MÁS CICLOS IF PARA UMBRALES CERCA, LEJOS Y MUY LEJOS
    } else if (modoGuia && _obstaculosFijos.contains(d.clase)) {
      if (enCentro && d.alto >= umbralObstaculoGuia) {
        alertas.add(Alerta('${d.clase}:$pos', 'Hay $sujeto $pos.'));
      }
    }
  }

  // Lo urgente primero
  alertas.sort((a, b) => (b.urgente ? 1 : 0).compareTo(a.urgente ? 1 : 0));
  return alertas;
}

const String textoAyudaVoz =
    'Toca el círculo y dime: qué tengo enfrente. O: dónde está la botella. '
    'O: guía mi camino. Para terminar la guía, di: para.';

const String textoActivarGuia =
    'Modo guía activado. Te avisaré si detecto obstáculos conocidos. '
    'Soy un apoyo, no reemplazo tu bastón. Di: para, cuando quieras terminar.';
