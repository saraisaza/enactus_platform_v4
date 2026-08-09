import 'package:flutter/material.dart';

/// Sistema de color de la plataforma.
///
/// UI: tema oscuro con acento amarillo dorado de marca.
/// Gráficos: paleta categórica validada (contraste >= 3:1 sobre la superficie
/// oscura, separación CVD adyacente ΔE 61.6) — NO usar el amarillo de marca
/// (#F4C430) como color de serie: es demasiado claro para la banda de
/// luminosidad de datos; usar [AppColors.chartSeries] en orden fijo.
class AppColors {
  // Marca / UI
  static const gold = Color(0xFFF4C430);
  static const goldBright = Color(0xFFFFD700);
  static const slate = Color(0xFF2D3E50); // barras laterales, tarjetas secundarias
  static const slateLight = Color(0xFF3D5166);

  /// Colores oficiales de la bandera de Colombia, para acentos de identidad
  /// nacional (borde tricolor de header/footer, partículas del hero).
  static const colombiaYellow = Color(0xFFFCD116);
  static const colombiaBlue = Color(0xFF003893);
  static const colombiaRed = Color(0xFFCE1126);

  // Superficies (tema oscuro)
  static const background = Color(0xFF111315);
  static const surface = Color(0xFF1A1D21); // superficie de tarjetas y gráficos
  static const surfaceAlt = Color(0xFF22262B);
  static const border = Color(0xFF33383F);

  // Texto
  static const textPrimary = Color(0xFFF5F5F2);
  static const textSecondary = Color(0xFFB8BcbF);
  static const textMuted = Color(0xFF8A9099);

  /// Paleta categórica para gráficos, en orden FIJO (nunca ciclar ni
  /// reordenar): amarillo, azul, rojo, violeta, verde agua.
  static const chartSeries = [
    Color(0xFFC98500),
    Color(0xFF3987E5),
    Color(0xFFE66767),
    Color(0xFF9085E9),
    Color(0xFF199E70),
  ];

  // Estados (reservados: nunca usarlos como "serie 4")
  static const statusGood = Color(0xFF34A853);
  static const statusWarning = Color(0xFFE8A93D);
  static const statusSerious = Color(0xFFE07030);
  static const statusCritical = Color(0xFFE05252);

  /// Colores oficiales de los 17 Objetivos de Desarrollo Sostenible (ONU),
  /// 1-indexados. Usados en el Directorio de Proyectos: portada de tarjeta,
  /// marca de agua, cuadrito de etiqueta y segmento de etapa actual — el
  /// color viene del dato (el ODS principal de cada proyecto), no de un
  /// acento fijo.
  static const odsColors = {
    1: Color(0xFFE5243B),
    2: Color(0xFFDDA63A),
    3: Color(0xFF4C9F38),
    4: Color(0xFFC5192D),
    5: Color(0xFFFF3A21),
    6: Color(0xFF26BDE2),
    7: Color(0xFFFCC30B),
    8: Color(0xFFA21942),
    9: Color(0xFFFD6925),
    10: Color(0xFFDD1367),
    11: Color(0xFFFD9D24),
    12: Color(0xFFBF8B2E),
    13: Color(0xFF3F7E44),
    14: Color(0xFF0A97D9),
    15: Color(0xFF56C02B),
    16: Color(0xFF00689D),
    17: Color(0xFF19486A),
  };

  /// Color por laboratorio (handoff `design_handoff_portal_estudiante`),
  /// derivado de la paleta ODS para que cada laboratorio sea reconocible en
  /// Dashboard, Mis Cursos y Ruta de Impacto: el color viene del dato (el
  /// laboratorio del curso/fase), no de un acento fijo. Asignación
  /// confirmada con el equipo de Enactus.
  static const labColors = {
    'lab_ia': Color(0xFFFD6925), // ODS 9
    'lab_agua': Color(0xFF26BDE2), // ODS 6
    'lab_energia': Color(0xFFFCC30B), // ODS 7
    'lab_impacto': Color(0xFFDD1367), // ODS 10
    'lab_emprendimiento': Color(0xFFA21942), // ODS 8
    'lab_agricultura': Color(0xFF56C02B), // ODS 15
  };
}

/// Color de un laboratorio para acentos por dato (cabeceras de curso,
/// barras de progreso, riel de fases). Sin match — incluye la Ruta National
/// Expo, cuyos cursos no tienen laboratorio (`Course.labId` vacío) — cae al
/// amarillo de marca, tal como pide el README para "Ruta National Expo".
Color labColorFor(String labId) => AppColors.labColors[labId] ?? AppColors.gold;

/// Extrae el número de un rótulo de ODS ("ODS 6: Agua limpia..." -> 6).
/// Los `ods` de [Project]/[Course] se guardan como texto completo
/// ("ODS N: Etiqueta"), nunca como número suelto.
int odsNumberFrom(String odsLabel) {
  final match = RegExp(r'ODS\s*(\d+)').firstMatch(odsLabel);
  return match != null ? int.parse(match.group(1)!) : 1;
}

/// Color oficial del ODS de un rótulo ("ODS 6: ..." -> #26BDE2). Usado
/// dondequiera que el acento venga del ODS principal de un proyecto
/// (Directorio de Proyectos, tarjeta "Tu proyecto" del Dashboard).
Color odsColorFor(String odsLabel) =>
    AppColors.odsColors[odsNumberFrom(odsLabel)] ?? AppColors.gold;

/// Paleta clara/oscura del contenido del portal estudiante (handoffs
/// `design_handoff_directorio_proyectos/README.md` y
/// `design_handoff_portal_estudiante/README.md`). Dashboard, Calendario, Mis
/// Cursos, Ruta de Impacto y Directorio de Proyectos tienen cada uno su
/// propio toggle de tema local: el resto del portal (header, sidebar) es
/// oscuro fijo, así que estos tokens viven aparte de [AppColors] en vez de
/// ampliar el [ThemeData] global.
class ContentColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color text2;
  final Color text3;
  final Color goldInk;
  final Color goldSoft;
  final List<BoxShadow> shadow;
  final Color veil;

  const ContentColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.goldInk,
    required this.goldSoft,
    required this.shadow,
    required this.veil,
  });

  static const dark = ContentColors(
    bg: Color(0xFF111315),
    surface: Color(0xFF1A1D21),
    surface2: Color(0xFF22262B),
    border: Color(0xFF33383F),
    text: Color(0xFFF5F5F2),
    text2: Color(0xFFB8BCBF),
    text3: Color(0xFF8A9099),
    goldInk: AppColors.gold,
    goldSoft: Color(0x24F4C430), // rgba(244,196,48,.14)
    shadow: [
      BoxShadow(
          color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 18)),
    ],
    veil: Color(0x47000000), // rgba(0,0,0,.28)
  );

  /// El dorado de marca (#F4C430) no alcanza AA sobre blanco, así que en
  /// tema claro el texto/ink dorado se oscurece a #8A6A00 (ver README).
  static const light = ContentColors(
    bg: Color(0xFFF2F2EC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F0E9),
    border: Color(0xFFDEDED4),
    text: Color(0xFF15181B),
    text2: Color(0xFF4C525A),
    text3: Color(0xFF787F88),
    goldInk: Color(0xFF8A6A00),
    goldSoft: Color(0x3DF4C430), // rgba(244,196,48,.24)
    shadow: [
      BoxShadow(
          color: Color(0x24141923), blurRadius: 36, offset: Offset(0, 16)),
    ],
    veil: Color(0x38000000), // rgba(0,0,0,.22)
  );
}

/// Tokens tipográficos — el equivalente Flutter de --font-display / --font-ui
/// en CSS. Referencia esto (o mejor, usa el textTheme del Theme) en vez de
/// escribir 'Knockout' o 'SpaceGrotesk' directo en un widget.
///
/// Reglas de uso:
/// - [display] (Knockout 92): SOLO títulos principales — h1/h2, hero titles,
///   nombres de sección grandes ([SectionTitle] en widgets/common.dart). Va
///   siempre en mayúsculas (.toUpperCase() al renderizar, no en los datos) y
///   con tracking vía [knockoutTracking] — es una fuente condensada.
/// - [ui] (Space Grotesk): todo lo demás — botones, navegación, labels,
///   body text, formularios, badges, footer. Ya viene aplicada por defecto
///   a todo el textTheme, así que no hace falta declararla a mano salvo en
///   TextStyle sueltos que no heredan del tema.
class AppFonts {
  static const display = 'Knockout';
  static const ui = 'SpaceGrotesk';
}

/// Pesos de Space Grotesk realmente cargados en pubspec.yaml (variable font,
/// eje wght 300-700): 400 para texto normal, 500-600 para botones y labels
/// destacados — nunca "regular" en un botón, se ve débil al lado de Knockout.
class AppWeights {
  static const uiRegular = FontWeight.w400;
  static const uiMedium = FontWeight.w500;
  static const uiSemibold = FontWeight.w600;
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: Color(0xFF1A1400),
    secondary: AppColors.slateLight,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.statusCritical,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    // Sistema de dos fuentes (ver AppFonts arriba): display/headline en
    // Knockout (títulos principales), title/body/label en Space Grotesk
    // (todo lo demás) — ver _buildTextTheme más abajo.
    textTheme: _buildTextTheme(base.textTheme),
    primaryTextTheme: _buildTextTheme(base.primaryTextTheme),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    // Botones "premium": al pasar el mouse se elevan, el amarillo se ilumina
    // y la sombra crece; al presionar bajan (el ripple M3 viene de fábrica).
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? AppColors.goldBright
                : AppColors.gold),
        foregroundColor:
            const WidgetStatePropertyAll(Color(0xFF1A1400)),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 1;
          if (states.contains(WidgetState.hovered)) return 8;
          return 2;
        }),
        shadowColor: const WidgetStatePropertyAll(Colors.black87),
        overlayColor:
            WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: AppWeights.uiSemibold)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8))),
        animationDuration: const Duration(milliseconds: 150),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? AppColors.goldBright
                : AppColors.gold),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.hovered)
                ? AppColors.goldBright
                : AppColors.gold,
            width: states.contains(WidgetState.hovered) ? 1.6 : 1)),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? AppColors.gold.withValues(alpha: 0.08)
                : null),
        overlayColor: WidgetStatePropertyAll(
            AppColors.gold.withValues(alpha: 0.1)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8))),
        animationDuration: const Duration(milliseconds: 150),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      textStyle: const TextStyle(
          color: AppColors.textPrimary, fontSize: 12.5, height: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorderWith(AppColors.border),
      focusedBorder: OutlineInputBorderWith(AppColors.gold),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
          color: AppColors.gold,
          fontWeight: AppWeights.uiSemibold,
          fontSize: 13),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      dividerThickness: 0.5,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.gold,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.slate,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceAlt,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
  );
}

// ignore: non_constant_identifier_names
OutlineInputBorder OutlineInputBorderWith(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

/// Tracking (letter-spacing) como fracción del tamaño de fuente. Knockout es
/// condensada; sin esto las letras se ven pegadas entre sí.
const double kKnockoutTrackingRatio = 0.045;

/// Letter-spacing sugerido para un tamaño de fuente dado, usando Knockout.
/// Útil para TextStyle sueltos que no vienen del textTheme (títulos hero,
/// SectionTitle) — ver knockoutHeading() más abajo.
double knockoutTracking(double fontSize) => fontSize * kKnockoutTrackingRatio;

/// Construye un TextStyle de título en Knockout listo para usar: familia,
/// tracking proporcional y el texto pasado por .toUpperCase() se aplican
/// consistentemente. Para el texto, usa knockoutHeadingText() al armar el
/// widget Text (el transform es solo visual, no toca los datos).
TextStyle knockoutHeading({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: knockoutTracking(fontSize),
      color: color,
      height: height,
    );

/// Sistema de dos fuentes: display/headline en Knockout (títulos
/// principales), title/body/label en Space Grotesk con los pesos de
/// AppWeights (regular en body, medium/semibold en title y label — así
/// botones y labels destacados no se ven débiles al lado de Knockout).
TextTheme _buildTextTheme(TextTheme theme) {
  TextStyle? display(TextStyle? style) => style?.copyWith(
        fontFamily: AppFonts.display,
        letterSpacing: knockoutTracking(style.fontSize ?? 24),
      );
  TextStyle? ui(TextStyle? style, FontWeight weight) => style?.copyWith(
        fontFamily: AppFonts.ui,
        fontWeight: weight,
      );
  return theme.copyWith(
    displayLarge: display(theme.displayLarge),
    displayMedium: display(theme.displayMedium),
    displaySmall: display(theme.displaySmall),
    headlineLarge: display(theme.headlineLarge),
    headlineMedium: display(theme.headlineMedium),
    headlineSmall: display(theme.headlineSmall),
    titleLarge: ui(theme.titleLarge, AppWeights.uiSemibold),
    titleMedium: ui(theme.titleMedium, AppWeights.uiMedium),
    titleSmall: ui(theme.titleSmall, AppWeights.uiMedium),
    bodyLarge: ui(theme.bodyLarge, AppWeights.uiRegular),
    bodyMedium: ui(theme.bodyMedium, AppWeights.uiRegular),
    bodySmall: ui(theme.bodySmall, AppWeights.uiRegular),
    labelLarge: ui(theme.labelLarge, AppWeights.uiSemibold), // botones
    labelMedium: ui(theme.labelMedium, AppWeights.uiMedium),
    labelSmall: ui(theme.labelSmall, AppWeights.uiMedium),
  );
}
