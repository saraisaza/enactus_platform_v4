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
