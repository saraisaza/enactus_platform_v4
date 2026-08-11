import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../utils/app_theme.dart';
import '../utils/colombia_cities.dart';

/// Ruta del asset copiado de `design_handoff_mapa_estudiantes/colombia-110m.json`
/// (Natural Earth 110m, dominio público, vía `world-atlas@2.0.2`). Geometría
/// real, nunca dibujada a mano — ver el README del handoff.
const String kColombiaGeometryAsset = 'assets/data/colombia-110m.json';

typedef LonLat = (double lon, double lat);

/// Un `Feature` GeoJSON de tipo `MultiPolygon` ya parseado a listas de
/// puntos `(lon, lat)`: polígono → anillo → puntos. El archivo del handoff
/// trae un solo polígono de un solo anillo, pero el parser no asume eso —
/// funciona igual si algún día se usa una geometría con islas.
class ColombiaGeometry {
  final List<List<List<LonLat>>> polygons;
  const ColombiaGeometry(this.polygons);

  static ColombiaGeometry parse(String geoJson) {
    final root = json.decode(geoJson) as Map<String, dynamic>;
    final geometry = root['geometry'] as Map<String, dynamic>;
    final rawCoords = geometry['coordinates'] as List;
    final polygons = <List<List<LonLat>>>[];
    for (final rawPoly in rawCoords) {
      final rings = <List<LonLat>>[];
      for (final rawRing in rawPoly as List) {
        final points = <LonLat>[];
        for (final rawPoint in rawRing as List) {
          points.add(((rawPoint[0] as num).toDouble(), (rawPoint[1] as num).toDouble()));
        }
        rings.add(points);
      }
      polygons.add(rings);
    }
    return ColombiaGeometry(polygons);
  }

  static Future<ColombiaGeometry> load() async {
    final raw = await rootBundle.loadString(kColombiaGeometryAsset);
    return parse(raw);
  }
}

/// Mercator esférica ajustada a una caja con margen — mismas fórmulas del
/// README (`design_handoff_mapa_estudiantes`), nada de un paquete de mapas:
/// `x = lon·π/180`, `y = ln(tan(π/4 + lat·π/360))`, luego se ajustan los
/// límites del polígono a la caja y se invierte el eje Y al pasar a
/// pantalla. La latitud se recorta a ±85° para evitar el infinito de
/// Mercator (irrelevante para Colombia, deja la función reutilizable).
class MercatorFit {
  final double k;
  final double dx;
  final double dy;
  const MercatorFit({required this.k, required this.dx, required this.dy});

  static ({double x, double y}) _forward(double lon, double lat) {
    final la = lat.clamp(-85.0, 85.0) * math.pi / 180;
    return (x: lon * math.pi / 180, y: math.log(math.tan(math.pi / 4 + la / 2)));
  }

  factory MercatorFit.fit(ColombiaGeometry geometry, double width, double height, double pad) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final polygon in geometry.polygons) {
      for (final ring in polygon) {
        for (final p in ring) {
          final q = _forward(p.$1, p.$2);
          if (q.x < x0) x0 = q.x;
          if (q.x > x1) x1 = q.x;
          if (q.y < y0) y0 = q.y;
          if (q.y > y1) y1 = q.y;
        }
      }
    }
    final k = math.min((width - pad * 2) / (x1 - x0), (height - pad * 2) / (y1 - y0));
    final dx = (width - k * (x1 + x0)) / 2;
    final dy = (height + k * (y1 + y0)) / 2;
    return MercatorFit(k: k, dx: dx, dy: dy);
  }

  Offset project(double lon, double lat) {
    final q = _forward(lon, lat);
    return Offset(q.x * k + dx, dy - q.y * k);
  }
}

class _ColombiaLandPainter extends CustomPainter {
  final ColombiaGeometry geometry;
  final MercatorFit fit;
  final Color fillColor;
  final Color strokeColor;
  const _ColombiaLandPainter(
      {required this.geometry, required this.fit, required this.fillColor, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final polygon in geometry.polygons) {
      for (final ring in polygon) {
        for (var i = 0; i < ring.length; i++) {
          final p = fit.project(ring[i].$1, ring[i].$2);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
      }
    }
    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  // El polígono es fijo (100 puntos) y el repintado solo ocurre cuando
  // cambian tamaño/tema — barato de sobra para no molestarse en comparar.
  @override
  bool shouldRepaint(covariant _ColombiaLandPainter oldDelegate) => true;
}

/// Radio del punto por raíz cuadrada del valor (nunca por diámetro): el
/// área debe ser proporcional al valor, si no las ciudades grandes se
/// exageran. Ver README, sección "Mapa".
double cityDotRadius(int value, int maxValue) =>
    math.max(3.5, math.sqrt(value / math.max(1, maxValue)) * 26);

/// Un punto ya resuelto para pintar: ciudad + valor + color de nivel +
/// universidades reales de esa ciudad (no las del prototipo). El color y
/// la leyenda los decide quien arma la lista (ver `studentCountTiers` en
/// `students_map_view.dart`) — este widget no sabe qué significa "nivel".
class CityMapPoint {
  final ColombiaCity city;
  final int value;
  final Color color;
  final List<String> universities;
  const CityMapPoint(
      {required this.city, required this.value, required this.color, required this.universities});
}

class MapLegendEntry {
  final Color color;
  final String label;
  const MapLegendEntry({required this.color, required this.label});
}

class _PlacedPoint {
  final CityMapPoint point;
  final Offset pos;
  final double r;
  const _PlacedPoint(this.point, this.pos, this.r);
}

/// Mapa de Colombia con puntos por ciudad — geometría real (Natural Earth
/// 110m, cargada de `assets/`), proyección Mercator propia, sin paquete de
/// mapas. Hover en un punto muestra el tooltip y atenúa los demás; el
/// resaltado también puede venir de afuera (`hoveredCity`, para el vínculo
/// bidireccional con el listado lateral).
class ColombiaStudentsMap extends StatefulWidget {
  final List<CityMapPoint> points;
  final List<MapLegendEntry> legend;
  final ContentColors colors;
  final bool isDark;
  final String? hoveredCity;
  final ValueChanged<String?> onHoverCity;
  final String tooltipSuffix;

  const ColombiaStudentsMap({
    super.key,
    required this.points,
    required this.legend,
    required this.colors,
    required this.isDark,
    required this.hoveredCity,
    required this.onHoverCity,
    this.tooltipSuffix = 'estudiantes',
  });

  @override
  State<ColombiaStudentsMap> createState() => _ColombiaStudentsMapState();
}

class _ColombiaStudentsMapState extends State<ColombiaStudentsMap> {
  ColombiaGeometry? _geometry;
  Object? _loadError;
  Offset? _pointerLocal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final geo = await ColombiaGeometry.load();
      if (mounted) setState(() => _geometry = geo);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_off, size: 34, color: colors.text3),
              const SizedBox(height: 14),
              Text('No se pudo cargar el mapa',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
              const SizedBox(height: 6),
              Text('Las cifras y el listado siguen disponibles a la derecha.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: colors.text3)),
            ],
          ),
        ),
      );
    }
    if (_geometry == null) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.goldInk));
    }

    final maxValue =
        widget.points.isEmpty ? 1 : widget.points.map((p) => p.value).reduce(math.max);
    // Los grandes se dibujan primero (abajo) y los chicos encima, igual que
    // el prototipo: si dos halos se superponen, el más chico gana el hover.
    final sorted = [...widget.points]..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
      final fit = MercatorFit.fit(_geometry!, size.width, size.height, 40);
      final placed = [
        for (final p in sorted) _PlacedPoint(p, fit.project(p.city.lon, p.city.lat), cityDotRadius(p.value, maxValue)),
      ];

      void handleHover(Offset local) {
        setState(() => _pointerLocal = local);
        for (final e in placed.reversed) {
          final haloR = math.max(6.0, e.r) * 1.9;
          if ((e.pos - local).distance <= haloR) {
            if (widget.hoveredCity != e.point.city.name) {
              widget.onHoverCity(e.point.city.name);
            }
            return;
          }
        }
        if (widget.hoveredCity != null) widget.onHoverCity(null);
      }

      _PlacedPoint? hoveredPoint;
      if (widget.hoveredCity != null) {
        for (final e in placed) {
          if (e.point.city.name == widget.hoveredCity) {
            hoveredPoint = e;
            break;
          }
        }
      }

      return MouseRegion(
        onHover: (event) => handleHover(event.localPosition),
        onExit: (_) {
          setState(() => _pointerLocal = null);
          if (widget.hoveredCity != null) widget.onHoverCity(null);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: _ColombiaLandPainter(
                geometry: _geometry!,
                fit: fit,
                fillColor: colors.surface2,
                strokeColor: colors.border,
              ),
            ),
            for (final e in placed)
              _CityDot(
                center: e.pos,
                radius: e.r,
                color: e.point.color,
                label: e.point.value >= maxValue * 0.35 ? e.point.city.name : null,
                highlighted: widget.hoveredCity == e.point.city.name,
                dimmed: widget.hoveredCity != null && widget.hoveredCity != e.point.city.name,
                isDark: widget.isDark,
                colors: colors,
              ),
            if (hoveredPoint != null && _pointerLocal != null)
              _CityTooltip(anchor: _pointerLocal!, point: hoveredPoint.point, suffix: widget.tooltipSuffix),
            Positioned(
              left: 22,
              bottom: 20,
              child: _MapLegend(
                  legend: widget.legend, maxValue: maxValue, colors: colors, isDark: widget.isDark),
            ),
          ],
        ),
      );
    });
  }
}

class _CityDot extends StatelessWidget {
  final Offset center;
  final double radius;
  final Color color;
  final String? label;
  final bool highlighted;
  final bool dimmed;
  final bool isDark;
  final ContentColors colors;
  const _CityDot({
    required this.center,
    required this.radius,
    required this.color,
    required this.label,
    required this.highlighted,
    required this.dimmed,
    required this.isDark,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final haloR = math.max(6.0, radius) * 1.9;
    final box = haloR * 2 + 40; // margen extra para que la etiqueta no se corte
    final coreBorderColor =
        highlighted ? colors.text : (isDark ? const Color(0xFF0D0F11) : Colors.white);
    final coreBorderWidth = highlighted ? 2.0 : (isDark ? 1.3 : 1.6);

    return Positioned(
      left: center.dx - box / 2,
      top: center.dy - box / 2,
      width: box,
      height: box,
      child: IgnorePointer(
        // El hit-test real lo hace el MouseRegion del mapa completo (así el
        // círculo más chico puede "ganar" cuando dos halos se superponen);
        // este widget solo pinta.
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: dimmed ? 0.25 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: haloR * 2,
                height: haloR * 2,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
              ),
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: coreBorderColor, width: coreBorderWidth),
                ),
              ),
              if (label != null)
                Positioned(
                  bottom: box / 2 + radius + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _StrokedLabel(text: label!, fillColor: colors.text2, strokeColor: colors.surface2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto con contorno (`paint-order:stroke` en el prototipo): dos `Text`
/// superpuestos, uno con `Paint` de trazo detrás para que la etiqueta se
/// lea sobre los puntos y el relleno del mapa.
class _StrokedLabel extends StatelessWidget {
  final String text;
  final Color fillColor;
  final Color strokeColor;
  const _StrokedLabel({required this.text, required this.fillColor, required this.strokeColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.5
                  ..color = strokeColor)),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fillColor)),
      ],
    );
  }
}

class _CityTooltip extends StatelessWidget {
  final Offset anchor;
  final CityMapPoint point;
  final String suffix;
  const _CityTooltip({required this.anchor, required this.point, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1.18),
          child: Container(
            constraints: const BoxConstraints(minWidth: 172),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xEB0A0C0E),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: point.color)),
                    const SizedBox(width: 8),
                    Text(point.city.name.toUpperCase(),
                        style: knockoutHeading(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(point.city.department,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${point.value}',
                        style: knockoutHeading(fontSize: 26, fontWeight: FontWeight.w800, color: point.color)),
                    const SizedBox(width: 8),
                    Text(suffix, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.72))),
                  ],
                ),
                if (point.universities.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                      margin: const EdgeInsets.only(bottom: 7)),
                  Text(point.universities.join(' · '),
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.white.withValues(alpha: 0.66))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  final List<MapLegendEntry> legend;
  final int maxValue;
  final ContentColors colors;
  final bool isDark;
  const _MapLegend(
      {required this.legend, required this.maxValue, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (legend.isEmpty) return const SizedBox.shrink();
    final steps = [
      math.max(1, (maxValue * 0.1).round()),
      (maxValue * 0.45).round(),
      maxValue,
    ];
    // `body.light .legend` en el prototipo: el vidrio pasa de negro a
    // blanco translúcido en tema claro, el texto sigue los tokens
    // (colors.text3/text2) en vez de un hex fijo.
    final panelColor = isDark ? const Color(0xB80A0C0E) : const Color(0xDBFFFFFF);
    final panelBorder = isDark ? Colors.white.withValues(alpha: 0.1) : colors.border;
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.14) : colors.border;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ESTUDIANTES POR CIUDAD',
                  style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 10.5 * 0.14,
                      fontWeight: FontWeight.w600,
                      color: colors.text3)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final v in steps) ...[
                    _LegendSize(value: v, radius: math.max(4, cityDotRadius(v, maxValue)), colors: colors),
                    const SizedBox(width: 11),
                  ],
                ],
              ),
              Container(margin: const EdgeInsets.only(top: 12, bottom: 11), height: 1, color: dividerColor),
              for (final entry in legend)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: entry.color)),
                      const SizedBox(width: 8),
                      Text(entry.label, style: TextStyle(fontSize: 11, color: colors.text2)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSize extends StatelessWidget {
  final int value;
  final double radius;
  final ContentColors colors;
  const _LegendSize({required this.value, required this.radius, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF4C430).withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 5),
        Text('$value', style: TextStyle(fontSize: 10.5, color: colors.text3)),
      ],
    );
  }
}
