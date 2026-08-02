import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../lxd/lesson_editor.dart' show lessonTypeIcon, lessonTypeLabel;

/// Editor de la Ruta de Impacto de un laboratorio: fases (título y
/// descripción), objetivos por categoría (con los cursos que los
/// completan) y módulos (cursos asignados + entregas/lecturas propias).
/// El último módulo de cada fase es SIEMPRE el módulo de mentoría — se
/// deriva automáticamente de su posición, no es un toggle manual.
class LabRutaEditorView extends StatelessWidget {
  final String labId;
  const LabRutaEditorView({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(labId);
    if (lab == null) {
      return const Scaffold(
          body: Center(child: Text('Laboratorio no encontrado')));
    }

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: 'Ruta de Impacto · ${lab.name}'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: AppColors.gold,
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('RUTA DE IMPACTO'.toUpperCase(),
                                  style: knockoutHeading(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold)),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 56, top: 4),
                          child: Text(
                              '${lab.name} — edita fases, objetivos y módulos',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ),
                        const SizedBox(height: 20),
                        for (var i = 0; i < lab.phases.length; i++)
                          _PhaseEditorCard(lab: lab, phaseIndex: i),
                      ],
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                      alignment: Alignment.bottomCenter, child: AppFooter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseEditorCard extends StatelessWidget {
  final Laboratory lab;
  final int phaseIndex;
  const _PhaseEditorCard({required this.lab, required this.phaseIndex});

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    final phase = lab.phases[phaseIndex];
    final entrepreneurshipObjs = phase.objectives
        .where((o) => o.category == ObjectiveCategory.entrepreneurship)
        .toList();
    final businessObjs = phase.objectives
        .where((o) => o.category == ObjectiveCategory.business)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    phase.title.isEmpty
                        ? 'Fase ${phaseIndex + 1}'
                        : phase.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.gold)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Editar título y descripción',
                onPressed: () => _editPhaseInfo(context, lab, phaseIndex),
              ),
            ],
          ),
          if (phase.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(phase.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 14,
                    color: phase.deadline.isEmpty
                        ? AppColors.textMuted
                        : AppColors.gold),
                const SizedBox(width: 6),
                Text(
                    phase.deadline.isEmpty
                        ? 'Sin fecha límite'
                        : 'Fecha límite: ${DateFormat('d MMM yyyy').format(DateTime.parse(phase.deadline))}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 24),

          _SectionHeader(
              label: 'Objetivos de Emprendimiento',
              onAdd: () => _editObjective(context, lab, phaseIndex, null,
                  ObjectiveCategory.entrepreneurship)),
          if (entrepreneurshipObjs.isEmpty)
            const _MutedHint('Sin objetivos todavía.')
          else
            for (final o in entrepreneurshipObjs)
              _ObjectiveEditRow(lab: lab, phaseIndex: phaseIndex, objective: o),
          const SizedBox(height: 12),

          _SectionHeader(
              label: 'Objetivos Empresariales',
              onAdd: () => _editObjective(
                  context, lab, phaseIndex, null, ObjectiveCategory.business)),
          if (businessObjs.isEmpty)
            const _MutedHint('Sin objetivos todavía.')
          else
            for (final o in businessObjs)
              _ObjectiveEditRow(lab: lab, phaseIndex: phaseIndex, objective: o),

          const Divider(height: 24),

          _SectionHeader(
              label: 'Módulos',
              onAdd: () => _editModule(context, lab, phaseIndex, null)),
          if (phase.modules.isEmpty)
            const _MutedHint(
                'Sin módulos todavía. El último que agregues será siempre el módulo de mentoría.')
          else
            for (var i = 0; i < phase.modules.length; i++)
              _ModuleEditRow(lab: lab, phaseIndex: phaseIndex, moduleIndex: i),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final VoidCallback onAdd;
  const _SectionHeader({required this.label, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          color: AppColors.gold,
          tooltip: 'Agregar',
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;
  const _MutedHint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      );
}

// ---------------------------------------------------------------------------
// Objetivos
// ---------------------------------------------------------------------------

class _ObjectiveEditRow extends StatelessWidget {
  final Laboratory lab;
  final int phaseIndex;
  final Objective objective;
  const _ObjectiveEditRow(
      {required this.lab, required this.phaseIndex, required this.objective});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: HoverCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _editObjective(
            context, lab, phaseIndex, objective, objective.category),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(objective.text, style: const TextStyle(fontSize: 13)),
                  Text(
                    objective.sourceCourseIds.isEmpty
                        ? 'Sin cursos vinculados (nunca se completará solo)'
                        : '${objective.sourceCourseIds.length} curso(s) vinculado(s)',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.statusCritical,
              onPressed: () async {
                if (await confirmDialog(context, 'Eliminar objetivo',
                    '¿Eliminar "${objective.text}"?')) {
                  lab.phases[phaseIndex].objectives
                      .removeWhere((o) => o.id == objective.id);
                  await data.saveLab(lab);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editObjective(BuildContext context, Laboratory lab,
    int phaseIndex, Objective? existing, String defaultCategory) async {
  final data = context.read<DataProvider>();
  final textCtrl = TextEditingController(text: existing?.text ?? '');
  var category = existing?.category ?? defaultCategory;
  final selectedCourseIds = {...(existing?.sourceCourseIds ?? <String>[])};
  final courses = data.coursesByLab(lab.id);

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Nuevo objetivo' : 'Editar objetivo',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Objetivo')),
                const SizedBox(height: 14),
                const Text('Categoría',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in ObjectiveCategory.all)
                      ChoiceChip(
                        label: Text(c),
                        selected: category == c,
                        selectedColor: AppColors.gold.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                    'Cursos vinculados (el objetivo se completa cuando el estudiante termine TODOS estos cursos)',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                courses.isEmpty
                    ? const Text(
                        'Este laboratorio no tiene cursos todavía (los crea el LXD).',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in courses)
                            FilterChip(
                              label: Text(c.name,
                                  style: const TextStyle(fontSize: 12)),
                              selected: selectedCourseIds.contains(c.id),
                              selectedColor:
                                  AppColors.gold.withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => sel
                                  ? selectedCourseIds.add(c.id)
                                  : selectedCourseIds.remove(c.id)),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (textCtrl.text.trim().isEmpty) return;
              final phase = lab.phases[phaseIndex];
              if (existing == null) {
                phase.objectives.add(Objective(
                    id: data.newId('obj'),
                    category: category,
                    text: textCtrl.text.trim(),
                    sourceCourseIds: selectedCourseIds.toList()));
              } else {
                existing.text = textCtrl.text.trim();
                existing.category = category;
                existing.sourceCourseIds = selectedCourseIds.toList();
              }
              await data.saveLab(lab);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Módulos
// ---------------------------------------------------------------------------

class _ModuleEditRow extends StatelessWidget {
  final Laboratory lab;
  final int phaseIndex;
  final int moduleIndex;
  const _ModuleEditRow(
      {required this.lab, required this.phaseIndex, required this.moduleIndex});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final phase = lab.phases[phaseIndex];
    final module = phase.modules[moduleIndex];
    final isLast = moduleIndex == phase.modules.length - 1;
    final title =
        module.title.isEmpty ? 'Módulo ${moduleIndex + 1}' : module.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => _editModule(context, lab, phaseIndex, moduleIndex),
        child: Row(
          children: [
            Icon(
                isLast ? Icons.groups_outlined : Icons.view_module_outlined,
                color: AppColors.gold,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    isLast
                        ? 'Módulo de mentoría (automático: siempre el último)'
                        : '${module.courseIds.length} curso(s) · ${module.ownLessons.length} entrega(s)/lectura(s)',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 16),
              color:
                  moduleIndex == 0 ? AppColors.border : AppColors.textMuted,
              tooltip: 'Subir',
              onPressed: moduleIndex == 0
                  ? null
                  : () => _moveModule(context, lab, phaseIndex, moduleIndex, -1),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 16),
              color: isLast ? AppColors.border : AppColors.textMuted,
              tooltip: 'Bajar',
              onPressed: isLast
                  ? null
                  : () => _moveModule(context, lab, phaseIndex, moduleIndex, 1),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.statusCritical,
              onPressed: () async {
                if (await confirmDialog(
                    context, 'Eliminar módulo', '¿Eliminar "$title"?')) {
                  phase.modules.removeAt(moduleIndex);
                  data.normalizeMentorshipFlags(phase);
                  await data.saveLab(lab);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _moveModule(BuildContext context, Laboratory lab, int phaseIndex,
    int index, int delta) async {
  final data = context.read<DataProvider>();
  final phase = lab.phases[phaseIndex];
  final newIndex = index + delta;
  if (newIndex < 0 || newIndex >= phase.modules.length) return;
  final m = phase.modules.removeAt(index);
  phase.modules.insert(newIndex, m);
  data.normalizeMentorshipFlags(phase);
  await data.saveLab(lab);
}

Future<void> _editModule(BuildContext context, Laboratory lab, int phaseIndex,
    int? moduleIndex) async {
  final data = context.read<DataProvider>();
  final phase = lab.phases[phaseIndex];
  final existing = moduleIndex == null ? null : phase.modules[moduleIndex];
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final selectedCourseIds = {...(existing?.courseIds ?? <String>[])};
  final originalCourseIds = {...(existing?.courseIds ?? <String>[])};
  var ownLessons = List<Lesson>.from(existing?.ownLessons ?? <Lesson>[]);
  final courses = data.coursesByLab(lab.id);
  // Los módulos siempre se agregan al final, así que un módulo nuevo (o el
  // último existente) será el módulo de mentoría — y un módulo sin ningún
  // curso ni entrega/lectura nunca cuenta como completo, así que la fase
  // (y el certificado) nunca se desbloquearían.
  final willBeMentorship =
      moduleIndex == null || moduleIndex == phase.modules.length - 1;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Nuevo módulo' : 'Editar módulo',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Título del módulo')),
                const SizedBox(height: 10),
                Text(
                    willBeMentorship
                        ? '🎓 Este será el módulo de mentoría (siempre el último de la fase). '
                            'Agrégale al menos un curso o una entrega/lectura propia — por '
                            'ejemplo "Confirmar asistencia a la reunión" — o nunca se podrá '
                            'completar y la fase quedará bloqueada para siempre.'
                        : 'Un módulo sin ningún curso ni entrega/lectura propia nunca cuenta '
                            'como completo: agrégale al menos uno para que pueda desbloquear '
                            'el siguiente módulo.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.statusWarning)),
                const SizedBox(height: 16),
                const Text('Cursos asignados',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                courses.isEmpty
                    ? const Text(
                        'Este laboratorio no tiene cursos todavía (los crea el LXD).',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in courses)
                            FilterChip(
                              label: Text(c.name,
                                  style: const TextStyle(fontSize: 12)),
                              selected: selectedCourseIds.contains(c.id),
                              selectedColor:
                                  AppColors.gold.withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => sel
                                  ? selectedCourseIds.add(c.id)
                                  : selectedCourseIds.remove(c.id)),
                            ),
                        ],
                      ),
                const SizedBox(height: 6),
                const Text(
                    'Al agregar un curso nuevo, sus objetivos se suman automáticamente a los de la fase.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Entregas y lecturas propias',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      color: AppColors.gold,
                      tooltip: 'Agregar',
                      onPressed: () async {
                        final lesson = await _editOwnLesson(context, null);
                        if (lesson != null) {
                          setState(() => ownLessons = [...ownLessons, lesson]);
                        }
                      },
                    ),
                  ],
                ),
                if (ownLessons.isEmpty)
                  const Text('Sin entregas ni lecturas.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted))
                else
                  for (final l in ownLessons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(lessonTypeIcon(l.type),
                              size: 16, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(l.title,
                                  style: const TextStyle(fontSize: 12.5))),
                          Text(
                              l.type == LessonType.activity
                                  ? 'Entrega'
                                  : lessonTypeLabel(l.type),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            color: AppColors.gold,
                            onPressed: () async {
                              final updated =
                                  await _editOwnLesson(context, l);
                              if (updated != null) {
                                setState(() => ownLessons = [
                                      for (final x in ownLessons)
                                        x.id == l.id ? updated : x,
                                    ]);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 15),
                            color: AppColors.statusCritical,
                            onPressed: () => setState(() => ownLessons =
                                ownLessons
                                    .where((x) => x.id != l.id)
                                    .toList()),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              if (existing == null) {
                phase.modules.add(RutaModule(
                    id: data.newId('mod'),
                    order: phase.modules.length + 1,
                    title: titleCtrl.text.trim(),
                    courseIds: selectedCourseIds.toList(),
                    ownLessons: ownLessons));
              } else {
                existing.title = titleCtrl.text.trim();
                existing.courseIds = selectedCourseIds.toList();
                existing.ownLessons = ownLessons;
              }
              data.normalizeMentorshipFlags(phase);

              // Sección 5.4: los objetivos de un curso recién vinculado se
              // agregan como objetivos de la fase (o se suman al objetivo
              // existente si el texto ya coincide, para poder exigir
              // "todos los cursos" en un mismo objetivo).
              final newCourseIds =
                  selectedCourseIds.difference(originalCourseIds);
              for (final cid in newCourseIds) {
                final course = data.courseById(cid);
                if (course != null) data.importCourseObjectives(phase, course);
              }

              await data.saveLab(lab);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Future<Lesson?> _editOwnLesson(BuildContext context, Lesson? existing) async {
  final data = context.read<DataProvider>();
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final pathCtrl = TextEditingController(text: existing?.resourcePath ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  var type = existing?.type ?? LessonType.pdf;

  return showDialog<Lesson>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Nueva entrega o lectura' : 'Editar',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              DropdownButtonFormField<LessonType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in const [
                    LessonType.pdf,
                    LessonType.video,
                    LessonType.resource,
                    LessonType.link,
                    LessonType.activity,
                  ])
                    DropdownMenuItem(
                        value: t,
                        child: Text(t == LessonType.activity
                            ? 'Entrega (actividad)'
                            : lessonTypeLabel(t))),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 12),
              if (type == LessonType.activity)
                TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Instrucciones para el estudiante'))
              else
                TextField(
                    controller: pathCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Ruta del recurso (o URL si es enlace)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                  ctx,
                  Lesson(
                    id: existing?.id ?? data.newId('lec'),
                    title: titleCtrl.text.trim(),
                    type: type,
                    resourcePath: pathCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  ));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Info de fase
// ---------------------------------------------------------------------------

Future<void> _editPhaseInfo(
    BuildContext context, Laboratory lab, int phaseIndex) async {
  final data = context.read<DataProvider>();
  final phase = lab.phases[phaseIndex];
  final titleCtrl = TextEditingController(text: phase.title);
  final descCtrl = TextEditingController(text: phase.description);
  var deadline = phase.deadline;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Editar Fase ${phaseIndex + 1}',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 12),
              HoverCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: now,
                    lastDate: DateTime(now.year + 2),
                    initialDate: DateTime.tryParse(deadline) ?? now,
                  );
                  if (picked != null) {
                    setState(() => deadline = picked.toIso8601String());
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Text(deadline.isEmpty
                        ? 'Fecha límite: sin definir'
                        : 'Fecha límite: ${DateFormat('d MMM yyyy').format(DateTime.parse(deadline))}'),
                    const Spacer(),
                    if (deadline.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => setState(() => deadline = ''),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                  'Al acercarse (o pasar) la fecha, se avisa por notificación a los estudiantes que aún no completan la fase y a sus Mentores.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              phase.title = titleCtrl.text.trim();
              phase.description = descCtrl.text.trim();
              phase.deadline = deadline;
              await data.saveLab(lab);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
