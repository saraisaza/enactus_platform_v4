import 'package:flutter/material.dart';

import 'redibujar.dart';

/// La marca con la que se pinta la plataforma: la de eduXaction o la del
/// cliente de quien inició sesión.
///
/// Todos los colores de marca de la app salen de acá: `AppColors.gold`,
/// `goldBright` e `ink`, y el `goldInk`/`goldSoft` de `ContentColors`, son
/// lecturas de [Marca.instancia]. Cambiar la paleta cambia toda la plataforma
/// de una vez, sin tocar ninguna pantalla.
///
/// Lo que NO sale de acá, a propósito: el logo de eduXaction (lleva siempre su
/// ámbar, `AppColors.ambarEduXaction`), los colores de dato —gráficos, ODS,
/// laboratorios, estados— y los grises de la interfaz. La marca de un cliente
/// se nota en los acentos; la tipografía y la estructura siguen siendo las de
/// eduXaction.
class Marca extends ChangeNotifier {
  Marca._();

  /// Una sola instancia para toda la app: los colores se leen sin `context`,
  /// igual que los textos (`Idioma.instancia`).
  static final Marca instancia = Marca._();

  PaletaMarca _paleta = PaletaMarca.eduXaction;

  /// La paleta activa.
  PaletaMarca get paleta => _paleta;

  /// Pinta la plataforma con [paleta] de inmediato, sin recargar ni perder lo
  /// que la persona tenía abierto.
  void aplicar(PaletaMarca paleta) {
    if (paleta == _paleta) return;
    _paleta = paleta;
    notifyListeners();
    redibujarTodaLaApp();
  }

  /// Vuelve a la marca de eduXaction (al cerrar sesión, por ejemplo).
  void restablecer() => aplicar(PaletaMarca.eduXaction);
}

/// Los colores de una marca, ya resueltos para cada uso.
///
/// Un mismo color no sirve igual para todo. El azul #1A73E8 de relleno de un
/// botón, con texto blanco encima, da 4.51:1 y se lee bien; ese mismo azul
/// como texto sobre el gris de la plataforma da 2.74:1 y no se lee. Por eso
/// la paleta guarda una variante por uso, cada una con su contraste mínimo
/// (4.5:1, el nivel AA de WCAG para texto normal) garantizado.
@immutable
class PaletaMarca {
  /// Relleno de botones, íconos activos, enlaces, foco y acentos sobre las
  /// superficies oscuras. Es el color tal cual lo eligió el cliente.
  final Color primario;

  /// Insignias, barras de progreso y la opción activa del menú.
  final Color secundario;

  /// [secundario] como color de TEXTO sobre las superficies oscuras y claras
  /// (el texto de una insignia), con el mismo mínimo que el primario.
  final Color secundarioSobreOscuro;
  final Color secundarioSobreClaro;

  /// [primario] al pasar el mouse sobre un botón.
  final Color primarioBrillante;

  /// Texto e íconos ENCIMA de [primario] o [primarioBrillante]: oscuro sobre
  /// un acento claro, blanco sobre uno oscuro.
  final Color sobrePrimario;

  /// La marca como color de TEXTO sobre las superficies oscuras.
  final Color tintaSobreOscuro;

  /// [tintaSobreOscuro] al pasar el mouse (el texto de un botón con borde).
  /// Más clara, nunca más oscura: sobre el gris, más clara se lee mejor.
  final Color tintaSobreOscuroBrillante;

  /// La marca como color de TEXTO sobre las superficies claras (las pestañas
  /// que tienen modo claro).
  final Color tintaSobreClaro;

  /// Fondo suave de marca (chips, resaltados) en modo oscuro y en claro.
  final Color suaveSobreOscuro;
  final Color suaveSobreClaro;

  const PaletaMarca._({
    required this.primario,
    required this.secundario,
    required this.secundarioSobreOscuro,
    required this.secundarioSobreClaro,
    required this.primarioBrillante,
    required this.sobrePrimario,
    required this.tintaSobreOscuro,
    required this.tintaSobreOscuroBrillante,
    required this.tintaSobreClaro,
    required this.suaveSobreOscuro,
    required this.suaveSobreClaro,
  });

  /// La marca de eduXaction, con los valores exactos del handoff de branding.
  ///
  /// No se calcula con [PaletaMarca.desde]: estos tonos los afinó el diseño a
  /// mano (el hover #FFCF3D, el texto en claro #8A6A00) y la plataforma tiene
  /// que verse idéntica a como se veía antes de que existieran las marcas.
  static const eduXaction = PaletaMarca._(
    primario: Color(0xFFFFC107),
    secundario: Color(0xFFFFC107),
    secundarioSobreOscuro: Color(0xFFFFC107),
    secundarioSobreClaro: Color(0xFF8A6A00),
    primarioBrillante: Color(0xFFFFCF3D),
    sobrePrimario: tintaOscura,
    tintaSobreOscuro: Color(0xFFFFC107),
    tintaSobreOscuroBrillante: Color(0xFFFFCF3D),
    tintaSobreClaro: Color(0xFF8A6A00),
    suaveSobreOscuro: Color(0x29FFC107), // rgba(255,193,7,.16)
    suaveSobreClaro: Color(0x3DFFC107), // rgba(255,193,7,.24)
  );

  /// Tinta oscura de la plataforma: la que va sobre el ámbar.
  static const tintaOscura = Color(0xFF21120A);

  /// Contraste mínimo de todo texto de marca: AA de WCAG, texto normal.
  static const contrasteMinimo = 4.5;

  /// El fondo oscuro más claro sobre el que se escribe texto de marca
  /// (`AppColors.background`). Si se lee ahí, se lee en las tarjetas y
  /// paneles, que son más oscuros.
  static const fondoOscuroMasClaro = Color(0xFF35343A);

  /// El fondo claro más oscuro sobre el que se escribe texto de marca
  /// (`ContentColors.light.surface2`). Mismo razonamiento al revés.
  static const fondoClaroMasOscuro = Color(0xFFE9E7E3);

  /// La paleta de un cliente a partir de sus dos colores.
  ///
  /// Los rellenos usan el color exacto; los textos se aclaran u oscurecen lo
  /// justo para llegar a [contrasteMinimo] sobre su fondo, sin cambiar el
  /// tono. Sin [secundario], se usa el primario.
  factory PaletaMarca.desde({required Color primario, Color? secundario}) {
    primario = _opaco(primario);
    final secundarioOpaco = _opaco(secundario ?? primario);
    final sobre = _mejorTintaSobre(primario);
    // El hover se aleja del color del texto que lleva encima: un botón con
    // texto blanco se oscurece y uno con texto oscuro se aclara. Al revés, el
    // texto perdería contraste justo cuando la persona va a hacer clic.
    final brillante = sobre == Colors.white
        ? Color.lerp(primario, Colors.black, 0.15)!
        : Color.lerp(primario, Colors.white, 0.22)!;
    final tintaSobreOscuro =
        legibleSobre(primario, fondoOscuroMasClaro, aclarando: true);
    return PaletaMarca._(
      primario: primario,
      secundario: secundarioOpaco,
      secundarioSobreOscuro:
          legibleSobre(secundarioOpaco, fondoOscuroMasClaro, aclarando: true),
      secundarioSobreClaro:
          legibleSobre(secundarioOpaco, fondoClaroMasOscuro, aclarando: false),
      primarioBrillante: brillante,
      sobrePrimario: sobre,
      tintaSobreOscuro: tintaSobreOscuro,
      tintaSobreOscuroBrillante:
          Color.lerp(tintaSobreOscuro, Colors.white, 0.22)!,
      tintaSobreClaro:
          legibleSobre(primario, fondoClaroMasOscuro, aclarando: false),
      suaveSobreOscuro: primario.withValues(alpha: 0.16),
      suaveSobreClaro: primario.withValues(alpha: 0.24),
    );
  }

  /// La tinta que más contrasta sobre [fondo]: la oscura de la plataforma o
  /// el blanco, con el mismo criterio que `inkSobre`.
  ///
  /// El negro queda para los tonos medios: hay colores en los que ni la tinta
  /// oscura ni el blanco llegan a 4.5:1 (el peor caso da 4.25:1), y el negro
  /// puro siempre llega.
  static Color _mejorTintaSobre(Color fondo) {
    final oscura = contraste(tintaOscura, fondo);
    final blanca = contraste(Colors.white, fondo);
    final mejor = oscura >= blanca ? tintaOscura : Colors.white;
    if (oscura >= contrasteMinimo || blanca >= contrasteMinimo) return mejor;
    return Colors.black;
  }

  /// [color] tal cual si ya se lee sobre [fondo]; si no, el mismo tono
  /// aclarado (o oscurecido) lo mínimo para llegar a [contrasteMinimo].
  static Color legibleSobre(Color color, Color fondo, {required bool aclarando}) {
    if (contraste(color, fondo) >= contrasteMinimo) return color;
    final hsl = HSLColor.fromColor(color);
    var luz = hsl.lightness;
    while (aclarando ? luz < 1 : luz > 0) {
      luz = (luz + (aclarando ? 0.005 : -0.005)).clamp(0.0, 1.0);
      final candidato = hsl.withLightness(luz).toColor();
      if (contraste(candidato, fondo) >= contrasteMinimo) return candidato;
    }
    return aclarando ? Colors.white : Colors.black;
  }

  /// Un color de marca no puede ser transparente: se escribe texto encima.
  static Color _opaco(Color c) => c.withValues(alpha: 1);

  @override
  bool operator ==(Object other) =>
      other is PaletaMarca &&
      other.primario == primario &&
      other.secundario == secundario &&
      other.secundarioSobreOscuro == secundarioSobreOscuro &&
      other.secundarioSobreClaro == secundarioSobreClaro &&
      other.primarioBrillante == primarioBrillante &&
      other.sobrePrimario == sobrePrimario &&
      other.tintaSobreOscuro == tintaSobreOscuro &&
      other.tintaSobreOscuroBrillante == tintaSobreOscuroBrillante &&
      other.tintaSobreClaro == tintaSobreClaro &&
      other.suaveSobreOscuro == suaveSobreOscuro &&
      other.suaveSobreClaro == suaveSobreClaro;

  @override
  int get hashCode => Object.hash(primario, secundario, secundarioSobreOscuro,
      secundarioSobreClaro, primarioBrillante, sobrePrimario, tintaSobreOscuro,
      tintaSobreOscuroBrillante, tintaSobreClaro, suaveSobreOscuro,
      suaveSobreClaro);
}

/// Contraste WCAG 2.x entre dos colores opacos: de 1:1 (iguales) a 21:1
/// (negro y blanco).
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}
