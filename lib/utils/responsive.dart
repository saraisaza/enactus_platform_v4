import 'package:flutter/material.dart';

/// Tamaños de ventana de Material 3: compact (móvil), medium (tablet) y
/// expanded (escritorio). Único lugar de verdad para estos cortes — antes
/// de este archivo cada pantalla que tenía alguna lógica adaptativa
/// inventaba su propio número (900, 800, 760, 1080...), y ninguno cortaba
/// cerca de un ancho de teléfono real.
enum AppBreakpoint { compact, medium, expanded }

/// Da acceso a [AppBreakpoint] desde cualquier `BuildContext`, para
/// decisiones globales de página/navegación (qué nav mostrar, si un diálogo
/// va a pantalla completa, cuánto padding lateral usar). Usa
/// `MediaQuery.sizeOf` (no `MediaQuery.of(context).size`) para acotar el
/// rebuild solo a cambios de tamaño.
///
/// No reemplaza a `LayoutBuilder`: para decisiones que dependen del ancho
/// *disponible* dentro de un layout (p. ej. cuántas tarjetas caben dentro
/// del sidebar de un portal), seguí usando `LayoutBuilder` +
/// [responsiveColumns] — el ancho de ventana y el ancho disponible no son
/// lo mismo.
extension ResponsiveContext on BuildContext {
  AppBreakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 600) return AppBreakpoint.compact;
    if (width < 840) return AppBreakpoint.medium;
    return AppBreakpoint.expanded;
  }

  bool get isCompact => breakpoint == AppBreakpoint.compact;
  bool get isMedium => breakpoint == AppBreakpoint.medium;
  bool get isExpanded => breakpoint == AppBreakpoint.expanded;
}

/// Cuántas columnas caben en [maxWidth] dado un ancho mínimo de tarjeta y
/// el espacio entre ellas. Formula ya usada (copiada) en 10+ pantallas
/// detrás de su propio `LayoutBuilder`; se extrae acá para no seguir
/// repitiéndola, sin cambiar el resultado de ninguna pantalla existente.
int responsiveColumns(double maxWidth,
    {required double minCardWidth, double gap = 12}) {
  final columns = ((maxWidth + gap) / (minCardWidth + gap)).floor();
  return columns.clamp(1, 6);
}
