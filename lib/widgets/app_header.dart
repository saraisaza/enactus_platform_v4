import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import 'animated_logo.dart';
import 'common.dart';

/// Header con logo, buscador global, campana de notificaciones y avatar
/// con menú desplegable. En compact (<600dp) se reduce de alto, oculta el
/// chip de portal, colapsa el buscador a un ícono de pantalla completa y
/// quita el nombre/rol en línea del avatar — ver [ResponsiveContext].
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Título opcional del portal (p. ej. "Portal Estudiante").
  final String? portalTitle;

  /// Si `true`, en compact muestra un ícono de menú que abre el `Drawer`
  /// del `Scaffold` ancestro más cercano (solo [PortalShell] lo pasa: es
  /// el único que arma un `Drawer` de navegación compact).
  final bool showMenuButton;

  const AppHeader({super.key, this.portalTitle, this.showMenuButton = false});

  static const _flagBarHeight = 4.0;

  @override
  Size get preferredSize => const Size.fromHeight(160 + _flagBarHeight);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final compact = context.isCompact;
    // El buscador en línea (240-340px) y el chip de portal solo caben
    // cómodos a partir de expanded — a 768px (medium) esta fila, con todo
    // lo demás ya puesto (logo + chip + buscador + campana + avatar con
    // nombre), desborda por un margen real (~46px), no solo en compact.
    final roomy = context.isExpanded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ColombiaFlagBar(height: _flagBarHeight),
        Container(
          height: compact ? 64 : 160,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (showMenuButton && compact)
                IconButton(
                  icon: const Icon(Icons.menu),
                  color: AppColors.textPrimary,
                  tooltip: 'Menú',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              AnimatedLogo(
                height: compact ? 34 : 135,
                onTap: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false),
              ),
              if (!compact && roomy) ...[
                const SizedBox(width: 16),
                if (portalTitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.slate,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(portalTitle!,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
              ],
              const Spacer(),
              if (user != null) ...[
                if (roomy) ...[
                  const _GlobalSearch(),
                  const SizedBox(width: 12),
                ] else
                  IconButton(
                    icon: const Icon(Icons.search),
                    color: AppColors.textSecondary,
                    tooltip: 'Buscar',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const _CompactSearchScreen())),
                  ),
                _NotificationBell(userId: user.id),
                SizedBox(width: compact ? 4 : 10),
                _AvatarMenu(user: user),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buscador global: se expande al enfocar y sugiere estudiantes, cursos,
// proyectos, universidades y empresas al instante.
// ---------------------------------------------------------------------------

class _SearchHit {
  final String type;
  final String name;
  final String sub;
  final IconData icon;
  const _SearchHit(this.type, this.name, this.sub, this.icon);

  @override
  String toString() => name;
}

/// Búsqueda global por estudiantes/alumni, LXD, mentores, cursos,
/// proyectos, universidades y empresas. Función libre (no método de
/// estado) para que la use tanto el buscador en línea de escritorio
/// ([_GlobalSearch]) como la pantalla completa de compact
/// ([_CompactSearchScreen]).
List<_SearchHit> _searchHits(DataProvider data, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return const [];
  final hits = <_SearchHit>[];
  for (final u in data.studentsAndAlumni) {
    if (u.name.toLowerCase().contains(q)) {
      hits.add(_SearchHit(Roles.label(u.role), u.name,
          '${u.university} · ${u.career}', Icons.school_outlined));
    }
  }
  for (final u in data.usersByRole(Roles.lxd)) {
    if (u.name.toLowerCase().contains(q)) {
      final courseCount =
          data.courses.where((c) => c.creatorId == u.id).length;
      hits.add(_SearchHit(
          'LXD', u.name, '$courseCount cursos creados', Icons.school_outlined));
    }
  }
  for (final u in data.usersByRole(Roles.mentor)) {
    if (u.name.toLowerCase().contains(q)) {
      final labNames = data
          .labsForMentor(u)
          .map((l) => l.name)
          .join(', ');
      hits.add(_SearchHit('Mentor', u.name, labNames,
          Icons.psychology_outlined));
    }
  }
  for (final c in data.courses) {
    if (c.name.toLowerCase().contains(q)) {
      hits.add(_SearchHit('Curso', c.name,
          '${c.lessonCount} lecciones', Icons.video_library_outlined));
    }
  }
  for (final p in data.projects) {
    if (p.name.toLowerCase().contains(q)) {
      hits.add(_SearchHit(
          'Proyecto', p.name, 'Etapa: ${p.stage}', Icons.lightbulb_outline));
    }
  }
  final universities = data.studentsAndAlumni
      .map((s) => s.university)
      .where((u) => u.isNotEmpty)
      .toSet();
  for (final u in universities) {
    if (u.toLowerCase().contains(q)) {
      final count = data.studentsAndAlumni
          .where((s) => s.university == u)
          .length;
      hits.add(_SearchHit('Universidad', u, '$count estudiantes',
          Icons.account_balance_outlined));
    }
  }
  for (final c in data.usersByRole(Roles.company)) {
    if (c.companyName.toLowerCase().contains(q)) {
      final labNames =
          data.labsForCompany(c.id).map((l) => l.name).join(', ');
      hits.add(_SearchHit('Empresa', c.companyName,
          labNames.isEmpty ? 'Aliado corporativo' : labNames,
          Icons.business_outlined));
    }
  }
  return hits.take(8).toList();
}

/// Diálogo de detalle al elegir un resultado — compartido por el buscador
/// en línea de escritorio y la pantalla completa de compact.
void _showSearchHitDetail(BuildContext context, _SearchHit hit) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(children: [
        Icon(hit.icon, color: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(child: Text(hit.name, style: const TextStyle(fontSize: 18))),
      ]),
      content: Text('${hit.type}\n${hit.sub}', style: const TextStyle(height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    ),
  );
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: _focused ? 340 : 240,
      child: RawAutocomplete<_SearchHit>(
        focusNode: _focus,
        textEditingController: TextEditingController(),
        optionsBuilder: (t) => _searchHits(data, t.text),
        displayStringForOption: (h) => h.name,
        onSelected: (hit) => _showSearchHitDetail(context, hit),
        fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
          controller: ctrl,
          focusNode: focus,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Buscar estudiantes, cursos, proyectos…',
            prefixIcon: Icon(Icons.search,
                size: 19,
                color: _focused ? AppColors.gold : AppColors.textMuted),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 8)),
                ],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(6),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final hit = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    hoverColor: AppColors.gold.withValues(alpha: 0.08),
                    leading: Icon(hit.icon, color: AppColors.gold, size: 20),
                    title: Text(hit.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('${hit.type} · ${hit.sub}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                    onTap: () => onSelected(hit),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buscador global en compact: pantalla completa en vez del campo que se
// expande in-line (ese no cabe junto al resto del header en <600dp).
// ---------------------------------------------------------------------------

class _CompactSearchScreen extends StatefulWidget {
  const _CompactSearchScreen();

  @override
  State<_CompactSearchScreen> createState() => _CompactSearchScreenState();
}

class _CompactSearchScreenState extends State<_CompactSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final hits = _searchHits(data, _query);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Buscar estudiantes, cursos, proyectos…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: _query.isEmpty
          ? const Center(
              child: Text('Escribe para buscar',
                  style: TextStyle(color: AppColors.textMuted)))
          : hits.isEmpty
              ? const Center(
                  child: Text('Sin resultados',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: hits.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final hit = hits[i];
                    return ListTile(
                      minVerticalPadding: 14,
                      leading: Icon(hit.icon, color: AppColors.gold),
                      title: Text(hit.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('${hit.type} · ${hit.sub}',
                          style: const TextStyle(color: AppColors.textMuted)),
                      onTap: () => _showSearchHitDetail(context, hit),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar con menú desplegable (Mi perfil / Cerrar sesión)
// ---------------------------------------------------------------------------

class _AvatarMenu extends StatelessWidget {
  final AppUser user;
  const _AvatarMenu({required this.user});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Mi cuenta',
      offset: const Offset(0, 52),
      color: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              Text('${Roles.label(user.role)} · ${user.email}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 18),
            SizedBox(width: 10),
            Text('Mi perfil'),
          ]),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: AppColors.statusCritical),
            SizedBox(width: 10),
            Text('Cerrar sesión',
                style: TextStyle(color: AppColors.statusCritical)),
          ]),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'profile':
            _showProfile(context);
          case 'logout':
            context.read<AuthProvider>().logout();
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false);
        }
      },
      child: HoverableAvatar(user: user),
    );
  }

  void _showProfile(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          CircleAvatar(
            backgroundColor: AppColors.gold,
            child: Text(user.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF1A1400), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(user.name, style: const TextStyle(fontSize: 18))),
        ]),
        content: Text(
          'Rol: ${Roles.label(user.role)}\n'
          'Correo: ${user.email}\n'
          '${user.phone.isNotEmpty ? 'Teléfono: ${user.phone}\n' : ''}'
          '${user.university.isNotEmpty ? 'Universidad: ${user.university}\n' : ''}',
          style: const TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

/// Avatar que se ilumina al pasar el mouse.
class HoverableAvatar extends StatefulWidget {
  final AppUser user;
  const HoverableAvatar({super.key, required this.user});

  @override
  State<HoverableAvatar> createState() => _HoverableAvatarState();
}

class _HoverableAvatarState extends State<HoverableAvatar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // En compact no entra el nombre/rol en línea junto al resto del header
    // — el avatar solo (círculo con inicial) sigue abriendo el mismo menú.
    final compact = context.isCompact;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _hover ? 1.08 : 1,
            duration: const Duration(milliseconds: 150),
            child: CircleAvatar(
              radius: 17,
              backgroundColor:
                  _hover ? AppColors.goldBright : AppColors.gold,
              child: Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFF1A1400), fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.name,
                    style: TextStyle(
                        color: _hover
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(Roles.label(widget.user.role),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 18,
                color: _hover ? AppColors.gold : AppColors.textMuted),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notificaciones: panel que se desliza suavemente desde la derecha
// ---------------------------------------------------------------------------

class _NotificationBell extends StatelessWidget {
  final String userId;
  const _NotificationBell({required this.userId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final notifications = data.notificationsFor(userId);
    final unread = notifications.where((n) => !n.read).length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.textSecondary,
          hoverColor: AppColors.gold.withValues(alpha: 0.1),
          tooltip: 'Notificaciones',
          onPressed: () => _showPanel(context),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
                child: Text('$unread',
                    style: const TextStyle(
                        color: Color(0xFF1A1400),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }

  void _showPanel(BuildContext context) {
    final data = context.read<DataProvider>();
    final notifications = data.notificationsFor(userId);
    data.markNotificationsRead(userId);

    if (context.isCompact) {
      // Panel flotante de 380px no cabe en un teléfono — bottom sheet a
      // todo el ancho en su lugar.
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceAlt,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => SafeArea(
          child: _NotificationListBody(notifications: notifications, maxHeight: 480),
        ),
      );
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notificaciones',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0.15, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (context, _, __) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 114, right: 20),
          child: Material(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            elevation: 12,
            child: SizedBox(
              width: 380,
              child: _NotificationListBody(
                  notifications: notifications, maxHeight: 460),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de notificaciones — compartida por el panel flotante de
/// escritorio y el bottom sheet de compact.
class _NotificationListBody extends StatelessWidget {
  final List<AppNotification> notifications;
  final double maxHeight;
  const _NotificationListBody(
      {required this.notifications, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('Sin notificaciones',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final n = notifications[i];
          return ListTile(
            leading: const Icon(Icons.notifications,
                color: AppColors.gold, size: 20),
            title: Text(n.title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${n.body}\n${DateFormat('d MMM yyyy, h:mm a').format(n.date)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
