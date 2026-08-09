import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Construye un widget en función de si el mouse está encima.
/// Base de todos los efectos "reveal on hover" de la plataforma.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  const HoverBuilder(
      {super.key, required this.builder, this.cursor = MouseCursor.defer});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.builder(context, _hover),
    );
  }
}

/// Aparición con fade + deslizamiento + escala, con retardo opcional para
/// crear efectos escalonados (stagger) en dashboards y listas.
class Entrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Entrance({super.key, required this.child, this.delayMs = 0});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delayMs == 0) {
      // Sin retardo: visible en el primer frame renderizado.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.97,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tarjeta interactiva: al pasar el mouse se eleva (sombra), escala 1.02,
/// aclara el fondo y el borde se tiñe de un color de acento. Por defecto
/// usa los tokens fijos de tema oscuro de [AppColors] (como siempre); las
/// pantallas con tema claro/oscuro propio ([ContentColors]) o con acento
/// por dato (ODS, laboratorio) pueden pasar [bg]/[bgHover]/[borderColor]/
/// [borderHoverColor] sin bifurcar el widget.
class HoverCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Escala en hover (1.0 = sin zoom). 1.02 por defecto.
  final double hoverScale;
  final Color? bg;
  final Color? bgHover;
  final Color? borderColor;
  final Color? borderHoverColor;

  const HoverCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(16),
      this.hoverScale = 1.02,
      this.bg,
      this.bgHover,
      this.borderColor,
      this.borderHoverColor});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hover ? hoverScale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: padding,
            decoration: BoxDecoration(
              color: hover
                  ? (bgHover ?? AppColors.surfaceAlt)
                  : (bg ?? AppColors.surface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hover
                      ? (borderHoverColor ?? AppColors.gold)
                      : (borderColor ?? AppColors.border),
                  width: hover ? 1.2 : 1),
              boxShadow: hover
                  ? const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 18,
                          offset: Offset(0, 6)),
                    ]
                  : const [],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Círculo con la inicial del nombre en mayúscula: el mismo patrón se
/// repetía copiado en cada lista de personas de la plataforma (equipos,
/// foro, BuscaTalento, perfiles...). [large] usa los colores/tamaño de
/// encabezado de perfil; [radius] permite ajustar el tamaño exacto sin
/// duplicar el resto del widget.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final bool large;
  final double? radius;
  final double? fontSize;
  const InitialsAvatar(this.name,
      {super.key, this.large = false, this.radius, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return CircleAvatar(
      radius: radius ?? (large ? 26 : null),
      backgroundColor: large ? AppColors.gold : AppColors.slate,
      child: Text(
        initial,
        style: large
            ? TextStyle(
                fontSize: fontSize ?? 19,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1400))
            : const TextStyle(
                color: AppColors.gold, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Tile de estadística: número héroe con contador animado + etiqueta.
/// [detail] agrega un tooltip con el desglose al pasar el mouse.
/// [trend] muestra una línea secundaria (p. ej. "↑ +18 este mes").
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String? detail;
  final String? trend;
  const StatTile(
      {super.key,
      required this.value,
      required this.label,
      required this.icon,
      this.detail,
      this.trend});

  @override
  Widget build(BuildContext context) {
    final tile = HoverCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedValue(value: value),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                if (trend != null)
                  Text(trend!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.statusGood,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
    return detail == null ? tile : Tooltip(message: detail!, child: tile);
  }
}

/// Anima el número inicial de un valor tipo "450", "68%" o "120 h".
class _AnimatedValue extends StatelessWidget {
  final String value;
  const _AnimatedValue({required this.value});

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(value);
    final style = knockoutHeading(
        fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    if (match == null) return Text(value, style: style);
    final number = int.parse(match.group(1)!);
    final suffix = match.group(2)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: number.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Fila de StatTiles adaptable, con aparición escalonada (stagger).
class StatRow extends StatelessWidget {
  final List<StatTile> tiles;
  const StatRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 3 : 2);
      final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < tiles.length; i++)
            SizedBox(
              width: width,
              child: Entrance(delayMs: 70 * i, child: tiles[i]),
            ),
        ],
      );
    });
  }
}

/// Barra de progreso delgada con etiqueta de porcentaje.
/// [tooltip] muestra el detalle (p. ej. "17 de 25 lecciones") en hover.
class ThinProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final String? tooltip;
  const ThinProgressBar(
      {super.key,
      required this.value,
      this.color = AppColors.gold,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final bar = Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
    return tooltip == null
        ? bar
        : Tooltip(
            message: '${(value * 100).round()}%\n$tooltip', child: bar);
  }
}

/// Estado vacío estándar. Sin [title]/acciones: ícono+mensaje centrado,
/// como lo usan hoy ~15 pantallas. Con [title] (y opcionalmente
/// [primaryLabel]/[secondaryLabel]): la versión de alta fidelidad del
/// portal estudiante (`design_handoff_portal_estudiante/README.md`) — caja
/// con borde punteado, ícono en caja dorada, título Knockout y hasta dos
/// botones de acción. [colors] tiñe la variante con tokens de tema
/// claro/oscuro de una pantalla; `null` = tema oscuro fijo de [AppColors].
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? title;
  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final ContentColors? colors;
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.primaryLabel,
    this.primaryIcon = Icons.restart_alt,
    this.onPrimary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (title == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    final c = colors ?? ContentColors.dark;
    return _DashedRRectBorder(
      color: c.border,
      radius: 20,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        decoration:
            BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  color: c.goldSoft, borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, size: 36, color: c.goldInk),
            ),
            const SizedBox(height: 16),
            Text(title!.toUpperCase(),
                style: knockoutHeading(
                    fontSize: 38, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.55, color: c.text2)),
            ),
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (primaryLabel != null)
                    ElevatedButton.icon(
                      onPressed: onPrimary,
                      icon: Icon(primaryIcon, size: 19),
                      label: Text(primaryLabel!),
                    ),
                  if (secondaryLabel != null)
                    OutlinedButton.icon(
                      onPressed: onSecondary,
                      icon: Icon(secondaryIcon ?? Icons.mail_outline, size: 19),
                      label: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Borde punteado — Flutter no lo trae de fábrica; se dibuja a mano sobre
/// el contorno redondeado del hijo. Usado por la variante de alta
/// fidelidad de [EmptyState].
class _DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const _DashedRRectBorder(
      {required this.child, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Título de sección dentro de una pestaña (Knockout, mayúsculas). Espaciado
/// arriba/abajo fijo: al ser el único widget de encabezado de sección de
/// toda la app, mantenerlo centralizado aquí es lo que garantiza que ese
/// espaciado quede consistente sitio-wide sin repetirlo en cada vista.
/// Borde delgado tricolor (amarillo, azul, rojo) que evoca la bandera de
/// Colombia, izquierda a derecha. Usado como acento superior en header/footer.
class ColombiaFlagBar extends StatelessWidget {
  final double height;
  const ColombiaFlagBar({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: ColoredBox(color: AppColors.colombiaYellow)),
          Expanded(child: ColoredBox(color: AppColors.colombiaBlue)),
          Expanded(child: ColoredBox(color: AppColors.colombiaRed)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(text.toUpperCase(),
          style: knockoutHeading(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary)),
    );
  }
}

/// Chip de estado con icono (nunca solo color).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const StatusChip(
      {super.key, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Insignia del estado de una fase de la Ruta de Impacto para un
/// estudiante: completa, en curso o bloqueada. Se usa en los portales de
/// Mentor y Asesor para mostrar en qué fase/laboratorio va cada estudiante.
class PhaseBadge extends StatelessWidget {
  final String label;
  final bool complete;
  final bool unlocked;
  const PhaseBadge(
      {super.key,
      required this.label,
      required this.complete,
      required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = complete
        ? (AppColors.statusGood, Icons.check_circle)
        : unlocked
            ? (AppColors.statusWarning, Icons.hourglass_empty)
            : (AppColors.textMuted, Icons.lock_outline);
    return StatusChip(label: label, color: color, icon: icon);
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline : Icons.check_circle_outline,
          color: error ? AppColors.statusCritical : AppColors.gold, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
    ]),
  ));
}

/// Micro-interacción de éxito: check animado que aparece al centro y se
/// desvanece solo. Úsala al completar lecciones, enviar entregas, aprobar
/// quizzes o emitir certificados — el progreso se siente gratificante.
void showSuccessCheck(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SuccessToast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _SuccessToast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _SuccessToast({required this.message, required this.onDone});

  @override
  State<_SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<_SuccessToast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _visible = false);
    });
    Future.delayed(const Duration(milliseconds: 1750), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedScale(
              scale: _visible ? 1 : 0.7,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.statusGood.withValues(alpha: 0.6)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 24,
                        offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusGood.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.statusGood, size: 34),
                    ),
                    const SizedBox(height: 10),
                    Text(widget.message,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
    BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
      ],
    ),
  );
  return result ?? false;
}

/// Doble verificación para acciones destructivas (eliminar usuarios,
/// mentores o cursos): además de confirmar, hay que escribir ELIMINAR.
Future<bool> confirmDoubleDialog(
    BuildContext context, String title, String message) async {
  const keyword = 'ELIMINAR';
  final ctrl = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.statusCritical),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                    color: AppColors.statusCritical,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Escribe $keyword para confirmar',
                  hintText: keyword,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: ctrl.text.trim().toUpperCase() == keyword
                ? () => Navigator.pop(ctx, true)
                : null,
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
