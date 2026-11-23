import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../l10n/textos.dart';
import '../utils/app_theme.dart';
import '../utils/tema.dart';
import '../utils/marca.dart';
import '../utils/responsive.dart';

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
      // Tope de 400 ms: las listas escalonan con `55 * i`, y sin tope la
      // tarjeta 100 aparecía a los 5,5 s; al desplazarse rápido (en el
      // teléfono, con el dedo) se veían huecos vacíos.
      final retraso = widget.delayMs > 400 ? 400 : widget.delayMs;
      Future.delayed(Duration(milliseconds: retraso), () {
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

/// Como [HoverBuilder], pero además hace que [onTap] se pueda activar con
/// teclado: `Tab` enfoca la tarjeta y `Enter`/`Espacio` la activa (antes
/// estas tarjetas solo usaban `GestureDetector`, que no participa del orden
/// de foco de Flutter — Tab nunca las alcanzaba). El `builder` recibe
/// `true` tanto en hover como en foco, así que cualquier estilo reactivo
/// (borde, elevación, escala…) que ya tuvieras también se ve al navegar
/// con teclado, sin tocar la lógica visual de cada call site. Si [onTap]
/// es `null`, se comporta exactamente igual que [HoverBuilder] (sin foco
/// ni `Semantics` de botón — no hay nada que activar).
class KeyboardHoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool highlighted) builder;
  final VoidCallback? onTap;
  const KeyboardHoverBuilder({super.key, required this.builder, this.onTap});

  @override
  State<KeyboardHoverBuilder> createState() => _KeyboardHoverBuilderState();
}

class _KeyboardHoverBuilderState extends State<KeyboardHoverBuilder> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final child = MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onTap,
        child: widget.builder(context, _hover || _focused),
      ),
    );
    if (onTap == null) return child;
    return FocusableActionDetector(
      onShowFocusHighlight: (show) => setState(() => _focused = show),
      // `FocusableActionDetector` NO trae por sí solo un atajo de teclado
      // que dispare `ActivateIntent` — sin este `shortcuts:` explícito, el
      // `actions:` de abajo queda enchufado a la nada: la tarjeta SÍ recibe
      // foco con Tab (se ve el resaltado), pero Enter/Espacio no hacían
      // nada (confirmado con un test real: el foco llegaba, la URL no
      // cambiaba). `InkWell`/`ElevatedButton` traen este mapeo de fábrica;
      // como esto no es ninguno de los dos, hay que declararlo a mano.
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          onTap();
          return null;
        }),
      },
      child: Semantics(button: true, onTap: onTap, child: child),
    );
  }
}

/// Tarjeta interactiva: al pasar el mouse (o enfocar con teclado — ver
/// [KeyboardHoverBuilder]) se eleva (sombra), escala 1.02, aclara el fondo
/// y el borde se tiñe de un color de acento. Por defecto usa los tokens
/// fijos de tema oscuro de [AppColors] (como siempre); las pantallas con
/// tema claro/oscuro propio ([ContentColors]) o con acento por dato (ODS,
/// laboratorio) pueden pasar [bg]/[bgHover]/[borderColor]/[borderHoverColor]
/// sin bifurcar el widget.
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
    return KeyboardHoverBuilder(
      onTap: onTap,
      builder: (context, active) => AnimatedScale(
        scale: active ? hoverScale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: padding,
          decoration: BoxDecoration(
            color: active
                ? (bgHover ?? AppColors.surfaceAlt)
                : (bg ?? AppColors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active
                    ? (borderHoverColor ?? AppColors.gold)
                    : (borderColor ?? AppColors.border),
                width: active ? 1.2 : 1),
            boxShadow: active
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
      backgroundColor: large ? AppColors.relleno : AppColors.slate,
      child: Text(
        initial,
        style: large
            ? TextStyle(
                fontSize: fontSize ?? 19,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)
            : TextStyle(
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
    final icono = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.gold, size: 22),
    );
    List<Widget> textos(TextAlign alineado) => [
          _AnimatedValue(value: value),
          Text(label,
              textAlign: alineado,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (trend != null)
            Text(trend!,
                textAlign: alineado,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.statusGood,
                    fontWeight: FontWeight.w600)),
        ];
    final tile = HoverCard(
      child: LayoutBuilder(builder: (context, caja) {
        // Angosta (dos por fila en un teléfono): el ícono arriba y todo
        // centrado. Al lado del ícono, «Universidades» no cabía y se partía
        // en «Universidad / es».
        if (caja.maxWidth < 170) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icono,
              const SizedBox(height: 8),
              ...textos(TextAlign.center),
            ],
          );
        }
        return Row(
          children: [
            icono,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: textos(TextAlign.start),
              ),
            ),
          ],
        );
      }),
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
    final style = displayHeading(
        fontSize: 26,
        color: AppColors.textPrimary,
        height: 1.0,
        letterSpacing: 0);
    if (match == null) return Text(value, style: style);
    final number = int.parse(match.group(1)!);
    final suffix = match.group(2)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: number.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}$suffix', style: style),
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

  /// Sin color, el acento de la marca. No puede ser el valor por defecto del
  /// parámetro: el acento se resuelve al dibujar (ver `Marca`).
  final Color? color;
  final String? tooltip;
  const ThinProgressBar(
      {super.key,
      required this.value,
      this.color,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final barra = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: AppColors.surfaceAlt,
          // Sin color propio, el secundario de la marca.
          valueColor: AlwaysStoppedAnimation(color ?? AppColors.secundario),
        ),
      ),
    );
    final porcentaje = Text('${(value * 100).round()}%',
        textAlign: TextAlign.right,
        style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600));
    final bar = LayoutBuilder(builder: (context, caja) {
      // En una caja muy angosta —un teléfono con la letra agrandada— el
      // porcentaje va encima de la barra: al lado necesitaba 52 dp fijos y la
      // fila se salía.
      if (caja.maxWidth < 100) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [porcentaje, const SizedBox(height: 4), barra],
        );
      }
      return Row(
        children: [
          Expanded(child: barra),
          const SizedBox(width: 10),
          SizedBox(width: 42, child: porcentaje),
        ],
      );
    });
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
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    final c = colors ?? ContentColors.dark;
    return DashedRRectBorder(
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
                style: displayHeading(
                    fontSize: 38, fontWeight: AppWeights.display, color: c.text)),
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
/// fidelidad de [EmptyState] y por cajas vacías más chicas dentro de una
/// tarjeta (p. ej. "sin certificados aún" en Mi Perfil).
class DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedRRectBorder(
      {super.key, required this.child, required this.color, required this.radius});

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
/// Filete delgado de un solo tono (naranja de marca). Reemplaza el borde
/// tricolor original (bandera de Colombia) — el tricolor peleaba con la
/// paleta cálida naranja/marrón. Usado como acento superior en header/footer.
class ColombiaFlagBar extends StatelessWidget {
  final double height;
  const ColombiaFlagBar({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    final paleta = Marca.instancia.paleta;
    return SizedBox(
      height: height,
      width: double.infinity,
      // Con la marca de un cliente, sus dos colores: del primario al
      // secundario.
      child: paleta.esDeCliente
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [paleta.primario, paleta.secundario]),
              ),
            )
          : ColoredBox(color: AppColors.relleno),
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
          style: displayHeading(
              fontSize: 26,
              color: AppColors.textPrimary,
              height: 1.05,
              letterSpacing: 26 * 0.012)),
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
          // `Flexible`: la ficha vive casi siempre dentro de un `Wrap`, que le
          // ofrece a lo sumo su propio ancho. Con la etiqueta pidiendo su
          // ancho natural, un rótulo largo en una tarjeta angosta desborda —
          // por poco, pero desborda. Prefiere recortar antes que romper.
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
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

/// La etiqueta de un campo que hay que llenar para poder guardar: con un
/// asterisco al final, la convención que todos reconocen. Solo para los
/// campos que el formulario de verdad exige — un asterisco en un campo
/// opcional enseña a ignorarlos.
String obligatorio(String etiqueta) => '$etiqueta *';

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

/// El aviso de que algo salió bien: entregar una actividad, guardar,
/// publicar, calificar, subir un archivo.
///
/// Una notificación tipo «toast» que entra barriendo desde la derecha, en la
/// esquina superior derecha, con el check, el título, una explicación
/// opcional ([detalle]) y, si hay [accion], un botón que la ejecuta (p. ej.
/// «Ver entrega»). Una barra al pie se va vaciando mientras el aviso sigue
/// a la vista; al terminar, sale barriendo hacia la derecha.
///
/// No tapa la pantalla ni hay que cerrarlo para seguir: antes era una
/// tarjeta en el centro, con velo, que pedía «Continuar» cada vez que se
/// guardaba algo (recomendaciones del 20 de noviembre). Se cierra solo, con
/// la X, o pasándole el dedo hacia un lado. Mientras el mouse está encima
/// no se va.
///
/// Va en la capa de más arriba, así que sobrevive a que quien lo pidió
/// cierre su diálogo justo antes —que es lo que hacen casi todos—. Uno nuevo
/// reemplaza al anterior.
void showSuccessCheck(
  BuildContext context,
  String message, {
  String? detalle,
  String? accion,
  VoidCallback? alAccion,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _avisoAbierto?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AvisoDeExito(
      titulo: message,
      detalle: detalle,
      accion: accion,
      alAccion: alAccion,
      alCerrar: () {
        if (_avisoAbierto == entry) _avisoAbierto = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _avisoAbierto = entry;
  overlay.insert(entry);
}

OverlayEntry? _avisoAbierto;

/// Los colores del aviso: el verde es el de «salió bien», no el acento de la
/// marca, así que no cambia con el cliente. La tarjeta sigue al modo claro u
/// oscuro.
abstract final class _ColoresDelAviso {
  static const check = Color(0xFF3FB26C);
  static Color get fondoDelCheck => check.withValues(alpha: 0.16);
  static Color get tarjeta => Tema.oscuro
      ? const Color(0xFF232327)
      : const Color(0xFFFFFFFF);
  static Color get borde => Tema.oscuro
      ? const Color(0xFF34343A)
      : const Color(0xFFD8D4CE);
  static Color get titulo => AppColors.textPrimary;
  static Color get detalle => AppColors.textSecondary;
}

/// La tarjeta de [showSuccessCheck].
class AvisoDeExito extends StatefulWidget {
  final String titulo;
  final String? detalle;
  final String? accion;
  final VoidCallback? alAccion;
  final VoidCallback alCerrar;

  /// Cuánto queda a la vista. Con una acción, más: hay algo que decidir.
  final Duration? duracion;

  const AvisoDeExito({
    super.key,
    required this.titulo,
    required this.alCerrar,
    this.detalle,
    this.accion,
    this.alAccion,
    this.duracion,
  });

  @override
  State<AvisoDeExito> createState() => _AvisoDeExitoState();
}

class _AvisoDeExitoState extends State<AvisoDeExito>
    with TickerProviderStateMixin {
  /// La entrada y la salida: el barrido desde la derecha.
  late final AnimationController _barrido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();

  /// El tiempo a la vista: la barra del pie.
  late final AnimationController _tiempo = AnimationController(
    vsync: this,
    duration: widget.duracion ??
        Duration(seconds: widget.accion != null ? 8 : 5),
  )
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _cerrar();
    })
    ..forward();

  bool _cerrado = false;

  @override
  void dispose() {
    _barrido.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    _tiempo.stop();
    if (mounted) await _barrido.reverse();
    widget.alCerrar();
  }

  void _accion() {
    _cerrar();
    widget.alAccion?.call();
  }

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final ancho = medidas.size.width;
    final accion = widget.accion;
    // Debajo del encabezado en el computador; arriba de todo en el
    // teléfono, dentro del área segura.
    final arriba = medidas.padding.top + (ancho < 600 ? 12.0 : 96.0);
    final curva = CurvedAnimation(
      parent: _barrido,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // `Material` debajo de todo: sin él, el texto que se dibuja en esta capa
    // no hereda estilo y Flutter lo marca con el subrayado amarillo doble.
    return Positioned(
      top: arriba,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: Tween(begin: const Offset(1.15, 0), end: Offset.zero)
              .animate(curva),
          child: FadeTransition(
            opacity: curva,
            child: MouseRegion(
              // Mientras se lee con el mouse encima, no se va.
              onEnter: (_) => _tiempo.stop(),
              onExit: (_) {
                if (!_cerrado) _tiempo.forward();
              },
              child: Dismissible(
                key: const ValueKey('aviso-deslizable'),
                onDismissed: (_) {
                  _cerrado = true;
                  _tiempo.stop();
                  widget.alCerrar();
                },
                child: Semantics(
                  // Se anuncia sin mover el foco: es una confirmación, no
                  // una pregunta.
                  liveRegion: true,
                  container: true,
                  label: widget.titulo,
                  child: Container(
                    key: const ValueKey('aviso-de-exito'),
                    width: 360,
                    constraints: BoxConstraints(maxWidth: ancho - 32),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _ColoresDelAviso.tarjeta,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _ColoresDelAviso.borde),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _ColoresDelAviso.fondoDelCheck,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: _ColoresDelAviso.check, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.titulo,
                                        style: TextStyle(
                                          fontFamily: AppFonts.ui,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: _ColoresDelAviso.titulo,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      if (widget.detalle != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.detalle!,
                                          style: TextStyle(
                                            fontFamily: AppFonts.ui,
                                            fontSize: 13,
                                            height: 1.4,
                                            color: _ColoresDelAviso.detalle,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                      if (accion != null) ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: _accion,
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                _ColoresDelAviso.check,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            minimumSize: const Size(0, 36),
                                            textStyle: const TextStyle(
                                              fontFamily: AppFonts.ui,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          child: Text(accion),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('aviso-cerrar'),
                                tooltip: tr.comunCerrar,
                                iconSize: 18,
                                color: _ColoresDelAviso.detalle,
                                onPressed: _cerrar,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        // El tiempo que le queda: una barra que se vacía.
                        AnimatedBuilder(
                          animation: _tiempo,
                          builder: (_, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 1 - _tiempo.value,
                              child: Container(
                                height: 3,
                                color: _ColoresDelAviso.check,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            child: Text(tr.comunCancelar)),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr.comunConfirmar)),
      ],
    ),
  );
  return result ?? false;
}

/// Diálogo de formulario (3+ campos: crear/editar usuario, proyecto,
/// grupo, laboratorio, quiz...) adaptado al tamaño de pantalla: en
/// compact (<600dp) ocupa toda la pantalla ([Dialog.fullscreen], ya trae
/// `resizeToAvoidBottomInset` para el teclado, cosa que ningún
/// `showDialog` suelto tenía); en medium/expanded sigue siendo el
/// `AlertDialog` centrado de siempre, solo que con
/// `ConstrainedBox(maxWidth: ...)` en vez de un ancho fijo, así sí encoge
/// en ventanas angostas de escritorio en vez de desbordar.
///
/// No reemplaza a [confirmDialog]/[confirmDoubleDialog]: esos diálogos de
/// 2-3 líneas ya caben cómodos en cualquier tamaño y no necesitan pantalla
/// completa.
///
/// [contentBuilder] arma los campos del formulario — típicamente los
/// mismos widgets que ya vivían dentro del `content:` de un `AlertDialog`,
/// sin el `SizedBox(width: N)`/`SingleChildScrollView` que ya pone este
/// helper. [actionsBuilder] arma los botones (p. ej. Cancelar/Guardar)
/// exactamente como en `AlertDialog.actions` — cada botón sigue haciendo
/// su propio `Navigator.pop(context, valor)`, así que el resultado se
/// recibe igual con `await showAdaptiveFormDialog(...)` sin importar cuál
/// de las dos variantes se mostró.
Future<T?> showAdaptiveFormDialog<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder contentBuilder,
  required List<Widget> Function(BuildContext) actionsBuilder,
  double maxWidth = 480,
}) {
  if (context.isCompact) {
    return Navigator.of(context).push<T>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: tr.comunCerrar,
            onPressed: () => Navigator.pop(routeContext),
          ),
          title: Text(title, style: const TextStyle(fontSize: 17)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: contentBuilder(routeContext),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final (i, action)
                          in actionsBuilder(routeContext).indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          // Lugar para la etiqueta flotante del primer campo: sin él,
          // el desplazamiento la recortaba («Rol» salía cortado).
          padding: const EdgeInsets.only(top: 8),
          child: contentBuilder(dialogContext)),
      ),
      actions: actionsBuilder(dialogContext),
    ),
  );
}

/// Doble verificación para acciones destructivas (eliminar usuarios,
/// mentores o cursos): además de confirmar, hay que escribir ELIMINAR (DELETE
/// en inglés).
Future<bool> confirmDoubleDialog(
    BuildContext context, String title, String message) async {
  final keyword = tr.comunPalabraEliminar;
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
              Text(
                tr.comunNoSeDeshace,
                style: TextStyle(
                    color: AppColors.statusCritical,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr.comunEscribaParaConfirmar(keyword),
                      prefixIcon: const Icon(Icons.warning_amber_rounded, size: 20),
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
              child: Text(tr.comunCancelar)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: ctrl.text.trim().toUpperCase() == keyword
                ? () => Navigator.pop(ctx, true)
                : null,
            child: Text(tr.comunEliminarDefinitivamente),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Envoltura adaptativa para un formulario con estado propio.
///
/// [showAdaptiveFormDialog] sirve cuando el contenido es un widget suelto;
/// esta sirve cuando el formulario es un `StatefulWidget` que necesita su
/// propio `setState` y sus botones tienen que ver ese estado — un guardado en
/// curso, por ejemplo. La decisión adaptativa es la misma: en compact ocupa
/// toda la pantalla (`Dialog.fullscreen`, con espacio para el teclado); en el
/// resto, un `AlertDialog` con `maxWidth` que sí encoge, no un ancho fijo que
/// desborda.
///
/// Se devuelve por `Navigator.pop` igual en los dos casos, así que quien la
/// abre no necesita saber cuál se mostró.
class AdaptiveFormShell extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxWidth;

  /// Con `true` se deshabilitan los dos botones y el de guardar dice que está
  /// trabajando. Evita el doble envío, que contra una API crea dos filas.
  final bool saving;

  /// Con `true`, salir sin guardar pide confirmación: el botón atrás de
  /// Android, el gesto de iOS, tocar fuera del diálogo, la X y "Cancelar".
  ///
  /// En el teléfono un toque accidental es mucho más probable que con el
  /// mouse, y antes cualquiera de esos caminos tiraba lo escrito sin avisar.
  final bool dirty;

  final VoidCallback onCancel;

  /// `null` deshabilita "Guardar": p. ej. mientras todavía no llegaron los
  /// datos sobre los que se va a guardar.
  final VoidCallback? onSave;
  final String? saveLabel;

  /// Rótulo del botón de salir ("Cerrar" en un quiz ya calificado).
  final String? cancelLabel;

  /// Lo que dice el botón principal mientras [saving] ("Enviando…").
  final String? savingLabel;

  const AdaptiveFormShell({
    super.key,
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onSave,
    this.maxWidth = 480,
    this.saving = false,
    this.dirty = false,
    this.saveLabel,
    this.cancelLabel,
    this.savingLabel,
  });

  Future<void> _salir(BuildContext context) async {
    if (saving) return;
    if (dirty &&
        !await confirmDialog(context, tr.formularioDescartarTitulo,
            tr.formularioDescartarTexto)) {
      return;
    }
    onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final acciones = [
      TextButton(
        onPressed: saving ? null : () => _salir(context),
        child: Text(cancelLabel ?? tr.comunCancelar),
      ),
      ElevatedButton(
        onPressed: saving ? null : onSave,
        child: Text(saving
            ? savingLabel ?? tr.comunGuardando
            : saveLabel ?? tr.comunGuardar),
      ),
    ];

    final Widget contenido;
    if (context.isCompact) {
      contenido = Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: tr.comunVolver,
                  onPressed: saving ? null : () => _salir(context),
                ),
                title: Text(title, style: const TextStyle(fontSize: 17)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // Sin sumar el teclado: `Dialog` ya se encoge por
                  // `viewInsets`. Sumarlo otra vez dejaba un hueco del alto
                  // del teclado al final del formulario.
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: child,
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                // `Wrap` y no `Row`: con un rótulo largo («Eliminar mi
                // cuenta») o la letra grande del sistema, los dos botones no
                // caben en una fila de 360 dp y el principal baja de línea en
                // vez de salirse de la pantalla.
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: acciones,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      contenido = AlertDialog(
        // Con «Atrás» a la izquierda del título, como en el teléfono
        // (recomendaciones del 20 de noviembre).
        title: TituloConAtras(
            titulo: title,
            alVolver: () {
              if (!saving) _salir(context);
            }),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
          // Lugar para la etiqueta flotante del primer campo: sin él,
          // el desplazamiento la recortaba («Rol» salía cortado).
          padding: const EdgeInsets.only(top: 8),
          child: child),
        ),
        actions: acciones,
      );
    }

    return PopScope(
      canPop: !saving && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir(context);
      },
      child: contenido,
    );
  }
}

/// Una herramienta pensada para computador, abierta en un teléfono.
///
/// El editor de la Ruta, el armado de la estructura de un curso y el contenido
/// del sitio tienen tablas, arrastrar y soltar y formularios largos que a
/// 360 dp casi no se pueden usar —y con un dedo es fácil equivocarse—. En un
/// teléfono se muestra primero este aviso; si la persona insiste, la
/// herramienta. En pantallas grandes no cambia nada.
class AvisoEscritorio extends StatefulWidget {
  /// Cómo se nombra en el aviso: "el editor de la Ruta de Impacto".
  final String herramienta;
  final Widget child;

  const AvisoEscritorio(
      {super.key, required this.herramienta, required this.child});

  @override
  State<AvisoEscritorio> createState() => _AvisoEscritorioState();
}

class _AvisoEscritorioState extends State<AvisoEscritorio> {
  bool _continuar = false;

  @override
  Widget build(BuildContext context) {
    if (!context.isCompact || _continuar) return widget.child;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_outlined,
                  size: 44, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(tr.escritorioTitulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Text(
                tr.escritorioTexto(widget.herramienta),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => setState(() => _continuar = true),
                child: Text(tr.escritorioContinuar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La grilla de tarjetas de toda la plataforma: columnas del mismo ancho y,
/// en cada fila, todas las tarjetas del MISMO alto.
///
/// Antes cada pantalla armaba su `Wrap` y cada tarjeta medía lo que pedía su
/// contenido: un curso con un título de dos líneas quedaba más alto que su
/// vecino y la fila parecía un rompecabezas (recomendaciones del 20 de
/// noviembre). Acá las columnas salen del ancho disponible y de
/// [anchoMinimo], y cada fila se mide en dos pasadas: primero cada tarjeta
/// con su alto natural, después todas con el de la más alta.
///
/// En la segunda pasada cada tarjeta recibe un alto fijo. Para llevar algo
/// al pie (un botón, el docente) sirve `MainAxisAlignment.spaceBetween` en
/// su `Column`; `Spacer` y `Expanded` no, porque en la primera pasada no hay
/// alto que repartir.
class RejillaDeTarjetas extends StatelessWidget {
  final List<Widget> children;

  /// El ancho mínimo de una tarjeta: define cuántas columnas caben.
  final double anchoMinimo;

  final double separacion;

  /// Tope de columnas, para listas que se ven mal muy angostas.
  final int? maxColumnas;

  const RejillaDeTarjetas({
    super.key,
    required this.children,
    this.anchoMinimo = 340,
    this.separacion = 20,
    this.maxColumnas,
  });

  /// Cuántas columnas caben en [ancho].
  static int columnasPara(double ancho,
      {double anchoMinimo = 340, double separacion = 20, int? maxColumnas}) {
    var n = math.max(1, ((ancho + separacion) / (anchoMinimo + separacion)).floor());
    if (maxColumnas != null) n = math.min(n, maxColumnas);
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, caja) {
      final columnas = columnasPara(caja.maxWidth,
          anchoMinimo: anchoMinimo,
          separacion: separacion,
          maxColumnas: maxColumnas);
      final filas = <Widget>[];
      for (var i = 0; i < children.length; i += columnas) {
        if (filas.isNotEmpty) filas.add(SizedBox(height: separacion));
        filas.add(FilaPareja(
          columnas: columnas,
          separacion: separacion,
          children: children.sublist(
              i, math.min(i + columnas, children.length)),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filas,
      );
    });
  }
}

/// Una fila de [RejillaDeTarjetas]: [columnas] casillas del mismo ancho, y
/// todos los hijos con el alto del más alto. Si hay menos hijos que
/// columnas, las casillas sobrantes quedan vacías (la última fila no estira
/// sus tarjetas a lo ancho).
class FilaPareja extends MultiChildRenderObjectWidget {
  final int columnas;
  final double separacion;

  const FilaPareja({
    super.key,
    required this.columnas,
    required this.separacion,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFilaPareja(columnas, separacion);

  @override
  void updateRenderObject(
      BuildContext context, RenderFilaPareja renderObject) {
    renderObject
      ..columnas = columnas
      ..separacion = separacion;
  }
}

class _DatosDeFila extends ContainerBoxParentData<RenderBox> {}

class RenderFilaPareja extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DatosDeFila>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DatosDeFila> {
  RenderFilaPareja(this._columnas, this._separacion);

  int _columnas;
  set columnas(int v) {
    if (v == _columnas) return;
    _columnas = v;
    markNeedsLayout();
  }

  double _separacion;
  set separacion(double v) {
    if (v == _separacion) return;
    _separacion = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DatosDeFila) child.parentData = _DatosDeFila();
  }

  @override
  void performLayout() {
    final ancho = constraints.maxWidth;
    final casilla = (ancho - _separacion * (_columnas - 1)) / _columnas;
    // Primera pasada: el alto natural de cada una.
    var alto = 0.0;
    var hijo = firstChild;
    while (hijo != null) {
      hijo.layout(BoxConstraints(minWidth: casilla, maxWidth: casilla),
          parentUsesSize: true);
      alto = math.max(alto, hijo.size.height);
      hijo = childAfter(hijo);
    }
    // Segunda pasada: todas con el alto de la más alta. Como MÍNIMO, no
    // exacto: con un alto exacto cada tarjeta queda aislada de la fila, y si
    // después le llega contenido (una lista que termina de cargar) crece sin
    // avisar y se desborda. Así, cualquier cambio vuelve a medir la fila.
    var x = 0.0;
    var altoFinal = 0.0;
    hijo = firstChild;
    while (hijo != null) {
      hijo.layout(
          BoxConstraints(minWidth: casilla, maxWidth: casilla, minHeight: alto),
          parentUsesSize: true);
      altoFinal = math.max(altoFinal, hijo.size.height);
      (hijo.parentData! as _DatosDeFila).offset = Offset(x, 0);
      x += casilla + _separacion;
      hijo = childAfter(hijo);
    }
    size = constraints.constrain(Size(ancho, altoFinal));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Cuántos elementos muestra una lista antes de pedir «Ver más»: la ley de
/// Miller (7 ± 2), que las recomendaciones del 20 de noviembre fijaron en 9.
const kLimiteDeMiller = 9;

/// Una lista que muestra a lo sumo [limite] elementos y, si hay más, un
/// botón «Ver más (N)» que despliega el resto (y «Ver menos» para volver).
///
/// Para listas de cosas por hacer o por mirar, donde ver 30 de golpe no
/// ayuda a nadie a decidir.
class ListaConVerMas extends StatefulWidget {
  final List<Widget> children;
  final int limite;

  /// El color del botón; por defecto el acento.
  final Color? color;

  const ListaConVerMas({
    super.key,
    required this.children,
    this.limite = kLimiteDeMiller,
    this.color,
  });

  @override
  State<ListaConVerMas> createState() => _ListaConVerMasState();
}

class _ListaConVerMasState extends State<ListaConVerMas> {
  bool _todo = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length;
    final sobran = total - widget.limite;
    final visibles =
        _todo || sobran <= 0 ? widget.children : widget.children.take(widget.limite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibles,
        if (sobran > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('ver-mas'),
              style: TextButton.styleFrom(
                  foregroundColor: widget.color ?? AppColors.gold),
              onPressed: () => setState(() => _todo = !_todo),
              icon: Icon(_todo ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_todo ? tr.comunVerMenos : tr.comunVerMasN(sobran)),
            ),
          ),
      ],
    );
  }
}

/// Una foto que, al tocarla, se abre a pantalla completa sobre un fondo
/// negro: se puede acercar con dos dedos o la rueda, y se cierra con la X,
/// con Esc o tocando fuera de la foto.
class FotoAmpliable extends StatelessWidget {
  final ImageProvider imagen;
  final Widget child;

  /// Lo que dice el lector de pantalla del botón.
  final String? descripcion;

  const FotoAmpliable({
    super.key,
    required this.imagen,
    required this.child,
    this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: descripcion ?? tr.comunAmpliarFoto,
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: GestureDetector(
          onTap: () => mostrarFotoCompleta(context, imagen),
          child: child,
        ),
      ),
    );
  }
}

/// Abre [imagen] a pantalla completa. Ver [FotoAmpliable].
Future<void> mostrarFotoCompleta(BuildContext context, ImageProvider imagen) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tr.comunCerrar,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Tocar el fondo cierra; tocar la foto no.
              onTap: () => Navigator.of(ctx).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Image(
                  key: const ValueKey('foto-completa'),
                  image: imagen,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filled(
              tooltip: tr.comunCerrar,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Botones de página: «‹ 1 2 3 … 9 ›». Muestra la primera, la última y las
/// vecinas de la actual; lo demás, con «…».
class Paginador extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final ValueChanged<int> alCambiar;

  const Paginador({
    super.key,
    required this.pagina,
    required this.totalPaginas,
    required this.alCambiar,
  });

  /// Las páginas a mostrar; `null` es un «…».
  static List<int?> paginasVisibles(int actual, int total) {
    if (total <= 7) return [for (var i = 1; i <= total; i++) i];
    final cerca = {1, total, actual - 1, actual, actual + 1}
        .where((p) => p >= 1 && p <= total)
        .toList()
      ..sort();
    final salida = <int?>[];
    for (final p in cerca) {
      if (salida.isNotEmpty && p - (salida.last ?? p) > 1) salida.add(null);
      salida.add(p);
    }
    return salida;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1) return const SizedBox.shrink();
    Widget boton(int p) {
      final actual = p == pagina;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          button: true,
          selected: actual,
          label: tr.comunPaginaN(p),
          child: SizedBox(
            width: 40,
            height: 40,
            child: TextButton(
              key: ValueKey('pagina-$p'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: actual ? AppColors.relleno : null,
                foregroundColor: actual ? AppColors.ink : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: actual ? null : () => alCambiar(p),
              child: Text('$p',
                  style: TextStyle(
                      fontWeight: actual ? FontWeight.w800 : FontWeight.w500,
                      color: actual ? AppColors.ink : null)),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        IconButton(
          tooltip: tr.comunPaginaAnterior,
          onPressed: pagina > 1 ? () => alCambiar(pagina - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (final p in paginasVisibles(pagina, totalPaginas))
          p == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('…', style: TextStyle(color: AppColors.textMuted)),
                )
              : boton(p),
        IconButton(
          tooltip: tr.comunPaginaSiguiente,
          onPressed:
              pagina < totalPaginas ? () => alCambiar(pagina + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// El título de un diálogo con la flecha «Atrás» a su izquierda.
class TituloConAtras extends StatelessWidget {
  final String titulo;

  /// Por defecto, cierra el diálogo.
  final VoidCallback? alVolver;

  const TituloConAtras({
    super.key,
    required this.titulo,
    this.alVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('dialogo-atras'),
          tooltip: tr.comunVolver,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: alVolver ?? () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18))),
      ],
    );
  }
}

/// Una tarjeta de resumen de un panel: título con ícono, unas pocas filas y,
/// si no hay nada, una frase. Para los paneles de asesor, empresa y mentor
/// (2026-11-23): llenan lo que antes era pantalla vacía con lo que esa
/// persona necesita mirar.
class TarjetaDeResumen extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> filas;
  final String vacio;

  const TarjetaDeResumen({
    super.key,
    required this.titulo,
    required this.icono,
    required this.filas,
    required this.vacio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(vacio,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            )
          else
            ...filas,
        ],
      ),
    );
  }
}

/// Una fila de [TarjetaDeResumen]: lo principal, un detalle chico y, a la
/// derecha, un valor o una barra.
class FilaDeResumen extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final Widget? derecha;
  final VoidCallback? alTocar;

  const FilaDeResumen({
    super.key,
    required this.titulo,
    this.detalle,
    this.derecha,
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final fila = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (detalle != null && detalle!.isNotEmpty)
                  Text(detalle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (derecha != null) ...[const SizedBox(width: 12), derecha!],
        ],
      ),
    );
    if (alTocar == null) return fila;
    return InkWell(
        borderRadius: BorderRadius.circular(8), onTap: alTocar, child: fila);
  }
}
