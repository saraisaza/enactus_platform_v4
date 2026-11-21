import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../utils/app_theme.dart';
import '../utils/marca.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import 'app_footer.dart';
import 'app_header.dart';
import 'cuenta.dart';
import '../utils/tema.dart';

/// Ítem del menú lateral de un portal.
class PortalTab {
  /// Identificador fijo, para abrir esta pestaña desde una ruta
  /// (`/estudiante/laboratorios`). No se usa [label] porque el rótulo cambia
  /// con el idioma.
  final String? id;

  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  /// Rótulo para la barra inferior del teléfono, donde cada destino tiene
  /// ~72 dp ("Ruta" en vez de "Ruta de Impacto"). Si es `null`, [label].
  final String? shortLabel;

  /// Va en la barra inferior del teléfono. Caben 4; el resto queda en "Más".
  /// La barra lateral de la web no cambia.
  final bool destacada;

  const PortalTab({
    this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.shortLabel,
    this.destacada = false,
  });
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

  const PortalShell({
    super.key,
    required this.portalTitle,
    required this.tabs,
    this.initialSelectedIndex = 0,
    this.contentOverride,
  });

  @override
  State<PortalShell> createState() => _PortalShellState();

  /// Abre la pestaña [id] del portal que contiene a [context], como si se
  /// la hubiera elegido en el menú. Para los accesos directos dentro del
  /// contenido («Ver calendario» en el inicio). Devuelve `false` si no hay
  /// portal o no tiene esa pestaña.
  static bool irAPestana(BuildContext context, String id) {
    final estado = context.findAncestorStateOfType<_PortalShellState>();
    if (estado == null) return false;
    final i = estado.widget.tabs.indexWhere((t) => t.id == id);
    if (i < 0) return false;
    estado._selectTab(i);
    return true;
  }

  /// [PortalTab.id] del calendario, igual en todos los portales.
  static const pestanaCalendario = 'calendario';
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  bool get _overrideActivo =>
      widget.contentOverride != null && !_overrideDismissed;

  /// Destinos principales para la barra inferior del teléfono: los marcados
  /// como [PortalTab.destacada] (o los primeros, si ninguno lo está). Material
  /// 3 recomienda entre 3 y 5; con más pestañas, 4 y "Más".
  List<int> get _enBarra {
    final tabs = widget.tabs;
    if (tabs.length <= 5) return [for (var i = 0; i < tabs.length; i++) i];
    final marcadas = [
      for (var i = 0; i < tabs.length; i++)
        if (tabs[i].destacada) i,
    ];
    return (marcadas.isEmpty ? [0, 1, 2, 3] : marcadas).take(4).toList();
  }

  bool get _hayMas => widget.tabs.length > _enBarra.length;

  /// Atrás de Android dentro de un portal: primero cierra el menú, después
  /// cierra un detalle abierto dentro de la pestaña, después vuelve a la
  /// primera pestaña (la convención de Android para los destinos
  /// principales) y recién ahí sale de la app. Antes salía de la app de una.
  ///
  /// En la web no se intercepta nada: el botón del navegador sigue igual.
  bool get _puedeSalir =>
      kIsWeb || (!_drawerOpen && !_overrideActivo && _selected == 0);

  void _alPedirAtras(bool didPop, Object? _) {
    if (didPop) return;
    if (_drawerOpen) {
      _scaffoldKey.currentState?.closeDrawer();
    } else if (_overrideActivo) {
      setState(() => _overrideDismissed = true);
    } else if (_selected != 0) {
      _selectTab(0);
    }
  }

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
    //
    // La `Key` de afuera es para las pruebas y vale la pena explicarla: sin
    // ella, "la pestaña dibujó algo" solo se podía comprobar contando textos
    // de TODA la pantalla — y el encabezado, la barra lateral y el pie ya
    // aportan varias decenas. Una pestaña entera podía quedar en blanco sin
    // que ninguna prueba lo notara (auditoría de pruebas, mutación F2). Con
    // esta llave el cuerpo de la pestaña se mira solo.
    final content = KeyedSubtree(
      key: const Key('portal-content'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(
            widget.contentOverride != null && !_overrideDismissed
                ? 'override-$_selected'
                : _selected,
          ),
          child: (widget.contentOverride != null && !_overrideDismissed)
              ? widget.contentOverride!
              : widget.tabs[_selected].builder(context),
        ),
      ),
    );

    return PopScope(
      canPop: _puedeSalir,
      onPopInvokedWithResult: _alPedirAtras,
      child: Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (abierto) => setState(() => _drawerOpen = abierto),
      // Compact no tiene espacio para una barra lateral permanente (ni
      // siquiera de 64px solo-íconos): los destinos principales van en una
      // barra inferior y el resto en un Drawer que abre "Más".
      drawer: compact && _hayMas ? _buildDrawer() : null,
      bottomNavigationBar: compact ? _barraInferior() : null,
      body: Column(
        children: [
          AppHeader(portalTitle: widget.portalTitle),
          Expanded(
            child: compact
                ? content
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Barra lateral. En pantallas anchas se puede plegar a
                      // solo íconos para darle el espacio al contenido; la
                      // elección dura toda la sesión, en todos los portales.
                      _barraLateral(angosta: !wide || _plegado, plegable: wide),
                      Expanded(child: content),
                    ],
                  ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _barraInferior() {
    final enBarra = _enBarra;
    final posicion = enBarra.indexOf(_selected);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.barraLateral,
        // La opción activa va con el secundario de la marca.
        indicatorColor: AppColors.secundario,
        labelTextStyle: WidgetStateProperty.resolveWith((estados) => TextStyle(
              fontSize: 11.5,
              fontWeight: estados.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: estados.contains(WidgetState.selected)
                  ? AppColors.secundarioTinta
                  : AppColors.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((estados) => IconThemeData(
              color: estados.contains(WidgetState.selected)
                  ? inkSobre(AppColors.secundario)
                  : AppColors.textSecondary,
            )),
      ),
      child: NavigationBar(
        // Una pestaña que no está en la barra (vive en "Más") marca "Más".
        selectedIndex: posicion >= 0 ? posicion : enBarra.length,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == enBarra.length) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            _selectTab(enBarra[i]);
          }
        },
        destinations: [
          for (final i in enBarra)
            NavigationDestination(
              icon: Icon(widget.tabs[i].icon),
              label: widget.tabs[i].shortLabel ?? widget.tabs[i].label,
              tooltip: widget.tabs[i].label,
            ),
          if (_hayMas)
            NavigationDestination(
              icon: Icon(Icons.menu),
              label: tr.portalMas,
              tooltip: tr.portalMasOpciones,
            ),
        ],
      ),
    );
  }

  /// Si la persona plegó el menú lateral. Estático: se conserva al pasar de
  /// una pantalla a otra (cada detalle arma su propio [PortalShell]).
  static bool _menuPlegado = false;
  bool get _plegado => _menuPlegado;

  Widget _barraLateral({required bool angosta, required bool plegable}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: angosta ? 64 : 230,
      decoration: BoxDecoration(
        color: AppColors.barraLateral,
        // En claro, el menú es blanco como las tarjetas: una línea lo separa
        // del fondo de la página.
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plegable)
            Align(
              alignment: angosta ? Alignment.center : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: IconButton(
                  key: const Key('plegar-menu'),
                  tooltip: angosta ? tr.portalDesplegarMenu : tr.portalPlegarMenu,
                  color: AppColors.textSecondary,
                  hoverColor: AppColors.velo(0.06),
                  icon: Icon(angosta
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded),
                  onPressed: () =>
                      setState(() => _menuPlegado = !_menuPlegado),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: plegable ? 4 : 12),
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  _SidebarItem(
                    tab: widget.tabs[i],
                    selected: i == _selected,
                    compact: angosta,
                    onTap: () => _selectTab(i),
                  ),
              ],
            ),
          ),
          // «Cerrar sesión» al pie del menú, donde se busca. Sigue también en
          // el menú de la cuenta.
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _SidebarItem.cerrarSesion(compact: angosta),
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
      backgroundColor: AppColors.barraLateral,
      child: SafeArea(
        child: Builder(
          builder: (drawerContext) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Text(
                  widget.portalTitle.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
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
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              _SidebarItem.cerrarSesion(compact: false),
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
  final VoidCallback? onTap;

  /// En rojo: «Cerrar sesión».
  final bool peligro;

  const _SidebarItem({
    required this.tab,
    required this.selected,
    required this.compact,
    required this.onTap,
  }) : peligro = false;

  /// «Cerrar sesión», al pie del menú lateral y del cajón del teléfono.
  _SidebarItem.cerrarSesion({required this.compact})
      : tab = PortalTab(
          id: 'cerrar-sesion',
          label: tr.comunCerrarSesion,
          icon: Icons.logout_rounded,
          builder: (_) => const SizedBox.shrink(),
        ),
        selected = false,
        onTap = null,
        peligro = true;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    // La opción activa va con el secundario de la marca. Con la marca de un
    // cliente, en pleno —relleno del secundario, borde del primario—: es lo
    // que más se ve de su identidad mientras se navega.
    final deCliente = Marca.instancia.paleta.esDeCliente;
    final color = widget.peligro
        ? AppColors.statusCritical
        : active
            ? (deCliente ? AppColors.sobreSecundario : AppColors.secundarioTinta)
            : (_hover ? AppColors.textPrimary : AppColors.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () => cerrarSesion(context),
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
                ? (deCliente
                    ? AppColors.secundario
                    : AppColors.secundario.withValues(alpha: 0.12))
                : (_hover ? AppColors.velo(0.05) : null),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: active
                    ? (deCliente ? AppColors.relleno : AppColors.secundario)
                    : (_hover
                          ? AppColors.gold.withValues(alpha: 0.55)
                          : Colors.transparent),
                width: 3,
              ),
            ),
          ),
          child: widget.compact
              ? Tooltip(
                  message: widget.tab.label,
                  child: Icon(widget.tab.icon, color: color, size: 22),
                )
              // Mientras el menú se despliega el ancho crece de a poco: el
              // rótulo aparece solo cuando ya cabe al lado del ícono.
              : LayoutBuilder(
                  builder: (context, caja) => caja.maxWidth < 72
                      ? Icon(widget.tab.icon, color: color, size: 20)
                      : Row(
                          children: [
                            Icon(widget.tab.icon, color: color, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.tab.label,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
  const TabBody({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // En el teléfono, título, bajada y botones centrados
    // (recomendaciones del 20 de noviembre).
    final centrar = context.isCompact;
    final titleBlock = Column(
      crossAxisAlignment:
          centrar ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          textAlign: centrar ? TextAlign.center : TextAlign.start,
          style: displayHeading(
            fontSize: 30,
            fontWeight: AppWeights.display,
            color: AppColors.gold,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              subtitle!,
              textAlign: centrar ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
    // En compact, título y acciones compartiendo la misma fila aprietan
    // tanto la columna del título (Knockout 30px) que llega a partir
    // palabras a la mitad — se apilan en vez de compartir fila. Sin
    // acciones no hay nada que lo apriete, así que ahí se conserva el
    // mismo Row de siempre en cualquier ancho.
    final header = centrar
        ? SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions),
                ],
              ],
            ),
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
    //
    // Deslizar hacia abajo vuelve a pedir lo que muestra la pestaña: en el
    // teléfono es el gesto que todos esperan, y antes no había ninguna forma
    // de actualizar sin cerrar sesión. `AlwaysScrollable` para que funcione
    // también cuando el contenido es más corto que la pantalla.
    return RefreshIndicator.adaptive(
      onRefresh: () => context.read<DataProvider>().refreshAll(),
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 20), ...children],
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
}

/// Contenedor de pantalla con tema claro/oscuro propio (el header y la
/// barra lateral del portal — [PortalShell] — siguen oscuros siempre: el
/// wordmark de eduXaction es blanco). Reproduce el patrón repetido en las 5
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
  final Widget Function(
    BuildContext context,
    ContentColors colors,
    bool isDark,
  )?
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
  bool get _isDark => Tema.oscuro;
  final _searchCtrl = TextEditingController();
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(
      // En la app el punto pulsa dos veces y se queda quieto: una animación
      // sin fin en cada pantalla de contenido gasta batería sin decir nada
      // nuevo. En la web, como siempre.
      count: kIsWeb ? null : 2,
    );

  ContentColors get _colors =>
      _isDark ? ContentColors.dark : ContentColors.light;

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
      // Deslizar para actualizar, igual que en [TabBody].
      child: RefreshIndicator.adaptive(
        onRefresh: () => context.read<DataProvider>().refreshAll(),
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.isCompact ? 16 : 40,
                24,
                context.isCompact ? 16 : 40,
                60,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El botón de tema se fue al encabezado: esta fila solo
                  // existe si hay buscador. Sin él, el título sube y no queda
                  // una franja vacía arriba.
                  if (_hayBuscador) ...[
                    _buildControlsRow(colors),
                    const SizedBox(height: 22),
                  ],
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
      ),
    );
  }

  /// Un buscador que no filtra nada solo ocupa espacio: se muestra
  /// únicamente si busca de verdad.
  bool get _hayBuscador =>
      widget.searchHint != null && widget.onSearchChanged != null;

  Widget _buildControlsRow(ContentColors colors) {
    // `mainAxisAlignment.end` en vez de un `Spacer`, y el buscador en
    // `Flexible`: con `Spacer` el hueco se come todo el espacio libre y el
    // buscador de 320px queda pidiendo su ancho fijo, que en un teléfono no
    // entra junto al botón de tema.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // En el teléfono, un buscador que no filtra nada solo ocupa espacio
        // y abre el teclado en vano: se muestra únicamente si busca. En
        // escritorio se conserva por consistencia del diseño de la cabecera.
        if (_hayBuscador) ...[
          Flexible(
            child: ConstrainedBox(
              // Antes 320px fijos: con el relleno lateral no entraba en un
              // teléfono y desbordaba la fila entera.
              constraints: const BoxConstraints(maxWidth: 320),
              // 48 dp: la altura mínima tocable en el teléfono.
              child: Container(
                height: 48,
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
                        textInputAction: TextInputAction.search,
                        style: TextStyle(fontSize: 14, color: colors.text),
                        decoration: InputDecoration(
                          isDense: true,
                          // El campo ocupa todo el alto de la caja: antes
                          // medía 29 dp y había que acertarle al texto.
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: widget.searchHint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.text3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(ContentColors colors) {
    // A todo el ancho: sin esto el `Wrap` medía lo que su contenido y lo de
    // la derecha (el anillo de avance del inicio) quedaba en el medio, con
    // un hueco muerto a su derecha.
    return SizedBox(
      width: double.infinity,
      child: _cabecera(colors),
    );
  }

  Widget _cabecera(ContentColors colors) {
    // En el teléfono, todo centrado (recomendaciones del 20 de noviembre).
    final centrar = context.isCompact;
    return Wrap(
      alignment:
          centrar ? WrapAlignment.center : WrapAlignment.spaceBetween,
      crossAxisAlignment:
          centrar ? WrapCrossAlignment.center : WrapCrossAlignment.end,
      spacing: 32,
      runSpacing: 20,
      children: [
        ConstrainedBox(
          // Sin `minWidth`: un mínimo más ancho que un teléfono no lo puede
          // rescatar ningún padre — es el desbordamiento garantizado.
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: centrar
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, _) {
                      final t = _glow.value;
                      return Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(
                                alpha: 0.55 * (1 - t),
                              ),
                              spreadRadius: 5 * t,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 9),
                  // `Flexible`: el rótulo suele ser una fecha larga
                  // ("SEMANA DEL 25 DE AGO AL 31 DE AGO") y dentro de un `Row`
                  // sin flex exige su ancho intrínseco, que en un teléfono no
                  // existe.
                  Flexible(
                    child: Text(
                      widget.eyebrow.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 12 * 0.16,
                        fontWeight: FontWeight.w600,
                        color: colors.text3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                // 58 px es un título de escritorio. A 390 px "LABORATORIOS"
                // —una sola palabra de 12 letras— no entra y se parte en
                // "LABORATORIO / S", que es peor que cualquier salto de
                // línea: rompe la palabra.
                final size = context.isCompact ? 38.0 : 58.0;
                return Text(
                  widget.title.toUpperCase(),
                  textAlign: centrar ? TextAlign.center : TextAlign.start,
                  style: displayHeading(
                    fontSize: size,
                    color: colors.goldInk,
                    height: 1.00,
                    letterSpacing: size * 0.004,
                  ),
                );
              }),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.subtitle!,
                  textAlign: centrar ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: colors.text2,
                    height: 1.4,
                  ),
                ),
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

  const StageRail({
    super.key,
    required this.accentColor,
    required this.colors,
    required this.currentIndex,
    this.totalOverride,
    this.caption,
  });

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
        // Las dos leyendas van en `Flexible`: "Sigue: Validación de mercado"
        // pide su ancho natural y el riel vive dentro de una tarjeta de
        // grilla, que en pantallas angostas es más estrecha que la suma de
        // los dos textos. Sin flex, el `Row` desborda — se veía en el
        // Directorio de Proyectos con las tarjetas a un ancho normal.
        caption ??
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    tr.etapaDeTotal(currentIndex + 1, total),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: colors.text3),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    currentIndex >= total - 1
                        ? tr.etapaFinal
                        : tr.etapaSigue(ProjectStage.label(projectStages[currentIndex + 1])),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: colors.text3),
                  ),
                ),
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
