import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/formatos.dart';
import '../l10n/textos.dart';

/// Gráficos del dashboard sobre fl_chart, siguiendo el sistema de
/// visualización: paleta categórica validada en orden fijo
/// ([AppColors.chartSeries]), marcas delgadas con extremos redondeados,
/// tooltips al pasar el mouse, grilla recesiva y texto siempre en tokens de
/// texto (nunca del color de la serie).
class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  /// Si hay, al lado del título va un botón para bajar la gráfica.
  final VoidCallback? alDescargar;

  /// Envuelve la tarjeta en un [RepaintBoundary] con esta llave: así se
  /// puede tomar como imagen para el reporte.
  final GlobalKey? llaveDeCaptura;

  const ChartCard(
      {super.key,
      required this.title,
      required this.child,
      this.height = 260,
      this.alDescargar,
      this.llaveDeCaptura});

  @override
  Widget build(BuildContext context) {
    final tarjeta = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              if (alDescargar != null)
                IconButton(
                  tooltip: tr.reporteDescargarGrafica,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.download_outlined,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: alDescargar,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
    if (llaveDeCaptura == null) return tarjeta;
    return RepaintBoundary(key: llaveDeCaptura, child: tarjeta);
  }
}

/// Barras verticales de una sola serie (sin leyenda: el título la nombra).
class SimpleBarChart extends StatelessWidget {
  final List<({String label, double value})> data;
  final double maxY;
  final Color color;
  final String Function(double)? valueFormat;

  SimpleBarChart({
    super.key,
    required this.data,
    required this.maxY,
    Color? color,
    this.valueFormat,
  }) : color = color ?? AppColors.chartSeries[0]; // serie 1 de la paleta

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              // El tope del eje (p. ej. 7,2) no lleva rótulo propio: redondeado
              // salía «7» encima del 7 de la escala, uno sobre otro.
              getTitlesWidget: (v, meta) => v == meta.max &&
                      v % meta.appliedInterval != 0
                  ? const SizedBox.shrink()
                  : Text(
                      valueFormat?.call(v) ?? v.toStringAsFixed(0),
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    data[i].label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.slate,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${data[group.x].label}\n'
              '${valueFormat?.call(rod.toY) ?? decimal(rod.toY)}',
              TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: data[i].value,
                width: 22,
                color: color,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)), // extremo de dato redondeado
              ),
            ]),
        ],
      ),
    );
  }
}

/// Dona de composición con leyenda y etiquetas directas.
/// Los colores siguen el orden fijo de la paleta; separador de 2px entre
/// segmentos (regla de espaciadores).
class DonutChart extends StatefulWidget {
  final List<({String label, double value})> data;
  const DonutChart({super.key, required this.data});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.data.fold<double>(0, (s, d) => s + d.value);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, // separador entre segmentos
              centerSpaceRadius: 46,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) => setState(() {
                  _touched =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                }),
              ),
              sections: [
                for (var i = 0; i < widget.data.length; i++)
                  PieChartSectionData(
                    value: widget.data[i].value,
                    color: AppColors
                        .chartSeries[i % AppColors.chartSeries.length],
                    radius: _touched == i ? 44 : 38,
                    showTitle: _touched == i,
                    title: total == 0
                        ? ''
                        : '${(widget.data[i].value / total * 100).round()}%',
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Leyenda (identidad nunca solo por color: marca + texto)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.data.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors
                            .chartSeries[i % AppColors.chartSeries.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${widget.data[i].label} · ${widget.data[i].value.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Línea temporal de una serie (2px, tooltip con crosshair de fl_chart).
class SimpleLineChart extends StatelessWidget {
  final List<({String label, double value})> data;
  final Color color;

  SimpleLineChart({super.key, required this.data, Color? color})
      : color = color ?? AppColors.chartSeries[1]; // serie 2 (azul)

  @override
  Widget build(BuildContext context) {
    final maxY =
        data.fold<double>(0, (m, d) => d.value > m ? d.value : m) * 1.25 + 1;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= data.length || v != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(data[i].label,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.slate,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${data[s.x.toInt()].label}: ${s.y.toStringAsFixed(0)}',
                      TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].value),
            ],
            color: color,
            barWidth: 2,
            isCurved: false,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: AppColors.surface, // anillo de superficie 2px
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador radial de progreso con número héroe al centro. [size]/
/// [strokeWidth]/[percentFontSize] permiten variantes más chicas (p. ej. la
/// tarjeta de progreso general del Dashboard, 96px) sin duplicar el widget.
/// [colors] tiñe el anillo con los tokens de tema claro/oscuro de una
/// pantalla (`ContentColors`); `null` mantiene el tema oscuro fijo de
/// [AppColors], como lo usaban los call sites originales.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1

  /// `null` u vacío = sin etiqueta debajo del anillo (p. ej. cuando el
  /// texto de contexto se arma aparte, al lado — ver Dashboard).
  final String? label;
  final double size;
  final double strokeWidth;
  final double percentFontSize;
  final ContentColors? colors;
  const ProgressRing({
    super.key,
    required this.value,
    this.label,
    this.size = 130,
    this.strokeWidth = 9,
    this.percentFontSize = 26,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final track = colors?.surface2 ?? AppColors.surfaceAlt;
    final percentColor = colors?.text ?? AppColors.textPrimary;
    final labelColor = colors?.text2 ?? AppColors.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                  backgroundColor: track,
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              Center(
                child: Text('${(value * 100).round()}%',
                    style: TextStyle(
                        fontSize: percentFontSize,
                        fontWeight: FontWeight.w700,
                        color: percentColor)),
              ),
            ],
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(label!, style: TextStyle(color: labelColor, fontSize: 13)),
        ],
      ],
    );
  }
}
