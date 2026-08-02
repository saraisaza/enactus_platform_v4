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

/// Foro de la comunidad Enactus: sencillo a propósito — escribir un
/// mensaje y ver los de los demás, con quién lo escribió y cuándo. Sin
/// reacciones ni nada elaborado por ahora. Lo comparten Admin, Super
/// Admin, Asesores y estudiantes Enactus (ver
/// [DataProvider.canAccessForum]).
class ForumView extends StatefulWidget {
  const ForumView({super.key});

  @override
  State<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends State<ForumView> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _publish(DataProvider data, AppUser me) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await data.saveForumPost(
          ForumPost(id: data.newId('post'), authorId: me.id, body: text));
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null) return const SizedBox.shrink();

    final posts = data.forumPosts;
    final canModerate = me.role == Roles.admin || me.role == Roles.superAdmin;

    return TabBody(
      title: 'Foro de la Comunidad',
      subtitle: 'Escribe un mensaje para toda la comunidad Enactus 💛',
      children: [
        HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ctrl,
                maxLines: 3,
                minLines: 1,
                decoration:
                    const InputDecoration(hintText: 'Escribe un mensaje…'),
                onSubmitted: (_) => _publish(data, me),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _sending ? null : () => _publish(data, me),
                  child: const Text('Publicar'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (posts.isEmpty)
          const EmptyState(
              icon: Icons.forum_outlined,
              message: 'Todavía no hay mensajes. ¡Escribe el primero!')
        else
          ...posts.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MessageRow(
                  post: p,
                  canDelete: canModerate || p.authorId == me.id,
                ),
              )),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  final ForumPost post;
  final bool canDelete;
  const _MessageRow({required this.post, required this.canDelete});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final author = data.userById(post.authorId);
    final name = (author == null || author.name.isEmpty)
        ? 'Usuario eliminado'
        : author.name;

    return HoverCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(DateFormat('d MMM, h:mm a').format(post.date),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.body,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.statusCritical,
              tooltip: 'Eliminar mensaje',
              onPressed: () async {
                final data = context.read<DataProvider>();
                if (await confirmDialog(context, 'Eliminar mensaje',
                    '¿Eliminar este mensaje del foro?')) {
                  await data.deleteForumPost(post.id);
                }
              },
            ),
        ],
      ),
    );
  }
}
