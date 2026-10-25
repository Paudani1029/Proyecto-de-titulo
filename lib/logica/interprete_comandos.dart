import '../models/clases_coco.dart';

/// Qué quiso decir el usuario.
enum TipoComando {
  queHayEnfrente,
  dondeEsta,
  guiarCamino,
  detenerGuia,
  repetir,
  ayuda,
  irADestino,
  desconocido,
}

class Comando {
  const Comando(this.tipo, {this.clase, this.objetoPedido});

  final TipoComando tipo;

  /// Clase de YOLO que se pidió buscar (ej. 'bottle'), si se pudo identificar.
  final String? clase;

  /// Lo que dijo el usuario ("botella"), para poder responder si no lo conocemos.
  final String? objetoPedido;
}

/// Pasa a minúsculas, quita tildes y signos: "¿Dónde está?" -> "donde esta".
String normalizar(String texto) {
  var t = texto.toLowerCase();
  const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sinTilde = 'aaaaeeeeiiiioooouuuun';
  for (var i = 0; i < conTilde.length; i++) {
    t = t.replaceAll(conTilde[i], sinTilde[i]);
  }
  t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// El reconocedor puede escribir "Lumina" de formas raras, así que se aceptan variantes.
const Set<String> _activacion = {
  'lumina',
  'lumi',
  'lumia',
  'numina',
  'lumin',
  'oye',
  'hola',
  'hey',
  'ey',
};

const Set<String> _relleno = {
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
  'mi', 'mis', 'tu', 'su', 'ese', 'esa', 'esos', 'esas',
  'este', 'esta', 'estos', 'estas', 'algun', 'alguna',
  'de', 'por', 'favor', 'que', 'en', 'aqui', 'ahi', 'donde', 'estan',
};

String _quitarActivacion(String t) {
  final palabras = t.split(' ');
  while (palabras.isNotEmpty && _activacion.contains(palabras.first)) {
    palabras.removeAt(0);
  }
  return palabras.join(' ');
}

String? _buscarClase(List<String> palabras) {
  // Primero pares de palabras ("control remoto")
  for (var i = 0; i < palabras.length - 1; i++) {
    final par = '${palabras[i]} ${palabras[i + 1]}';
    if (sinonimosCoco.containsKey(par)) return sinonimosCoco[par];
  }
  for (final p in palabras) {
    if (sinonimosCoco.containsKey(p)) return sinonimosCoco[p];
  }
  return null;
}

final RegExp _patronDonde = RegExp(
  r'(?:^| )(?:donde (?:esta|estan|queda|quedan|hay)|buscame|busca|buscar|encuentrame|encuentra|encontrar|ubicame|ubica|ubicar|localiza|localizar)(?:\s+(.+))?$',
);

final RegExp _patronDestino = RegExp(r'\bguia(?:me)? (?:a|hasta|hacia) ');

/// Convierte lo que dijo el usuario en un comando.
Comando interpretarComando(String frase) {
  final t = _quitarActivacion(normalizar(frase));
  if (t.isEmpty) return const Comando(TipoComando.desconocido);

  final palabras = t.split(' ');
  bool contiene(String trozo) => t.contains(trozo);
  bool tiene(List<String> claves) => palabras.any((p) => claves.contains(p));

  // 1) Detener la guía ("para", "silencio", "detente")
  if (tiene(['detente', 'detener', 'silencio', 'basta', 'callate', 'parar', 'termina']) ||
      t == 'para' ||
      t.startsWith('para de ') ||
      contiene('deja de')) {
    return const Comando(TipoComando.detenerGuia);
  }

  // 2) "¿Dónde está la botella?"
  final m = _patronDonde.firstMatch(t);
  if (m != null) {
    final resto = m.group(1) ?? '';
    final tokens = resto
        .split(' ')
        .where((w) => w.isNotEmpty && !_relleno.contains(w))
        .toList();
    if (tokens.isEmpty) return const Comando(TipoComando.dondeEsta);
    return Comando(
      TipoComando.dondeEsta,
      clase: _buscarClase(tokens),
      objetoPedido: tokens.join(' '),
    );
  }

  // 3) Ir a un lugar (todavía no soportado) y guiar el camino
  if (tiene(['llevame']) || contiene('como llego') || _patronDestino.hasMatch(t)) {
    return const Comando(TipoComando.irADestino);
  }
  if (tiene(['guia', 'guiame', 'guiar', 'acompaname']) ||
      contiene('ayudame a caminar') ||
      contiene('ayudame a avanzar')) {
    return const Comando(TipoComando.guiarCamino);
  }

  // 4) "¿Qué tengo enfrente?"
  if ((tiene(['que']) && tiene(['tengo', 'hay', 'ves', 'veo', 'tienes'])) ||
      tiene(['describe', 'describeme', 'describir', 'descripcion']) ||
      contiene('enfrente') ||
      contiene('al frente')) {
    return const Comando(TipoComando.queHayEnfrente);
  }

  // 5) Repetir
  if (tiene(['repite', 'repetir', 'repitelo', 'repitemelo']) ||
      contiene('otra vez') ||
      contiene('de nuevo') ||
      contiene('no entendi')) {
    return const Comando(TipoComando.repetir);
  }

  // 6) Ayuda
  if (tiene(['ayuda', 'comandos']) ||
      contiene('que puedes hacer') ||
      contiene('que sabes hacer') ||
      contiene('como funcionas')) {
    return const Comando(TipoComando.ayuda);
  }

  return const Comando(TipoComando.desconocido);
}
