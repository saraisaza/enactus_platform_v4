import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

Color forumCategoryColor(String category) => switch (category) {
      ForumCategory.avance => const Color(0xFF4C9F38),
      ForumCategory.recurso => const Color(0xFFFD6925),
      ForumCategory.anuncio => AppColors.gold,
      _ => const Color(0xFF26BDE2),
    };

IconData forumCategoryIcon(String category) => switch (category) {
      ForumCategory.avance => Icons.trending_up,
      ForumCategory.recurso => Icons.attach_file,
      ForumCategory.anuncio => Icons.campaign,
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
/// empresa si la tiene, si no universidad.
String _orgOf(AppUser? user) {
  if (user == null) return '';
  if (user.companyName.isNotEmpty) return user.companyName;
  return user.university;
}

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
  String _categoryDraft = ForumCategory.pregunta;
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
    setState(() => _sending = true);
    try {
      await data.saveForumPost(ForumPost(
        id: data.newId('post'),
        authorId: me.id,
        body: text,
        category: _categoryDraft,
      ));
      _composerCtrl.clear();
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No se pudo publicar. Intenta de nuevo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null) return const SizedBox.shrink();

    final allPosts = data.forumPosts; // ya viene ordenado por fecha desc
    final pinned = allPosts.where((p) => p.pinned).toList();
    final rest = allPosts.where((p) => !p.pinned).toList();
    final ordered = [...pinned, ...rest];

    var posts = _categoryFilter == 'todas'
        ? ordered
        : ordered.where((p) => p.category == _categoryFilter).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      posts = posts.where((p) {
        final author = data.userById(p.authorId);
        final haystack =
            [author?.name ?? '', _orgOf(author), p.body].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    final canModerate = me.role == Roles.admin || me.role == Roles.superAdmin;
    final activeCount = data.activeForumUsersThisWeek();
    final topTeams = data.mostActiveForumTeams();

    return ContentScreenShell(
      eyebrow: '$activeCount persona${activeCount == 1 ? '' : 's'} '
          'activa${activeCount == 1 ? '' : 's'} esta semana',
      title: 'Foro de la Comunidad',
      subtitle: 'Pregunta, comparte avances y encuentra a quién ya resolvió lo '
          'que tú estás resolviendo. Escriben estudiantes, mentores y LXD de '
          'toda la red.',
      searchHint: 'Buscar autor, organización o contenido',
      onSearchChanged: (v) => setState(() => _query = v),
      bodyBuilder: (context, colors, isDark) {
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    ? 'El foro está vacío. Sé la primera en abrir la '
                        'conversación de la comunidad.'
                    : 'Ninguna publicación coincide con este filtro. Prueba '
                        'con otra categoría o limpia la búsqueda.',
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
            _RulesCard(colors: colors),
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
                    color: Color(0xFF1A1400), fontWeight: FontWeight.w700, fontSize: 17)),
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
                    hintText: '¿Qué quieres compartir con la comunidad?',
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
    setState(() => _sendingReply = true);
    try {
      await data.addForumReply(widget.post.id,
          ForumReply(id: data.newId('reply'), authorId: widget.me.id, body: text));
      _replyCtrl.clear();
      if (mounted) setState(() => _replyOpen = false);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No se pudo enviar la respuesta.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final colors = widget.colors;
    final post = widget.post;
    final author = data.userById(post.authorId);
    final name = (author == null || author.name.isEmpty) ? 'Usuario eliminado' : author.name;
    final isStaff = author != null && !Roles.isStudentLike(author.role);
    final org = _orgOf(author);
    final catColor = forumCategoryColor(post.category);
    final liked = post.likedBy.contains(widget.me.id);
    final canDelete = widget.canModerate || post.authorId == widget.me.id;
    final visibleReplies =
        _repliesExpanded ? post.replies : post.replies.take(2).toList();

    return HoverBuilder(
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: catColor, width: 3),
            top: BorderSide(color: colors.border),
            right: BorderSide(color: colors.border),
            bottom: BorderSide(color: colors.border),
          ),
          boxShadow: hover ? colors.shadow : const [],
        ),
        child: Column(
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
                          color: Color(0xFF1A1400), fontWeight: FontWeight.w700, fontSize: 17)),
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
                              label: author == null ? '' : Roles.label(author.role),
                              staff: isStaff,
                              colors: colors),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (org.isNotEmpty) org,
                            relativeTime(post.date),
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
            Row(
              children: [
                _ActionButton(
                  icon: Icons.volunteer_activism_outlined,
                  label: '${post.likedBy.length}',
                  active: liked,
                  colors: colors,
                  onTap: () => data.toggleForumLike(post.id, widget.me.id),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.replies.length} '
                      'respuesta${post.replies.length == 1 ? '' : 's'}',
                  active: _replyOpen,
                  colors: colors,
                  onTap: () => setState(() => _replyOpen = !_replyOpen),
                ),
                const Spacer(),
                if (widget.canModerate)
                  _IconOnlyButton(
                    icon: post.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    colors: colors,
                    hoverColor: colors.goldInk,
                    tooltip: post.pinned ? 'Desfijar' : 'Fijar anuncio',
                    onTap: () => data.setForumPinned(post.id, !post.pinned),
                  ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  _IconOnlyButton(
                    icon: Icons.delete_outline,
                    colors: colors,
                    hoverColor: const Color(0xFFFF8A9B),
                    tooltip: 'Eliminar',
                    onTap: () async {
                      if (await confirmDialog(context, 'Eliminar publicación',
                          '¿Eliminar esta publicación del foro? Esta acción no se puede deshacer.')) {
                        await data.deleteForumPost(post.id);
                      }
                    },
                  ),
                ],
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
            if (post.replies.isNotEmpty) ...[
              for (final r in visibleReplies)
                _ReplyTile(
                  authorName: _replyAuthorName(data, r.authorId),
                  reply: r,
                  colors: colors,
                ),
              if (!_repliesExpanded && post.replies.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => setState(() => _repliesExpanded = true),
                    child: Text('Ver las ${post.replies.length} respuestas'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _replyAuthorName(DataProvider data, String authorId) {
  final name = data.userById(authorId)?.name ?? '';
  return name.isEmpty ? 'Usuario eliminado' : name;
}

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
        return GestureDetector(
          onTap: onTap,
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
                Text(label,
                    style: TextStyle(fontSize: 12.5, color: on ? colors.goldInk : colors.text2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  final IconData icon;
  final ContentColors colors;
  final Color hoverColor;
  final String tooltip;
  final VoidCallback onTap;
  const _IconOnlyButton(
      {required this.icon,
      required this.colors,
      required this.hoverColor,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: hover ? hoverColor : colors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: hover ? hoverColor : colors.text3),
          ),
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final String authorName;
  final ForumReply reply;
  final ContentColors colors;
  const _ReplyTile({required this.authorName, required this.reply, required this.colors});

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
                    color: Color(0xFF1A1400), fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(authorName,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: colors.text)),
                    const SizedBox(width: 8),
                    Text(relativeTime(reply.date),
                        style: TextStyle(fontSize: 11.5, color: colors.text3)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reply.body,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: colors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final ContentColors colors;
  const _RulesCard({required this.colors});

  static const _rules = [
    (
      Icons.handshake_outlined,
      'Respeta a los demás equipos y comparte con la misma apertura con la que te gustaría recibir ayuda.'
    ),
    (
      Icons.verified_outlined,
      'Publica contenido real de tu proyecto: evidencias y preguntas concretas ayudan más que mensajes genéricos.'
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
              style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
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
        ],
      ),
    );
  }
}

class _TopTeamsCard extends StatelessWidget {
  final List<({Group group, int count})> teams;
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
              style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
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
                        style: knockoutHeading(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? colors.bg : colors.text3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(teams[i].group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: colors.text)),
                        if (teams[i].group.university.isNotEmpty)
                          Text(teams[i].group.university,
                              style: TextStyle(fontSize: 11.5, color: colors.text3)),
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
