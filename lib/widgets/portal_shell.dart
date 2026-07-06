import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'app_footer.dart';
import 'app_header.dart';

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
  const PortalShell({super.key, required this.portalTitle, required this.tabs});

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: widget.portalTitle),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra lateral
                Container(
                  width: isWide ? 230 : 64,
                  color: AppColors.slate,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        _SidebarItem(
                          tab: widget.tabs[i],
                          selected: i == _selected,
                          compact: !isWide,
                          onTap: () => setState(() => _selected = i),
                        ),
                    ],
                  ),
                ),
                // Contenido (el footer vive dentro del scroll de cada
                // pestaña: solo aparece al desplazarse hasta el final)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_selected),
                      child: widget.tabs[_selected].builder(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold)),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(subtitle!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
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
