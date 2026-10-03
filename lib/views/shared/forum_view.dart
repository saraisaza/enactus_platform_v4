import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/async_value.dart';
import '../../widgets/async_states.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/normas_comunidad.dart';
import '../../widgets/portal_shell.dart';
import 'foro_moderacion.dart';

// "Recurso" usaba un naranja (#FD6925) casi idéntico al acento de marca de
// entonces — se reasignó a un tono de la paleta categórica de gráficos para
// que las 4 categorías se distingan entre sí y de "anuncio" (que sí usa el
// acento de marca a propósito). La razón sigue valiendo con el ámbar: el
// color de la categoría nunca debe poder confundirse con el acento.
Color forumCategoryColor(String category) => switch (category) {
      ForumCategory.progress => AppColors.statusGood,
      ForumCategory.resource => AppColors.chartSeries[3],
      ForumCategory.announcement => AppColors.gold,
      _ => AppColors.chartSeries[1],
    };

IconData forumCategoryIcon(String category) => switch (category) {
      ForumCategory.progress => Icons.trending_up,
      ForumCategory.resource => Icons.attach_file,
      ForumCategory.announcement => Icons.campaign,
      _ => Icons.help_outline,
    };

/// "hace 2 h", "ayer", "hace 5 días" y fecha completa a partir de una
/// semana — el tiempo relativo que pide el README para cada publicación.
String relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  if (diff.inDays < 7) return 'hace ${diff.inDays} días';
  return DateFormat('d MMM yyyy', 'es').format(date);
}

/// Organización de un usuario para mostrar junto a su nombre en el foro:
/// Foro de la comunidad Enactus — rediseño funcional y de alta fidelidad
/// según `design_handoff_portal_estudiante/README.md` (pantalla 6). Es el
/// único espacio de la plataforma que NO está aislado por laboratorio,
/// universidad o empresa: lo comparten Admin, Super Admin, Asesores y
/// estudiantes Enactus por igual (ver [DataProvider.canAccessForum]) —
/// este archivo es un solo widget compartido por los 3 portales
/// (`student_portal.dart`, `advisor_portal.dart`, `admin_portal.dart`),
/// no una copia por rol.
class ForumView extends StatefulWidget {
  const ForumView({super.key});

  @override
  State<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends State<ForumView> {
  final _composerCtrl = TextEditingController();
  String _categoryDraft = ForumCategory.question;
  bool _sending = false;

  /// Filtro de categoría del feed — deliberadamente separado de
  /// [_categoryDraft] (el compositor): el README es explícito en que son
  /// dos controles distintos que no comparten estado.
  String _categoryFilter = 'todas';
  String _query = '';

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish(DataProvider data, AppUser me) async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    // App Store (guía 1.2): antes de publicar, la persona acepta las normas.
    if (!await asegurarNormasAceptadas(context, me.id) || !mounted) return;
    setState(() => _sending = true);
    try {
      await data.createForumPost(text, _categoryDraft);
      _composerCtrl.clear();
    } on ApiException catch (e) {
      // Se muestra el motivo REAL: "sin conexión" y "su cuenta es de Open
      // Learning" piden cosas distintas de quien lo lee.
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null) return const SizedBox.shrink();

    final postsState = data.forumPosts;
    final canModerate = me.role == Roles.admin || me.role == Roles.superAdmin;

    // El foro es exclusivo de la comunidad Enactus: una cuenta de Open
    // Learning recibe 403 del servidor, y eso llega acá como error — nunca
    // como una lista vacía que parecería "todavía no hay publicaciones".
    final error = postsState.errorOrNull;
    if (error != null) {
      return ContentScreenShell(
        eyebrow: 'Comunidad',
        title: 'Foro de la Comunidad',
        subtitle: 'No pudimos abrir el foro.',
        bodyBuilder: (context, colors, isDark) =>
            ErrorState(error, onRetry: data.reloadForumPosts),
      );
    }

    final allPosts = postsState.valueOrNull;
    if (allPosts == null) {
      return const ContentScreenShell(
        eyebrow: 'Comunidad',
        title: 'Foro de la Comunidad',
        subtitle: 'Cargando publicaciones…',
        bodyBuilder: _forumLoadingBody,
      );
    }

    final pinned = allPosts.where((p) => p.pinned).toList();
    final rest = allPosts.where((p) => !p.pinned).toList();
    final ordered = [...pinned, ...rest];

    var posts = _categoryFilter == 'todas'
        ? ordered
        : ordered.where((p) => p.category == _categoryFilter).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      posts = posts
          .where((p) => '${p.authorName} ${p.body}'.toLowerCase().contains(q))
          .toList();
    }

    // Cifras del encabezado: las calcula el servidor. Si fallan, el foro se
    // muestra igual — no vale la pena bloquearlo por un contador.
    final stats = data.forumStats.valueOrNull;
    final activeCount = stats?.activeUsersThisWeek ?? 0;
    // Solo quien modera pide la cola: para el resto el servidor responde 403.
    final pendientes =
        canModerate ? (data.forumReports.valueOrNull?.length ?? 0) : 0;
    final topTeams = stats?.mostActiveTeams ?? const <ForumTeamActivity>[];

    return ContentScreenShell(
      eyebrow: '$activeCount persona${activeCount == 1 ? '' : 's'} '
          'activa${activeCount == 1 ? '' : 's'} esta semana',
      title: 'Foro de la Comunidad',
      subtitle: 'Pregunte, comparta avances y encuentre a quién ya resolvió lo '
          'que usted está resolviendo. Escriben estudiantes, mentores y LXD de '
          'toda la red.',
      searchHint: 'Buscar autor, organización o contenido',
      onSearchChanged: (v) => setState(() => _query = v),
      bodyBuilder: (context, colors, isDark) {
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendientes > 0) ...[
              _BannerReportes(pendientes: pendientes, colors: colors),
              const SizedBox(height: 16),
            ],
            _Composer(
              controller: _composerCtrl,
              me: me,
              category: _categoryDraft,
              sending: _sending,
              colors: colors,
              onCategoryChanged: (c) => setState(() => _categoryDraft = c),
              onChanged: () => setState(() {}),
              onPublish: () => _publish(data, me),
            ),
            const SizedBox(height: 20),
            _buildFilters(colors, allPosts),
            const SizedBox(height: 20),
            if (posts.isEmpty)
              EmptyState(
                icon: Icons.forum_outlined,
                title: 'Nadie ha escrito aún',
                message: allPosts.isEmpty
                    ? 'El foro está vacío. Puede ser la primera persona en abrir la '
                        'conversación de la comunidad.'
                    : 'Ninguna publicación coincide con este filtro. Pruebe '
                        'con otra categoría o limpie la búsqueda.',
                primaryLabel: 'Ver todo el foro',
                onPrimary: () => setState(() {
                  _categoryFilter = 'todas';
                  _query = '';
                }),
                colors: colors,
              )
            else
              for (var i = 0; i < posts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Entrance(
                    delayMs: 55 * i,
                    child: _PostCard(
                      post: posts[i],
                      me: me,
                      canModerate: canModerate,
                      colors: colors,
                    ),
                  ),
                ),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RulesCard(colors: colors, canModerate: canModerate),
            if (topTeams.isNotEmpty) ...[
              const SizedBox(height: 20),
              _TopTeamsCard(teams: topTeams, colors: colors),
            ],
          ],
        );

        return LayoutBuilder(builder: (context, c) {
          if (c.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 170, child: left),
                const SizedBox(width: 22),
                Expanded(flex: 100, child: right),
              ],
            );
          }
          return Column(children: [left, const SizedBox(height: 22), right]);
        });
      },
    );
  }

  Widget _buildFilters(ContentColors colors, List<ForumPost> allPosts) {
    int countFor(String cat) => cat == 'todas'
        ? allPosts.length
        : allPosts.where((p) => p.category == cat).length;

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        _CategoryFilterChip(
          label: 'Todo',
          count: countFor('todas'),
          active: _categoryFilter == 'todas',
          colors: colors,
          onTap: () => setState(() => _categoryFilter = 'todas'),
        ),
        for (final cat in ForumCategory.all)
          _CategoryFilterChip(
            label: ForumCategory.label(cat),
            count: countFor(cat),
            active: _categoryFilter == cat,
            colors: colors,
            onTap: () => setState(() => _categoryFilter = cat),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final AppUser me;
  final String category;
  final bool sending;
  final ContentColors colors;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onChanged;
  final VoidCallback onPublish;
  const _Composer({
    required this.controller,
    required this.me,
    required this.category,
    required this.sending,
    required this.colors,
    required this.onCategoryChanged,
    required this.onChanged,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final canPublish = controller.text.trim().isNotEmpty && !sending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gold,
            child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 17)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 3,
                  onChanged: (_) => onChanged(),
                  style: TextStyle(fontSize: 14.5, height: 1.5, color: colors.text),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.surface2,
                    hintText: '¿Qué quiere compartir con la comunidad?',
                    hintStyle: TextStyle(color: colors.text3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.goldInk)),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in ForumCategory.all)
                          _ComposerCategoryChip(
                            category: cat,
                            active: category == cat,
                            colors: colors,
                            onTap: () => onCategoryChanged(cat),
                          ),
                      ],
                    ),
                    Opacity(
                      // El tema global de ElevatedButton no atenúa el estado
                      // disabled (mismo dorado siempre) — el README pide
                      // opacidad .45 mientras el textarea esté vacío, así
                      // que se aplica aquí en vez de tocar el tema de toda
                      // la app por un solo botón.
                      opacity: canPublish ? 1 : 0.45,
                      child: MouseRegion(
                        cursor: canPublish
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.forbidden,
                        child: ElevatedButton.icon(
                          onPressed: canPublish ? onPublish : null,
                          icon: const Icon(Icons.send, size: 18),
                          label: Text(sending ? 'Publicando…' : 'Publicar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerCategoryChip extends StatelessWidget {
  final String category;
  final bool active;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ComposerCategoryChip(
      {required this.category, required this.active, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: active ? colors.goldSoft : colors.surface2,
            border: Border.all(color: active ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(forumCategoryIcon(category),
                  size: 15, color: active ? colors.goldInk : colors.text3),
              const SizedBox(width: 7),
              Text(ForumCategory.label(category),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.goldInk : colors.text3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final ContentColors colors;
  final VoidCallback onTap;
  const _CategoryFilterChip(
      {required this.label,
      required this.count,
      required this.active,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? colors.goldSoft : colors.surface,
            border: Border.all(color: active ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.goldInk : colors.text2)),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? colors.goldInk : colors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? colors.bg : colors.text3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final ForumPost post;
  final AppUser me;
  final bool canModerate;
  final ContentColors colors;
  const _PostCard(
      {required this.post, required this.me, required this.canModerate, required this.colors});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _replyOpen = false;
  bool _repliesExpanded = false;
  bool _sendingReply = false;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReply(DataProvider data) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sendingReply) return;
    if (!await asegurarNormasAceptadas(context, widget.me.id) || !mounted) {
      return;
    }
    setState(() => _sendingReply = true);
    try {
      await data.replyToForumPost(widget.post.id, text);
      _replyCtrl.clear();
    } on ApiException catch (e) {
      // El motivo real: «sin conexión» no se arregla igual que «lenguaje que
      // no está permitido».
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final colors = widget.colors;
    final post = widget.post;
    final authorName = post.authorName;
    final name = authorName.isEmpty ? 'Usuario eliminado' : authorName;
    final isStaff = post.authorRole.isNotEmpty &&
        !Roles.isStudentLike(post.authorRole);
    // La universidad o empresa del autor ya no viaja con la publicación: era
    // exponer el perfil de cada persona a todo el que abriera el foro.
    const org = '';
    final catColor = forumCategoryColor(post.category);
    final liked = post.likedByMe;
    final canDelete = widget.canModerate || post.authorId == widget.me.id;
    // El listado del servidor trae cuántas respuestas hay, no las respuestas:
    // esas vienen con el detalle, que se pide al abrir la conversación. Antes
    // la tarjeta contaba las que traía el listado —siempre cero— y ninguna
    // respuesta se veía nunca.
    final detalle = _replyOpen ? data.forumPostById(post.id) : null;
    final replies = post.replies.isNotEmpty
        ? post.replies
        : (detalle?.valueOrNull?.replies ?? const <ForumReply>[]);
    final visibleReplies =
        _repliesExpanded ? replies : replies.take(2).toList();

    // Nota: un Border con colores no uniformes (el filete izquierdo de
    // catColor vs. los otros 3 lados en colors.border) no se puede combinar
    // con borderRadius — Flutter lo rechaza en tiempo de ejecución ("A
    // borderRadius can only be given on borders with uniform colors"),
    // dejando la tarjeta completamente en blanco (bug preexistente, no
    // introducido por el cambio de paleta). Se resuelve recortando con
    // ClipRRect y pintando el filete como una franja aparte en vez de
    // como un lado del Border.
    return HoverBuilder(
      builder: (context, hover) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: hover ? colors.shadow : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.border),
                ),
                child: _postCardBody(context, colors, post, name, isStaff, org,
                    catColor, data, liked, canDelete, visibleReplies,
                    replies.length, detalle),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: catColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postCardBody(
      BuildContext context,
      ContentColors colors,
      ForumPost post,
      String name,
      bool isStaff,
      String org,
      Color catColor,
      DataProvider data,
      bool liked,
      bool canDelete,
      List<ForumReply> visibleReplies,
      int totalReplies,
      AsyncValue<ForumPost>? detalle) {
    final esMia = post.authorId == widget.me.id;
    final bloqueable = sePuedeBloquear(
        autorId: post.authorId, autorRol: post.authorRole, miId: widget.me.id);
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.pinned) ...[
              Row(
                children: [
                  Icon(Icons.push_pin, size: 14, color: colors.goldInk),
                  const SizedBox(width: 6),
                  Text('FIJADO',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: colors.goldInk)),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.gold,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 17)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.text)),
                          _RolePill(
                              label: post.authorRole.isEmpty ? '' : Roles.label(post.authorRole),
                              staff: isStaff,
                              colors: colors),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (org.isNotEmpty) org,
                            relativeTime(post.createdAt),
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: colors.text3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(forumCategoryIcon(post.category), size: 15, color: catColor),
                const SizedBox(width: 6),
                Text(ForumCategory.label(post.category).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: catColor)),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.body, style: TextStyle(fontSize: 14.5, height: 1.6, color: colors.text2)),
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 14),
            // Las dos acciones de todos a la izquierda, en un `Wrap`; las de
            // moderación en un menú ⋮. En una sola fila, con el espaciador y
            // dos íconos de 32 dp, no cabía a 360 dp (se salía 68 px).
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _ActionButton(
                        icon: Icons.volunteer_activism_outlined,
                        label: '${post.likeCount}',
                        active: liked,
                        colors: colors,
                        onTap: () => data.toggleForumLike(post.id),
                      ),
                      _ActionButton(
                        icon: Icons.mode_comment_outlined,
                        label: '${post.replyCount} '
                            'respuesta${post.replyCount == 1 ? '' : 's'}',
                        active: _replyOpen,
                        colors: colors,
                        onTap: () => setState(() => _replyOpen = !_replyOpen),
                      ),
                    ],
                  ),
                ),
                if (widget.canModerate || canDelete || !esMia)
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    icon: Icon(Icons.more_vert, color: colors.text2),
                    onSelected: (accion) async {
                      switch (accion) {
                        case 'fijar':
                          await data.toggleForumPin(post.id);
                        case 'reportar':
                          await mostrarReportar(context,
                              postId: post.id,
                              autorId: post.authorId,
                              autorNombre: name,
                              autorBloqueable: bloqueable);
                        case 'bloquear':
                          await confirmarBloqueo(context,
                              autorId: post.authorId, autorNombre: name);
                        case 'eliminar':
                          if (await confirmDialog(context, 'Eliminar publicación',
                              '¿Eliminar esta publicación del foro? Esta acción no se puede deshacer.')) {
                            await data.deleteForumPost(post.id);
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      if (widget.canModerate)
                        PopupMenuItem(
                          value: 'fijar',
                          child: ListTile(
                            leading: Icon(post.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined),
                            title: Text(
                                post.pinned ? 'Desfijar' : 'Fijar anuncio'),
                          ),
                        ),
                      if (!esMia)
                        const PopupMenuItem(
                          value: 'reportar',
                          child: ListTile(
                            leading: Icon(Icons.flag_outlined),
                            title: Text('Reportar'),
                          ),
                        ),
                      if (bloqueable)
                        PopupMenuItem(
                          value: 'bloquear',
                          child: ListTile(
                            leading: const Icon(Icons.block),
                            title: Text('Bloquear a $name'),
                          ),
                        ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: AppColors.statusCritical),
                            title: Text('Eliminar'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            if (_replyOpen) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      maxLines: 2,
                      minLines: 1,
                      style: TextStyle(fontSize: 13.5, color: colors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: colors.surface2,
                        hintText: 'Responder…',
                        hintStyle: TextStyle(color: colors.text3),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.goldInk)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, size: 18),
                    color: colors.goldInk,
                    onPressed: _sendingReply ? null : () => _submitReply(data),
                  ),
                ],
              ),
            ],
            if (detalle != null && detalle.isLoading && totalReplies == 0)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (detalle?.errorOrNull case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ErrorState(error,
                    compact: true,
                    onRetry: () => data.reloadForumPost(post.id)),
              ),
            if (totalReplies > 0) ...[
              for (final r in visibleReplies)
                _ReplyTile(
                  authorName: _replyAuthorName(r),
                  reply: r,
                  colors: colors,
                  postId: post.id,
                  me: widget.me,
                  canModerate: widget.canModerate,
                ),
              if (!_repliesExpanded && totalReplies > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => setState(() => _repliesExpanded = true),
                    child: Text('Ver las $totalReplies respuestas'),
                  ),
                ),
            ],
          ],
    );
  }
}

/// El nombre lo manda la API en cada respuesta. Antes se mostraba el
/// `authorId`: un identificador de 36 caracteres en lugar de una persona.
String _replyAuthorName(ForumReply reply) =>
    reply.authorName.isEmpty ? 'Usuario eliminado' : reply.authorName;

class _RolePill extends StatelessWidget {
  final String label;
  final bool staff;
  final ContentColors colors;
  const _RolePill({required this.label, required this.staff, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: staff ? colors.goldSoft : colors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: staff ? colors.goldInk : colors.text3)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) {
        final on = active || hover;
        // El botón se ve de ~32 dp de alto, pero el área tocable llega a 48
        // con el relleno transparente de arriba y abajo.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(color: on ? colors.goldInk : colors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: on ? colors.goldInk : colors.text2),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: on ? colors.goldInk : colors.text2)),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
class _ReplyTile extends StatelessWidget {
  final String authorName;
  final ForumReply reply;
  final ContentColors colors;
  final String postId;
  final AppUser me;
  final bool canModerate;
  const _ReplyTile(
      {required this.authorName,
      required this.reply,
      required this.colors,
      required this.postId,
      required this.me,
      required this.canModerate});

  Widget _menu(BuildContext context) {
    final esMia = reply.authorId == me.id;
    final bloqueable = sePuedeBloquear(
        autorId: reply.authorId, autorRol: reply.authorRole, miId: me.id);
    final puedeBorrar = esMia || canModerate;
    if (esMia && !puedeBorrar) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      icon: Icon(Icons.more_vert, size: 18, color: colors.text3),
      onSelected: (accion) async {
        final data = context.read<DataProvider>();
        switch (accion) {
          case 'reportar':
            await mostrarReportar(context,
                postId: postId,
                replyId: reply.id,
                autorId: reply.authorId,
                autorNombre: authorName,
                autorBloqueable: bloqueable);
          case 'bloquear':
            await confirmarBloqueo(context,
                autorId: reply.authorId, autorNombre: authorName);
          case 'eliminar':
            if (await confirmDialog(context, 'Eliminar respuesta',
                '¿Eliminar esta respuesta del foro? Esta acción no se puede deshacer.')) {
              try {
                await data.deleteForumReply(postId, reply.id);
              } on ApiException catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.message, error: true);
                }
              }
            }
        }
      },
      itemBuilder: (_) => [
        if (!esMia)
          const PopupMenuItem(
            value: 'reportar',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Reportar'),
            ),
          ),
        if (bloqueable)
          PopupMenuItem(
            value: 'bloquear',
            child: ListTile(
              leading: const Icon(Icons.block),
              title: Text('Bloquear a $authorName'),
            ),
          ),
        if (puedeBorrar)
          const PopupMenuItem(
            value: 'eliminar',
            child: ListTile(
              leading:
                  Icon(Icons.delete_outline, color: AppColors.statusCritical),
              title: Text('Eliminar'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.gold,
            child: Text(authorName.isEmpty ? '?' : authorName[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: colors.text)),
                    ),
                    const SizedBox(width: 8),
                    Text(relativeTime(reply.createdAt),
                        style: TextStyle(fontSize: 11.5, color: colors.text3)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reply.body,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: colors.text2)),
              ],
            ),
          ),
          _menu(context),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final ContentColors colors;
  final bool canModerate;
  const _RulesCard({required this.colors, required this.canModerate});

  static const _rules = [
    (
      Icons.handshake_outlined,
      'Respete a los demás equipos y comparta con la misma apertura con la que le gustaría recibir ayuda.'
    ),
    (
      Icons.verified_outlined,
      'Publique contenido real de su proyecto: evidencias y preguntas concretas ayudan más que mensajes genéricos.'
    ),
    (
      Icons.groups_outlined,
      'Es un espacio de toda la red: preguntas de cualquier laboratorio o universidad son bienvenidas.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Normas del foro'.toUpperCase(),
              style: displayHeading(fontSize: 24, fontWeight: AppWeights.display, color: colors.text)),
          const SizedBox(height: 14),
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rule.$1, size: 18, color: colors.goldInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(rule.$2,
                        style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.text2)),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton(
                onPressed: () => mostrarNormasDeLaComunidad(context),
                child: const Text('Normas completas'),
              ),
              TextButton(
                onPressed: () => mostrarPersonasBloqueadas(context),
                child: const Text('Personas bloqueadas'),
              ),
              if (canModerate)
                TextButton(
                  onPressed: () => ForoReportesView.abrir(context),
                  child: const Text('Reportes del foro'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aviso para quien modera: hay reportes sin atender.
class _BannerReportes extends StatelessWidget {
  final int pendientes;
  final ContentColors colors;
  const _BannerReportes({required this.pendientes, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.goldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.goldInk),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: colors.goldInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendientes == 1
                  ? 'Hay 1 reporte sin atender.'
                  : 'Hay $pendientes reportes sin atender.',
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => ForoReportesView.abrir(context),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}

class _TopTeamsCard extends StatelessWidget {
  final List<ForumTeamActivity> teams;
  final ContentColors colors;
  const _TopTeamsCard({required this.teams, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Equipos más activos'.toUpperCase(),
              style: displayHeading(fontSize: 24, fontWeight: AppWeights.display, color: colors.text)),
          const SizedBox(height: 14),
          for (var i = 0; i < teams.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? colors.goldInk : colors.surface2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('${i + 1}',
                        style: displayHeading(
                            fontSize: 17,
                            fontWeight: AppWeights.display,
                            color: i == 0 ? colors.bg : colors.text3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(teams[i].groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: colors.text)),
                      ],
                    ),
                  ),
                  Text(
                      '${teams[i].count} '
                      'publicaci${teams[i].count == 1 ? 'ón' : 'ones'}',
                      style: TextStyle(fontSize: 12.5, color: colors.text3)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// Esqueleto mientras cargan las publicaciones.
Widget _forumLoadingBody(BuildContext context, ContentColors colors, bool isDark) {
  return const CardListSkeleton(count: 4, height: 168);
}
