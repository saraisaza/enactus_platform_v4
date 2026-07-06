import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Gráficos del dashboard sobre fl_chart, siguiendo el sistema de
/// visualización: paleta categórica validada en orden fijo
/// ([AppColors.chartSeries]), marcas delgadas con extremos redondeados,
/// tooltips al pasar el mouse, grilla recesiva y texto siempre en tokens de
/// texto (nunca del color de la serie).
class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;
  const ChartCard(
      {super.key, required this.title, required this.child, this.height = 260});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

/// Barras verticales de una sola serie (sin leyenda: el título la nombra).
class SimpleBarChart extends StatelessWidget {
  final List<({String label, double value})> data;
  final double maxY;
  final Color color;
  final String Function(double)? valueFormat;

  const SimpleBarChart({
    super.key,
    required this.data,
    required this.maxY,
    Color? color,
    this.valueFormat,
  }) : color = color ?? const Color(0xFFC98500); // serie 1 de la paleta

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                valueFormat?.call(v) ?? v.toStringAsFixed(0),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                    style: const TextStyle(
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
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${data[group.x].label}\n'
              '${valueFormat?.call(rod.toY) ?? rod.toY.toStringAsFixed(1)}',
              const TextStyle(
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
                      style: const TextStyle(
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

  const SimpleLineChart({super.key, required this.data, Color? color})
      : color = color ?? const Color(0xFF3987E5); // serie 2 (azul)

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
              const FlLine(color: AppColors.border, strokeWidth: 0.5),
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
                  style: const TextStyle(
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
                      style: const TextStyle(
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
                      const TextStyle(
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
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
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

/// Indicador radial de progreso con número héroe al centro.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final String label;
  const ProgressRing({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              Center(
                child: Text('${(value * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
