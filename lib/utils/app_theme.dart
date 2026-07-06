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
            TextStyle(fontWeight: FontWeight.w700)),
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
          color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
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
