import 'package:flutter/material.dart';
 
/// Indica si la app está en modo oscuro.
/// Lo lee MaterialApp (main.dart) y lo cambia el interruptor de Ajustes.
final ValueNotifier<bool> modoOscuro = ValueNotifier<bool>(false);

/// Atajo para crear estilos de texto sin repetir tanto código.
TextStyle estiloTexto(
  double tamano,
  FontWeight peso,
  Color color, {
  double? altura,
  double? espaciado,
}) {
  return TextStyle(
    fontSize: tamano,
    fontWeight: peso,
    color: color,
    height: altura,
    letterSpacing: espaciado,
  );
}

/// Colores del diseño de Figma (variables de index.css), en versión clara y oscura.
class LuminaColors {
  const LuminaColors({
    required this.page,
    required this.welcome,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.brandPale,
    required this.brandBorder,
    required this.onBrand,
    required this.success,
    required this.successStrong,
    required this.successSoft,
    required this.warning,
    required this.warningStrong,
    required this.warningSoft,
    required this.toggle,
    required this.iconSurface,
    required this.overlay,
  });

  final Color page;
  final Color welcome;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color brandPale;
  final Color brandBorder;

  /// Color del texto/íconos que van SOBRE el azul de marca o el verde.
  /// En modo oscuro el azul es claro, así que el texto debe ser oscuro.
  final Color onBrand;

  final Color success;
  final Color successStrong;
  final Color successSoft;
  final Color warning;
  final Color warningStrong;
  final Color warningSoft;
  final Color toggle;
  final Color iconSurface;
  final Color overlay;

  // Iguales en ambos modos
  static const Color camera = Color(0xFF111820);
  static const Color cameraLabel = Color(0xD10C1724);
  static const Color live = Color(0xFFFF5B5B);

  // Sombras del diseño
  static const List<BoxShadow> sombraApp = [
    BoxShadow(color: Color(0x2425394D), blurRadius: 60, offset: Offset(0, 20)),
  ];
  static const List<BoxShadow> sombraControl = [
    BoxShadow(color: Color(0x47075BB7), blurRadius: 28, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> sombraTarjeta = [
    BoxShadow(color: Color(0x14234970), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> sombraToast = [
    BoxShadow(color: Color(0x3D0C1724), blurRadius: 32, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> sombraHoja = [
    BoxShadow(color: Color(0x290C1724), blurRadius: 40, offset: Offset(0, -16)),
  ];
  static const List<BoxShadow> sombraInterruptor = [
    BoxShadow(color: Color(0x3D0C1724), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const LuminaColors claro = LuminaColors(
    page: Color(0xFFE8EEF4),
    welcome: Color(0xFFDCECFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF2F6),
    ink: Color(0xFF17202A),
    inkMuted: Color(0xFF52606D),
    border: Color(0xFFD9E1E8),
    brand: Color(0xFF075BB7),
    brandStrong: Color(0xFF06478E),
    brandSoft: Color(0xFFB9DCFF),
    brandPale: Color(0xFFEEF7FF),
    brandBorder: Color(0xFFC9E5FF),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF16834B),
    successStrong: Color(0xFF0D6338),
    successSoft: Color(0xFFE2F6EA),
    warning: Color(0xFFB55B00),
    warningStrong: Color(0xFF7C3D00),
    warningSoft: Color(0xFFFFF0DC),
    toggle: Color(0xFF8B98A5),
    iconSurface: Color(0xFFDDECFB),
    overlay: Color(0x850C1724),
  );

  static const LuminaColors oscuro = LuminaColors(
    page: Color(0xFF08111A),
    welcome: Color(0xFF08111A),
    surface: Color(0xFF111D28),
    surfaceMuted: Color(0xFF1B2A36),
    ink: Color(0xFFF6F9FB),
    inkMuted: Color(0xFFC1CBD4),
    border: Color(0xFF31414E),
    brand: Color(0xFF58AAFF),
    brandStrong: Color(0xFF9BCEFF),
    brandSoft: Color(0xFF234B70),
    brandPale: Color(0xFF152C40),
    brandBorder: Color(0xFF2B567B),
    onBrand: Color(0xFF08111A),
    success: Color(0xFF5BD493),
    successStrong: Color(0xFF8CE8B5),
    successSoft: Color(0xFF153A2A),
    warning: Color(0xFFFFAE58),
    warningStrong: Color(0xFFFFD09D),
    warningSoft: Color(0xFF422B13),
    toggle: Color(0xFF65727D),
    iconSurface: Color(0xFF203C55),
    overlay: Color(0xB3000000),
  );

  /// Devuelve los colores según el tema activo.
  static LuminaColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? oscuro : claro;
  }
}

/// Tema de Flutter para cada modo.
ThemeData construirTema({required bool oscuro}) {
  final c = oscuro ? LuminaColors.oscuro : LuminaColors.claro;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.brand,
      brightness: oscuro ? Brightness.dark : Brightness.light,
    ),
    scaffoldBackgroundColor: c.page,
  );
}
