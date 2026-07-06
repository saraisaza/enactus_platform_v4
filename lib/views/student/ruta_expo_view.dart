import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/video_player_dialog.dart';

/// RUTA NATIONAL EXPO: curso colaborativo del equipo.
/// Checklist compartido, entrenamientos, entregas grupales y cronograma.
class RutaExpoView extends StatelessWidget {
  const RutaExpoView({super.key});

  static const _schedule = [
    ('15 Jul 2026', 'Cierre de inscripciones'),
    ('1 Ago 2026', 'Entrega Annual Report'),
    ('15 Ago 2026', 'Entrega Impact Page y Pitch Deck'),
    ('1 Sep 2026', 'Simulaciones de pitch con mentores'),
    ('20 Sep 2026', 'NATIONAL EXPO — Bogotá D. C.'),
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final group = data.groupById(student.groupId);

    if (group == null) {
      return const TabBody(
        title: 'RUTA NATIONAL EXPO',
        children: [
          EmptyState(
              icon: Icons.emoji_events_outlined,
              message: 'Aún no perteneces a un equipo.'),
        ],
      );
    }

    final project = data.projectById(group.projectId);
    if (project == null || !project.expoEnabled) {
      return const TabBody(
        title: 'RUTA NATIONAL EXPO',
        children: [
          EmptyState(
              icon: Icons.lock_outline,
              message:
                  'La RUTA NATIONAL EXPO se habilita cuando tu equipo es '
                  'seleccionado por el administrador.'),
        ],
      );
    }

    final expoCourse = data.courses
        .where((c) => c.isRutaExpo && c.projectId == project.id)
        .toList();
    final checklist = data.checklistFor(group.id);
    final submissions = data.submissionsForGroup(group.id);
    final teammates = group.studentIds
        .map((id) => data.userById(id)?.name ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');
    final done =
        checklist.items.where((i) => i['done'] == true).length;

    return TabBody(
      title: 'RUTA NATIONAL EXPO',
      subtitle:
          'Equipo ${group.name} · Proyecto ${project.name} · Integrantes: $teammates',
      children: [
        // Progreso del checklist
        HoverCard(
          child: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: AppColors.gold, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preparación para la competencia',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ThinProgressBar(
                        value: checklist.items.isEmpty
                            ? 0
                            : done / checklist.items.length),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Checklist de competencia (compartido con tu equipo)'),
        ...List.generate(checklist.items.length, (i) {
          final item = checklist.items[i];
          final isDone = item['done'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: HoverCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              onTap: () {
                checklist.items[i]['done'] = !isDone;
                data.saveChecklist(checklist);
                if (!isDone) {
                  showSuccessCheck(context, '¡Hito completado! 🏆');
                }
              },
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        isDone ? AppColors.statusGood : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['label'] as String,
                      style: TextStyle(
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SectionTitle('Entrenamientos y material'),
        if (expoCourse.isEmpty)
          const EmptyState(
              icon: Icons.school_outlined,
              message: 'El contenido del curso aún no está disponible.')
        else
          for (final module in expoCourse.first.modules)
            for (final lesson in module.lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: HoverCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  onTap: () {
                    if (lesson.type == LessonType.video) {
                      VideoPlayerDialog.show(
                          context, lesson.title, lesson.resourcePath);
                    } else {
                      showAppSnack(context,
                          'Material en course_resources/${lesson.resourcePath}');
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        lesson.type == LessonType.video
                            ? Icons.play_circle_outline
                            : Icons.picture_as_pdf_outlined,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(lesson.title)),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
        const SectionTitle('Entregas del equipo (Annual Report, Impact Page, Pitch Deck)'),
        for (final s in submissions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HoverCard(
              child: Row(
                children: [
                  const Icon(Icons.folder_shared_outlined,
                      color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.taskName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                            '${s.comment}\n${DateFormat('d MMM yyyy').format(s.date)}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (s.grade != null)
                    StatusChip(
                        label: 'Nota: ${s.grade}',
                        color: AppColors.statusGood,
                        icon: Icons.grade),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Nueva entrega grupal'),
          onPressed: () => _newGroupSubmission(
              context, group, expoCourse.isEmpty ? '' : expoCourse.first.id),
        ),
        const SectionTitle('Cronograma'),
        HoverCard(
          child: Column(
            children: [
              for (final (date, event) in _schedule)
                HoverBuilder(
                  builder: (context, hover) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: hover
                          ? AppColors.gold.withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        AnimatedScale(
                          scale: hover ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 100,
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.slate,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(date,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(event,
                              style: TextStyle(
                                  fontWeight: hover
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ),
                        AnimatedOpacity(
                          opacity: hover ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: const Icon(Icons.flag_outlined,
                              size: 16, color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _newGroupSubmission(
      BuildContext context, Group group, String courseId) async {
    final data = context.read<DataProvider>();
    final student = context.read<AuthProvider>().currentUser!;
    final taskCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String filePath = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Entrega grupal', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: taskCtrl,
                    decoration: const InputDecoration(
                        labelText:
                            'Entregable (p. ej. Annual Report, Pitch Deck)')),
                const SizedBox(height: 12),
                TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Comentario')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Adjuntar archivo'),
                      onPressed: () async {
                        final result = await FilePicker.pickFiles();
                        if (result != null) {
                          // En web no hay ruta local: se guarda el nombre.
                          setState(() => filePath =
                              result.files.single.path ??
                                  result.files.single.name);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        filePath.isEmpty
                            ? 'Sin archivo'
                            : filePath.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (taskCtrl.text.trim().isEmpty) return;
                await data.saveSubmission(Submission(
                  id: data.newId('sub'),
                  courseId: courseId,
                  groupId: group.id,
                  taskName: taskCtrl.text.trim(),
                  comment:
                      '${commentCtrl.text.trim()} (enviado por ${student.name})',
                  filePath: filePath,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSuccessCheck(context, 'Entrega grupal enviada ✓');
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
