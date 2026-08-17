import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import 'app_footer.dart';
import 'app_header.dart';
import 'common.dart';

/// Ítem del menú lateral de un portal.
class PortalTab {
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  const PortalTab(
      {required this.label, required this.icon, required this.builder});
}

/// Estructura común de todos los portales: header, barra lateral con
/// pestañas, área de contenido y footer institucional.
class PortalShell extends StatefulWidget {
  final String portalTitle;
  final List<PortalTab> tabs;

  /// Pestaña resaltada al montar. Por defecto la primera — todos los
  /// portales existentes se comportan exactamente igual que antes.
  final int initialSelectedIndex;

  /// Si no es null, reemplaza el contenido de la pestaña seleccionada sin
  /// cambiar cuál queda resaltada en la barra lateral — así una pantalla
  /// de detalle (p. ej. el detalle de un laboratorio) puede vivir "dentro"
  /// de su pestaña sin duplicar el header ni la barra lateral.
  final Widget? contentOverride;

  const PortalShell(
      {super.key,
      required this.portalTitle,
      required this.tabs,
      this.initialSelectedIndex = 0,
      this.contentOverride});

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  late int _selected = widget.initialSelectedIndex;

  /// Si `contentOverride` llegó activo (deep link a un detalle), se
  /// respeta hasta que el usuario toque explícitamente una pestaña de la
  /// barra lateral — a partir de ahí la navegación vuelve a ser normal
  /// para el resto de la vida de esta pantalla. Sin esto, `contentOverride`
  /// (una prop inmutable del padre) se seguía mostrando encima de
  /// cualquier pestaña nueva, dejando la barra lateral sin efecto.
  late bool _overrideDismissed = widget.contentOverride == null;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final compact = breakpoint == AppBreakpoint.compact;
    // "wide" conserva el nombre/comportamiento de siempre (sidebar de
    // 230px con texto vs. 64px solo íconos) — antes cortaba en 900px con
    // un solo umbral; ahora es exactamente "expanded" de Material 3
    // (≥840px), y "medium" (600-839) sigue recibiendo el mismo riel de
    // 64px de siempre, ya que ese caso no cambia de fondo.
    final wide = breakpoint == AppBreakpoint.expanded;

    // El footer vive dentro del scroll de cada pestaña: solo aparece al
    // desplazarse hasta el final.
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(widget.contentOverride != null && !_overrideDismissed
            ? 'override-$_selected'
            : _selected),
        child: (widget.contentOverride != null && !_overrideDismissed)
            ? widget.contentOverride!
            : widget.tabs[_selected].builder(context),
      ),
    );

    return Scaffold(
      // Compact no tiene espacio para una barra lateral permanente (ni
      // siquiera de 64px solo-íconos) — la navegación pasa a un Drawer
      // activado desde el ícono de menú de AppHeader.
      drawer: compact ? _buildDrawer() : null,
      body: Column(
        children: [
          AppHeader(portalTitle: widget.portalTitle, showMenuButton: compact),
          Expanded(
            child: compact
                ? content
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Barra lateral
                      Container(
                        width: wide ? 230 : 64,
                        color: AppColors.slate,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            for (var i = 0; i < widget.tabs.length; i++)
                              _SidebarItem(
                                tab: widget.tabs[i],
                                selected: i == _selected,
                                compact: !wide,
                                onTap: () => _selectTab(i),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int i) {
    setState(() {
      _selected = i;
      _overrideDismissed = true;
    });
  }

  /// Mismas pestañas que la barra lateral, en un `Drawer` a ancho completo
  /// para compact. `Builder` da un context propio, ya descendiente del
  /// `Drawer`, para poder cerrarlo con `Navigator.pop` al elegir una
  /// pestaña (el context de `_PortalShellState.build` está por encima del
  /// `Scaffold`/`Drawer`, no sirve para eso).
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.slate,
      child: SafeArea(
        child: Builder(
          builder: (drawerContext) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Text(widget.portalTitle.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1)),
              ),
              for (var i = 0; i < widget.tabs.length; i++)
                _SidebarItem(
                  tab: widget.tabs[i],
                  selected: i == _selected,
                  compact: false,
                  onTap: () {
                    Navigator.pop(drawerContext);
                    _selectTab(i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final PortalTab tab;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.tab,
      required this.selected,
      required this.compact,
      required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final color = active
        ? AppColors.gold
        : (_hover ? AppColors.textPrimary : AppColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          // vertical:14 (no 12) para que el área táctil real — el padding
          // queda dentro del BoxDecoration, que sí es lo que hit-testea —
          // alcance el mínimo de 48dp: 14+22+14=50 en modo ícono,
          // 14+20+14=48 en modo ícono+texto.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: active
                ? AppColors.gold.withValues(alpha: 0.12)
                : (_hover ? Colors.white.withValues(alpha: 0.05) : null),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                  color: active
                      ? AppColors.gold
                      : (_hover
                          ? AppColors.gold.withValues(alpha: 0.55)
                          : Colors.transparent),
                  width: 3),
            ),
          ),
          child: widget.compact
              ? Tooltip(
                  message: widget.tab.label,
                  child: Icon(widget.tab.icon, color: color, size: 22))
              : Row(
                  children: [
                    Icon(widget.tab.icon, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.tab.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Contenedor estándar del contenido de una pestaña.
class TabBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  const TabBody(
      {super.key,
      required this.title,
      this.subtitle,
      required this.children,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: knockoutHeading(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.gold)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
      ],
    );
    // En compact, título y acciones compartiendo la misma fila aprietan
    // tanto la columna del título (Knockout 30px) que llega a partir
    // palabras a la mitad — se apilan en vez de compartir fila. Sin
    // acciones no hay nada que lo apriete, así que ahí se conserva el
    // mismo Row de siempre en cualquier ancho.
    final header = context.isCompact && actions.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          )
        : Row(
            children: [
              Expanded(child: titleBlock),
              ...actions,
            ],
          );
    // El footer va al final del scroll: no ocupa pantalla hasta que el
    // usuario baja del todo. Si el contenido es corto, SliverFillRemaining
    // lo ancla al borde inferior del viewport.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AppFooter(),
          ),
        ),
      ],
    );
  }
}

/// Contenedor de pantalla con tema claro/oscuro propio (el header y la
/// barra lateral del portal — [PortalShell] — siguen oscuros siempre: el
/// logo de Enactus es blanco). Reproduce el patrón repetido en las 5
/// pantallas rediseñadas del portal estudiante
/// (`design_handoff_portal_estudiante/README.md`): fondo `colors.bg`,
/// buscador opcional + botón de tema, encabezado (punto con "glow" +
/// eyebrow + título Knockout 58px + bajada) y `AppFooter` anclado al fondo
/// del scroll. [trailingBuilder] arma lo que va a la derecha del
/// encabezado (tarjetas de estadística, tarjeta de progreso, leyenda…);
/// [bodyBuilder] arma el resto del contenido, ya con [ContentColors] y
/// `isDark` a mano.
class ContentScreenShell extends StatefulWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  /// `null` = sin buscador. El README solo define comportamiento de filtro
  /// para Mis Cursos y Directorio — en las demás pantallas se muestra por
  /// consistencia de la cabecera sin acción de filtro.
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final Widget Function(BuildContext context, ContentColors colors, bool isDark)?
      trailingBuilder;
  final Widget Function(BuildContext context, ContentColors colors, bool isDark)
      bodyBuilder;

  const ContentScreenShell({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.searchHint,
    this.onSearchChanged,
    this.trailingBuilder,
    required this.bodyBuilder,
  });

  @override
  State<ContentScreenShell> createState() => _ContentScreenShellState();
}

class _ContentScreenShellState extends State<ContentScreenShell>
    with SingleTickerProviderStateMixin {
  bool _isDark = true;
  final _searchCtrl = TextEditingController();
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  ContentColors get _colors => _isDark ? ContentColors.dark : ContentColors.light;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 34, 40, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControlsRow(colors),
                  const SizedBox(height: 22),
                  _buildHeader(colors),
                  const SizedBox(height: 26),
                  widget.bodyBuilder(context, colors, _isDark),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(ContentColors colors) {
    return Row(
      children: [
        const Spacer(),
        if (widget.searchHint != null) ...[
          Container(
            width: 320,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: colors.text3),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: widget.onSearchChanged,
                    style: TextStyle(fontSize: 14, color: colors.text),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(fontSize: 14, color: colors.text3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        _ContentThemeToggleButton(
          isDark: _isDark,
          colors: colors,
          onTap: () => setState(() => _isDark = !_isDark),
        ),
      ],
    );
  }

  Widget _buildHeader(ContentColors colors) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 32,
      runSpacing: 20,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, __) {
                      final t = _glow.value;
                      return Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C9F38),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4C9F38)
                                  .withValues(alpha: 0.55 * (1 - t)),
                              spreadRadius: 5 * t,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 9),
                  Text(widget.eyebrow.toUpperCase(),
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 12 * 0.16,
                          fontWeight: FontWeight.w600,
                          color: colors.text3)),
                ],
              ),
              const SizedBox(height: 10),
              Text(widget.title.toUpperCase(),
                  style: knockoutHeading(
                      fontSize: 58,
                      fontWeight: FontWeight.w800,
                      color: colors.goldInk,
                      height: 0.94)),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(widget.subtitle!,
                    style: TextStyle(
                        fontSize: 15.5, color: colors.text2, height: 1.4)),
              ],
            ],
          ),
        ),
        if (widget.trailingBuilder != null)
          widget.trailingBuilder!(context, colors, _isDark),
      ],
    );
  }
}

class _ContentThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ContentThemeToggleButton(
      {required this.isDark, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? AppColors.gold : colors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
            color: hover ? AppColors.gold : colors.text2,
          ),
        ),
      ),
    );
  }
}

/// Riel de 6 etapas (Ideación → National Expo): segmentos superados en
/// `colors.goldSoft`, la etapa actual con [accentColor] (color del ODS
/// principal del proyecto o del laboratorio, según la pantalla), futuras en
/// `colors.border`. Compartido por la tarjeta "Tu proyecto" del Dashboard y
/// las tarjetas del Directorio de Proyectos.
class StageRail extends StatelessWidget {
  final Color accentColor;
  final ContentColors colors;
  final int currentIndex;

  /// Número de segmentos. Por defecto las 6 etapas de un proyecto
  /// (`projectStages`) — la Ruta de Impacto de un laboratorio pasa el
  /// número real de sus fases en su lugar, con [caption] propio (sus
  /// fases no tienen nombre fijo como "Ideación"/"Piloto").
  final int? totalOverride;

  /// Reemplaza la leyenda por defecto ("Etapa N de M" / "Sigue: `<etapa>`")
  /// cuando el texto de `projectStages` no aplica.
  final Widget? caption;

  const StageRail(
      {super.key,
      required this.accentColor,
      required this.colors,
      required this.currentIndex,
      this.totalOverride,
      this.caption});

  @override
  Widget build(BuildContext context) {
    final total = totalOverride ?? projectStages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < currentIndex
                        ? colors.goldSoft
                        : (i == currentIndex ? accentColor : colors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        caption ??
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Etapa ${currentIndex + 1} de $total',
                    style: TextStyle(fontSize: 11.5, color: colors.text3)),
                Text(
                    currentIndex >= total - 1
                        ? 'Etapa final'
                        : 'Sigue: ${projectStages[currentIndex + 1]}',
                    style: TextStyle(fontSize: 11.5, color: colors.text3)),
              ],
            ),
      ],
    );
  }
}

/// Rayas diagonales `repeating-linear-gradient(115deg, rgba(255,255,255,.14)
/// 0 2px, transparent 2px 13px)` del handoff: patrón de textura sobre
/// cabeceras de color plano (portada de proyecto en el Directorio, cabecera
/// de curso en Mis Cursos, cabecera de "Continúa donde ibas" en el
/// Dashboard) — Flutter no lo trae de fábrica.
class StripePainter extends CustomPainter {
  const StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-25 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    final diag = size.width + size.height;
    for (double x = -diag; x < diag; x += 13) {
      canvas.drawLine(Offset(x, -diag), Offset(x, diag * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
