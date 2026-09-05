import 'package:flutter/material.dart';

/// Sistema de color de la plataforma.
///
/// UI: tema oscuro gris con un único acento ámbar de marca.
/// Gráficos: paleta categórica validada (contraste >= 3:1 sobre la superficie
/// oscura, separación CVD adyacente ΔE 61.6) — NO usar el ámbar de marca
/// (#FFC107) como color de serie: se confunde con el acento de UI; usar
/// [AppColors.chartSeries] en orden fijo.
class AppColors {
  // Marca / UI
  /// Acento de marca eduXaction: ámbar (identidad
  /// `assets/design_handoff_branding_eduxaction/brand-tokens.css`, token
  /// `--exa-accent`).
  ///
  /// Único sitio donde vive este valor — todo lo demás lo referencia por acá
  /// en vez de repetir el hex (certificados PDF y `ContentColors.dark` son
  /// las dos excepciones documentadas, por no poder referenciar esta
  /// constante desde su contexto).
  static const gold = Color(0xFFFFC107);

  /// Hover del acento (`--exa-accent-bright`).
  static const goldBright = Color(0xFFFFCF3D);

  /// Grises neutros. Reemplazan la rampa cálida marrón anterior
  /// (#453027 / #573D31 / #392720), que era el otro origen del aire de
  /// Halloween junto con el naranja: el acento cálido se conserva, el
  /// entorno pasa a gris.
  static const slate = Color(0xFF26262A); // barras laterales, tarjetas secundarias
  static const slateLight = Color(0xFF2C2B30);

  /// Variante oscurecida de [slate] para el segundo punto del degradado del
  /// footer.
  static const slateDark = Color(0xFF17171A);

  /// "Tinta sobre acento": texto/íconos oscuros sobre fondos [gold]/
  /// [goldBright] (iniciales de avatar, banner, contador de notificaciones,
  /// botones). Mismo valor que el onPrimary del ColorScheme — reunido acá
  /// para que ningún widget lo hardcodee suelto.
  static const ink = Color(0xFF21120A);

  // Superficies (tema oscuro) — página / tarjetas / paneles, identidad
  // eduXaction (ver `brand-tokens.css` del handoff de branding).
  static const background = Color(0xFF35343A); // página

  /// Negro al que van a parar los degradados (`--exa-bg-deep`).
  ///
  /// No es una superficie: nada se pinta plano con este tono. Es el segundo
  /// punto del hero, de la banda de laboratorios y de la de invitación — el
  /// "negro difuminado" que da profundidad sin volver la página negra.
  static const backgroundDeep = Color(0xFF0B0B0D);

  static const surface = Color(0xFF17171A); // tarjetas y gráficos
  static const surfaceAlt = Color(0xFF26262A); // paneles (campos, chips, diálogos)
  static const border = Color(0x14FFFFFF); // rgba(255,255,255,.08)

  // Texto
  static const textPrimary = Color(0xFFF2F2F5);
  static const textSecondary = Color(0xFFAEABB0);

  /// Tercer tono de texto. Antes era #8C817C, un gris CÁLIDO heredado de la
  /// paleta marrón: sobre el gris neutro nuevo se veía sucio. Ahora es el
  /// `--exa-text-3` del handoff, neutro como los otros dos.
  static const textMuted = Color(0xFF8F8C92);

  /// Partículas del hero de la landing. Ámbar, ámbar claro y dos neutros:
  /// sin el naranja saturado que las hacía leer como chispas.
  static const heroParticleColors = [
    Color(0xFFFFC107),
    Color(0xFFFFD98A),
    Color(0xFFFFFFFF),
    Color(0xFFBABABA),
  ];

  /// Paleta categórica para gráficos, en orden FIJO (nunca ciclar ni
  /// reordenar): malva, azul, rojo, violeta, verde agua.
  ///
  /// La primera serie era el amarillo #C98500. Con el acento de marca en
  /// naranja se distinguía; con el ámbar #FFC107 pasó a ser el mismo color
  /// a ojo, y una serie que se confunde con el acento de UI hace leer un
  /// dato como si fuera un elemento de interfaz. Se reemplaza por el malva
  /// #B07AA1 que propone el handoff.
  ///
  /// Se mantiene el criterio del archivo: contraste >= 3:1 sobre [surface]
  /// —el malva da 5.2:1— y separación entre series adyacentes. El violeta
  /// de la posición 4 es el más cercano en tono, y por eso están separados:
  /// nunca quedan uno al lado del otro.
  static const chartSeries = [
    Color(0xFFB07AA1),
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

  /// Color por laboratorio: seis tonos distinguibles y legibles sobre
  /// [background], que separan cada laboratorio en Dashboard, Mis Cursos y
  /// Ruta de Impacto — el color viene del dato (el laboratorio del
  /// curso/fase), no de un acento fijo.
  ///
  /// Era una rampa cálida derivada del naranja anterior, y sobre el gris
  /// nuevo los seis tonos se veían como variaciones del mismo naranja. La
  /// rampa del handoff de branding abre el abanico: solo el laboratorio de
  /// IA conserva el ámbar de marca, el resto son tonos propios.
  static const labColors = {
    'lab_ia': Color(0xFFFFC107),
    'lab_agua': Color(0xFF4FB3C4),
    'lab_energia': Color(0xFFE8A93D),
    'lab_impacto': Color(0xFF9085E9),
    'lab_emprendimiento': Color(0xFFE07A5F),
    'lab_agricultura': Color(0xFF7FA34A),
  };

  /// El número de ODS detrás de cada [labColors] — para la marca de agua
  /// de las tarjetas de laboratorio (Pantallas 8 y 9). Mismo criterio: sin
  /// match cae al 8 (Trabajo decente), el ODS del amarillo de marca /
  /// Ruta National Expo.
  static const labOdsNumbers = {
    'lab_ia': 9,
    'lab_agua': 6,
    'lab_energia': 7,
    'lab_impacto': 10,
    'lab_emprendimiento': 8,
    'lab_agricultura': 15,
  };
}

/// Número de ODS detrás del color de un laboratorio, para su marca de
/// agua. Ver [labColorFor].
int labOdsNumberFor(String labId) => AppColors.labOdsNumbers[labId] ?? 8;

/// Color de un laboratorio para acentos por dato (cabeceras de curso,
/// barras de progreso, riel de fases). Sin match — incluye la Ruta National
/// Expo, cuyos cursos no tienen laboratorio (`Course.labId` vacío) — cae al
/// ámbar de marca, tal como pide el README para "Ruta National Expo".
Color labColorFor(String labId) => AppColors.labColors[labId] ?? AppColors.gold;

/// Extrae el número de un rótulo de ODS ("ODS 6: Agua limpia..." -> 6).
/// Número de un ODS a partir de su código.
///
/// La API los guarda como `ods_6`, no como el rótulo completo "ODS 6: Agua
/// limpia…" que usaba Hive. Se aceptan las dos formas porque el rótulo largo
/// sigue apareciendo en textos escritos a mano, y sacar el número de cualquiera
/// de las dos es un solo regex: cambiar el formato no puede volver a dejar
/// todos los acentos en dorado sin que nada falle.
int odsNumberFrom(String ods) {
  final match = RegExp(r'(\d+)').firstMatch(ods);
  return match != null ? int.parse(match.group(1)!) : 1;
}

/// Color oficial del ODS (`ods_6` -> #26BDE2). Usado dondequiera que el acento
/// venga del ODS principal de un proyecto (Directorio de Proyectos, tarjeta
/// "Tu proyecto" del Dashboard).
Color odsColorFor(String ods) =>
    AppColors.odsColors[odsNumberFrom(ods)] ?? AppColors.gold;

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

  /// Texto/ícono de alerta (vencido) sobre el área de contenido. `#FF8A9B`
  /// en oscuro; en claro se oscurece a `#A8101C` porque el primero sobre
  /// blanco da 2.24:1 y no pasa AA. Todo texto de alerta debe leer este
  /// token — nunca un literal hex suelto en el widget.
  final Color alertInk;
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
    required this.alertInk,
    required this.shadow,
    required this.veil,
  });

  static const dark = ContentColors(
    bg: Color(0xFF35343A),
    surface: Color(0xFF17171A),
    surface2: Color(0xFF26262A),
    border: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    text: Color(0xFFF2F2F5),
    text2: Color(0xFFAEABB0),
    text3: Color(0xFF8F8C92),
    goldInk: AppColors.gold,
    goldSoft: Color(0x29FFC107), // rgba(255,193,7,.16)
    alertInk: Color(0xFFFF8A9B),
    shadow: [
      BoxShadow(
          color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 18)),
    ],
    veil: Color(0x47000000), // rgba(0,0,0,.28)
  );

  /// El ámbar de marca (#FFC107) sobre blanco da ~1.7:1 — peor todavía que
  /// el naranja anterior, que ya no pasaba. En tema claro el texto/ink se
  /// oscurece a #8A6A00: **nunca usar [AppColors.gold] como color de texto
  /// sobre fondo claro.**
  ///
  /// Los neutros también dejan de ser cálidos: el fondo era #F7F1EC, un
  /// crema rosado que acompañaba a la paleta marrón y desentona con el gris
  /// nuevo.
  static const light = ContentColors(
    bg: Color(0xFFF4F2EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE9E7E3),
    border: Color(0xFFD8D4CE),
    text: Color(0xFF1B1A1E),
    text2: Color(0xFF55535A),
    text3: Color(0xFF8C817C),
    goldInk: Color(0xFF8A6A00),
    goldSoft: Color(0x3DFFC107), // rgba(255,193,7,.24)
    alertInk: Color(0xFFA8101C),
    shadow: [
      BoxShadow(
          color: Color(0x24141923), blurRadius: 36, offset: Offset(0, 16)),
    ],
    veil: Color(0x38000000), // rgba(0,0,0,.22)
  );
}

/// Tokens tipográficos — el equivalente Flutter de --font-display / --font-ui
/// en CSS. Referencia esto (o mejor, usa el textTheme del Theme) en vez de
/// escribir 'Oswald' o 'DMSans' directo en un widget.
///
/// Reglas de uso:
/// - [display] (Oswald): SOLO títulos principales — hero, encabezados de
///   sección ([SectionTitle] en widgets/common.dart), saludo/título de
///   portal ([ContentScreenShell] en widgets/portal_shell.dart), títulos de
///   tarjeta, cifras de métrica. Va siempre en mayúsculas (.toUpperCase()
///   al renderizar, no en los datos) y con tracking vía [displayTracking]
///   — es una fuente condensada y de altura-x alta, necesita menos
///   interlínea que Knockout.
/// - [ui] (DM Sans): todo lo demás — botones, navegación, labels, body
///   text, formularios, badges, footer, tablas. Ya viene aplicada por
///   defecto a todo el textTheme, así que no hace falta declararla a mano
///   salvo en TextStyle sueltos que no heredan del tema.
class AppFonts {
  /// Oswald, **sustituta deliberada** de la display del handoff.
  ///
  /// El diseño especifica Knockout 92, pero esa fuente no se distribuye con la
  /// app: es comercial (Hoefler&Co) y un build web publica el archivo como
  /// descarga abierta para cualquiera. Se eliminó del repositorio a propósito.
  /// Oswald es condensada, de proporciones parecidas y con licencia OFL —
  /// libre de redistribuir.
  ///
  /// Si algún día se compra la licencia y se decide embeberla, cambiar este
  /// valor (y [AppWeights.display] y [kDisplayTrackingRatio], que están
  /// afinados a Oswald) alcanza para toda la app.
  static const display = 'Oswald';

  /// Manrope — SOLO el wordmark "eduXaction" ([AnimatedLogo] en
  /// widgets/animated_logo.dart), pesos 700/800 (los únicos dos
  /// registrados en pubspec.yaml). No es un tercer rol de texto general:
  /// nunca lo uses en un título ([display]) ni en texto de interfaz ([ui]).
  static const logo = 'Manrope';

  /// DM Sans, sustituta de Space Grotesk por la misma razón que [display]:
  /// la del handoff ya no está en el repositorio. DM Sans también es OFL y
  /// trae los tres pesos que usa [AppWeights] como archivos reales.
  static const ui = 'DMSans';
}

/// Pesos realmente cargados en pubspec.yaml.
class AppWeights {
  /// DM Sans (rol interfaz): 400 texto normal, 500 navegación (sidebar),
  /// 600 botones y labels/eyebrows destacados — nunca "regular" en un
  /// botón, se ve débil al lado de Oswald.
  static const uiRegular = FontWeight.w400;
  static const uiMedium = FontWeight.w500;
  static const uiSemibold = FontWeight.w600;

  /// Oswald (rol display): el diseño pide SemiBold (600), pero
  /// `assets/media/oswald/` solo trae Light/Regular/Bold — no hay archivo
  /// 600 descargado. Se usa Bold (700, el peso real más cercano) en vez de
  /// dejar que Flutter sintetice un 600 falso (se ve mal, contraformas
  /// cerradas). En cuanto se agregue Oswald-SemiBold.ttf a
  /// assets/media/oswald/ y a pubspec.yaml, este único valor pasa a
  /// FontWeight.w600 y corrige TODOS los títulos de la app a la vez — por
  /// eso [displayHeading] usa esto como default en vez de que cada
  /// pantalla escriba FontWeight.w700/w800/w900 suelto.
  static const display = FontWeight.w700;
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: Color(0xFF21120A),
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
    // Oswald (títulos principales), title/body/label en DM Sans (todo lo
    // demás) — ver _buildTextTheme más abajo.
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
            const WidgetStatePropertyAll(Color(0xFF21120A)),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 1;
          if (states.contains(WidgetState.hovered)) return 8;
          return 2;
        }),
        shadowColor: const WidgetStatePropertyAll(Colors.black87),
        overlayColor:
            WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
        // `fontFamily` explícita: el `textStyle` de un `ButtonStyle`
        // REEMPLAZA el estilo del botón, no se fusiona con el `textTheme`.
        // Sin ella, la etiqueta de CADA botón elevado de la plataforma se
        // pintaba con la fuente del sistema — distinta en cada navegador.
        textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: AppFonts.ui, fontWeight: AppWeights.uiSemibold)),
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
          fontFamily: AppFonts.ui,
          color: AppColors.textPrimary,
          fontSize: 12.5,
          height: 1.5),
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
      labelStyle: const TextStyle(
          fontFamily: AppFonts.ui, color: AppColors.textSecondary),
      hintStyle: const TextStyle(
          fontFamily: AppFonts.ui, color: AppColors.textMuted),
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
          fontFamily: AppFonts.ui,
          color: AppColors.gold,
          fontWeight: AppWeights.uiSemibold,
          fontSize: 13),
      // Space Grotesk no trae numerales tabulares por defecto — se
      // activan a mano acá para que las columnas numéricas de las 3
      // DataTable de la app (Usuarios, dashboard LXD, seguimiento de
      // curso) alineen bien.
      dataTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.textPrimary,
          fontSize: 13,
          fontFeatures: [FontFeature.tabularFigures()]),
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
      contentTextStyle: TextStyle(
          fontFamily: AppFonts.ui, color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceAlt,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.textPrimary,
          fontSize: 12),
    ),
  );
}

// ignore: non_constant_identifier_names
OutlineInputBorder OutlineInputBorderWith(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

/// Tracking (letter-spacing) como fracción del tamaño de fuente, para
/// títulos genéricos que no piden un valor propio.
///
/// **0.014, no el 0.045 de los handoff**: ese valor está medido sobre
/// Knockout, y la app usa Oswald (ver [AppFonts.display]), que es más angosta
/// y de altura-x más alta. Con 0.045 las mayúsculas quedan sueltas. Si algún
/// día entra Knockout, este valor vuelve a 0.045.
const double kDisplayTrackingRatio = 0.014;

/// Letter-spacing sugerido para un tamaño de fuente dado. Útil para TextStyle
/// sueltos que no vienen del textTheme. Ver displayHeading() más abajo.
double displayTracking(double fontSize) => fontSize * kDisplayTrackingRatio;

/// Construye un TextStyle de título en Oswald listo para usar: familia,
/// tracking (proporcional por defecto vía [kDisplayTrackingRatio], o el
/// valor explícito de [letterSpacing] para los roles con tabla propia:
/// hero, encabezado de sección, saludo de portal, cifra de métrica) y el
/// texto pasado por .toUpperCase() se aplican consistentemente. Para el
/// texto, usa .toUpperCase() al armar el widget Text (el transform es solo
/// visual, no toca los datos). [height] por defecto 1.08 (rol "Título de
/// tarjeta" — Oswald necesita menos interlínea que Knockout).
TextStyle displayHeading({
  required double fontSize,
  FontWeight fontWeight = AppWeights.display,
  Color? color,
  double? height = 1.08,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing ?? displayTracking(fontSize),
      color: color,
      height: height,
    );

/// Sistema de dos fuentes: display/headline en Oswald (títulos
/// principales), title/body/label en DM Sans con los pesos de AppWeights
/// (regular en body, medium en navegación, semibold en botones y labels
/// destacados — así no se ven débiles al lado de Oswald).
TextTheme _buildTextTheme(TextTheme theme) {
  TextStyle? display(TextStyle? style) => style?.copyWith(
        fontFamily: AppFonts.display,
        fontWeight: AppWeights.display,
        letterSpacing: displayTracking(style.fontSize ?? 24),
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
