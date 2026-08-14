import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/link_to_ruta_dialog.dart';
import '../../widgets/portal_shell.dart';
import '../lxd/course_editor_view.dart';
import '../lxd/course_tracking_view.dart';
import '../shared/projects_directory_view.dart' show ProjectDetailView;
import '../shared/student_detail_view.dart';
import 'lab_ruta_editor.dart';

// ---------------------------------------------------------------------------
// Proyectos
// ---------------------------------------------------------------------------

class AdminProjects extends StatelessWidget {
  const AdminProjects({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Proyectos',
      subtitle:
          'Cada proyecto define problema, solución, comunidad, ODS, etapa e indicadores',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo proyecto'),
          onPressed: () => _editProject(context, null),
        ),
      ],
      children: [
        if (data.projects.isEmpty)
          const EmptyState(
              icon: Icons.lightbulb_outline, message: 'No hay proyectos.')
        else
          ...data.projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HoverCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(name: '${AppRoutes.projects}/${p.id}'),
                          builder: (_) => ProjectDetailView(projectId: p.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                          ),
                          StatusChip(
                              label: p.stage,
                              color: AppColors.gold,
                              icon: Icons.flag_outlined),
                          const SizedBox(width: 8),
                          if (p.expoEnabled)
                            const StatusChip(
                                label: 'NATIONAL EXPO',
                                color: AppColors.statusGood,
                                icon: Icons.emoji_events_outlined),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.gold,
                            onPressed: () => _editProject(context, p),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.delete_outline, size: 18),
                            color: AppColors.statusCritical,
                            onPressed: () async {
                              if (await confirmDialog(context,
                                  'Eliminar proyecto', '¿Eliminar "${p.name}"?')) {
                                await data.deleteProject(p.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(p.description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('Problema: ${p.problem}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Solución: ${p.solution}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Comunidad: ${p.community}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Indicadores: ${p.impactIndicators}',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final o in p.ods)
                            Chip(
                                label: Text(o,
                                    style: const TextStyle(fontSize: 11))),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _editProject(BuildContext context, Project? project) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController(text: project?.name ?? '');
    final descCtrl =
        TextEditingController(text: project?.description ?? '');
    final problemCtrl =
        TextEditingController(text: project?.problem ?? '');
    final solutionCtrl =
        TextEditingController(text: project?.solution ?? '');
    final communityCtrl =
        TextEditingController(text: project?.community ?? '');
    final indicatorsCtrl =
        TextEditingController(text: project?.impactIndicators ?? '');
    var stage = project?.stage ?? projectStages.first;
    var expoEnabled = project?.expoEnabled ?? false;
    final selectedOds = {...(project?.ods ?? <String>[])};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(project == null ? 'Nuevo proyecto' : 'Editar proyecto',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Descripción')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: problemCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Problema que resuelve')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: solutionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Solución propuesta')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: communityCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Comunidad beneficiada')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: indicatorsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Indicadores de impacto')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    decoration:
                        const InputDecoration(labelText: 'Etapa actual'),
                    items: [
                      for (final s in projectStages)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => stage = v!),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Habilitar RUTA NATIONAL EXPO',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                        'Activa el curso colaborativo para el equipo de este proyecto',
                        style: TextStyle(fontSize: 12)),
                    value: expoEnabled,
                    activeThumbColor: AppColors.gold,
                    onChanged: (v) => setState(() => expoEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('ODS relacionados',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final o in odsList)
                        FilterChip(
                          label: Text(o.split(':').first,
                              style: const TextStyle(fontSize: 11)),
                          tooltip: o,
                          selected: selectedOds.contains(o),
                          selectedColor:
                              AppColors.gold.withValues(alpha: 0.25),
                          onSelected: (sel) => setState(() =>
                              sel ? selectedOds.add(o) : selectedOds.remove(o)),
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
                if (nameCtrl.text.trim().isEmpty) return;
                final saved = Project(
                  id: project?.id ?? data.newId('prj'),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  problem: problemCtrl.text.trim(),
                  solution: solutionCtrl.text.trim(),
                  community: communityCtrl.text.trim(),
                  ods: selectedOds.toList(),
                  stage: stage,
                  impactIndicators: indicatorsCtrl.text.trim(),
                  expoEnabled: expoEnabled,
                  createdAt: project?.createdAt ?? DateTime.now(),
                );
                await data.saveProject(saved);
                // Al habilitar EXPO se crea el curso RUTA del proyecto si falta
                if (expoEnabled &&
                    !data.courses.any(
                        (c) => c.isRutaExpo && c.projectId == saved.id)) {
                  await data.saveCourse(Course(
                    id: data.newId('crs_expo'),
                    name: 'RUTA NATIONAL EXPO — ${saved.name}',
                    description:
                        'Preparación colaborativa del equipo para National Expo.',
                    isRutaExpo: true,
                    projectId: saved.id,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grupos
// ---------------------------------------------------------------------------

class AdminGroups extends StatelessWidget {
  const AdminGroups({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Grupos',
      subtitle:
          'Cada grupo tiene un proyecto, una universidad, un asesor y sus estudiantes',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.group_add, size: 18),
          label: const Text('Nuevo grupo'),
          onPressed: () => _editGroup(context, null),
        ),
      ],
      children: [
        if (data.groups.isEmpty)
          const EmptyState(
              icon: Icons.groups_outlined, message: 'No hay grupos.')
        else
          ...data.groups.map((g) {
            final project = data.projectById(g.projectId);
            final advisor = data.userById(g.advisorId);
            final members = g.studentIds
                .map((id) => data.userById(id)?.name ?? '?')
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                onTap: () => _editGroup(context, g),
                child: Row(
                  children: [
                    const Icon(Icons.groups,
                        color: AppColors.gold, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Proyecto: ${project?.name ?? '—'} · '
                            'Universidad: ${g.university} · '
                            'Asesor: ${advisor?.name ?? '—'}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text('Integrantes: $members',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.gold,
                      onPressed: () => _editGroup(context, g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.statusCritical,
                      onPressed: () async {
                        if (await confirmDialog(context, 'Eliminar grupo',
                            '¿Eliminar "${g.name}"?')) {
                          await data.deleteGroup(g.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _editGroup(BuildContext context, Group? group) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final universityCtrl =
        TextEditingController(text: group?.university ?? '');
    String? projectId = group?.projectId;
    String? advisorId =
        (group?.advisorId.isEmpty ?? true) ? null : group!.advisorId;
    final selected = {...(group?.studentIds ?? <String>[])};
    final advisors = data.usersByRole(Roles.advisor);
    // Los grupos/proyectos son un concepto de Enactus: Open Learning no
    // participa en equipos ni proyectos. Alumni cuenta igual que estudiante
    // (ver Roles.isStudentLike).
    final students = data.studentsAndAlumni
        .where((s) => s.studentType == StudentType.enactus)
        .toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(group == null ? 'Nuevo grupo' : 'Editar grupo',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nombre del grupo')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: projectId,
                    decoration:
                        const InputDecoration(labelText: 'Proyecto'),
                    items: [
                      for (final p in data.projects)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() => projectId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: universityCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Universidad')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: advisorId,
                    decoration: const InputDecoration(
                        labelText: 'Asesor académico'),
                    items: [
                      for (final a in advisors)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => advisorId = v),
                  ),
                  const SizedBox(height: 14),
                  const Text('Estudiantes del grupo',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in students)
                        FilterChip(
                          label: Text(s.name,
                              style: const TextStyle(fontSize: 12)),
                          selected: selected.contains(s.id),
                          selectedColor:
                              AppColors.gold.withValues(alpha: 0.25),
                          onSelected: (sel) => setState(() =>
                              sel ? selected.add(s.id) : selected.remove(s.id)),
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
                if (nameCtrl.text.trim().isEmpty || projectId == null) {
                  return;
                }
                final saved = Group(
                  id: group?.id ?? data.newId('grp'),
                  name: nameCtrl.text.trim(),
                  projectId: projectId!,
                  university: universityCtrl.text.trim(),
                  advisorId: advisorId ?? '',
                  studentIds: selected.toList(),
                );
                await data.saveGroup(saved);

                // Sincroniza los estudiantes: asigna grupo y curso RUTA EXPO
                final expoCourse = data.courses
                    .where((c) =>
                        c.isRutaExpo && c.projectId == saved.projectId)
                    .toList();
                for (final s in students) {
                  final inGroup = selected.contains(s.id);
                  final wasInGroup = s.groupId == saved.id;
                  if (inGroup) {
                    s.extra['groupId'] = saved.id;
                    if (expoCourse.isNotEmpty &&
                        !s.courseIds.contains(expoCourse.first.id)) {
                      s.courseIds = [...s.courseIds, expoCourse.first.id];
                    }
                    await data.saveUser(s);
                  } else if (wasInGroup) {
                    s.extra['groupId'] = null;
                    await data.saveUser(s);
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asignaciones (cursos, empresa patrocinadora, donante)
// ---------------------------------------------------------------------------

class AdminAssignments extends StatelessWidget {
  const AdminAssignments({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = data.studentsAndAlumni;

    return TabBody(
      title: 'Asignaciones',
      subtitle:
          'Tipo de estudiante y laboratorios (sus cursos son automáticos), empresa patrocinadora y donante',
      children: [
        if (students.isEmpty)
          const EmptyState(
              icon: Icons.assignment_ind_outlined,
              message: 'No hay estudiantes registrados.')
        else
          ...students.map((s) {
            final isOpenLearning = s.studentType == StudentType.openLearning;
            final courses = data
                .coursesForStudent(s)
                .where((c) => !c.isRutaExpo)
                .map((c) => c.name)
                .join(', ');
            final labNames =
                data.labsForStudent(s).map((l) => l.name).join(', ');
            final sponsor =
                s.companyId == null ? null : data.userById(s.companyId!);
            final donor =
                s.donorId == null ? null : data.userById(s.donorId!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StudentDetailView(studentId: s.id))),
                child: Row(
                  children: [
                    InitialsAvatar(s.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              StatusChip(
                                  label: StudentType.label(s.studentType),
                                  color: isOpenLearning
                                      ? AppColors.slateLight
                                      : AppColors.gold,
                                  icon: isOpenLearning
                                      ? Icons.public_outlined
                                      : Icons.science_outlined),
                            ],
                          ),
                          if (!isOpenLearning)
                            Text(
                              'Laboratorios: ${labNames.isEmpty ? 'ninguno' : labNames}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          Text(
                            'Cursos: ${courses.isEmpty ? 'ninguno' : courses}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                          if (!isOpenLearning)
                            Text(
                              'Patrocinador: ${sponsor?.companyName ?? '—'} · '
                              'Donante: ${donor?.name ?? '—'}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Asignar'),
                      onPressed: () => _assign(context, s),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _assign(BuildContext context, AppUser student) async {
    final data = context.read<DataProvider>();
    final companies = data.usersByRole(Roles.company);
    final donors = data.usersByRole(Roles.donor);
    final labs = data.labs;
    final groups = data.groups;
    var studentType = student.studentType;
    final selectedLabIds = {...student.labIds};
    final selectedCourses = {...student.courseIds};
    String? companyId = student.companyId;
    String? donorId = student.donorId;
    String? groupId = student.groupId;

    // Cursos que este diálogo gestiona para el tipo actual (excluye el
    // legado RUTA NATIONAL EXPO, que se conserva pero ya no se edita aquí).
    List<Course> pickableCourses() => data.courses
        .where((c) => !c.isRutaExpo)
        .where((c) =>
            c.isOpenLearning == (studentType == StudentType.openLearning))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isOpenLearning = studentType == StudentType.openLearning;
          return AlertDialog(
            title: Text('Asignaciones de ${student.name}',
                style: const TextStyle(fontSize: 18)),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de estudiante',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in StudentType.all)
                          ChoiceChip(
                            label: Text(StudentType.label(t)),
                            selected: studentType == t,
                            selectedColor:
                                AppColors.gold.withValues(alpha: 0.25),
                            onSelected: (_) => setState(() {
                              studentType = t;
                              // Open Learning no tiene laboratorios ni
                              // patrocinio: son conceptos exclusivos de
                              // Enactus.
                              if (t == StudentType.openLearning) {
                                selectedLabIds.clear();
                                companyId = null;
                                donorId = null;
                                groupId = null;
                              }
                            }),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          isOpenLearning
                              ? 'Solo ve y completa los cursos que le asignes abajo.'
                              : 'Ve Laboratorios y su Ruta de Impacto.',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 16),
                    if (!isOpenLearning) ...[
                      const Text('Laboratorios asignados',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      labs.isEmpty
                          ? const Text('No hay laboratorios creados todavía.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted))
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final l in labs)
                                  FilterChip(
                                    label: Text(l.name,
                                        style: const TextStyle(fontSize: 12)),
                                    selected: selectedLabIds.contains(l.id),
                                    selectedColor: AppColors.gold
                                        .withValues(alpha: 0.25),
                                    onSelected: (sel) => setState(() => sel
                                        ? selectedLabIds.add(l.id)
                                        : selectedLabIds.remove(l.id)),
                                  ),
                              ],
                            ),
                      const SizedBox(height: 16),
                    ],
                    if (isOpenLearning) ...[
                      const Text('Cursos de Open Learning',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      pickableCourses().isEmpty
                          ? const Text(
                              'Aún no hay cursos de Open Learning creados.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted))
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in pickableCourses())
                                  FilterChip(
                                    label: Text(c.name,
                                        style: const TextStyle(fontSize: 12)),
                                    selected: selectedCourses.contains(c.id),
                                    selectedColor: AppColors.gold
                                        .withValues(alpha: 0.25),
                                    onSelected: (sel) => setState(() => sel
                                        ? selectedCourses.add(c.id)
                                        : selectedCourses.remove(c.id)),
                                  ),
                              ],
                            ),
                    ] else ...[
                      const Text(
                          'Cursos (automáticos, según los laboratorios elegidos arriba)',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        final autoCourses = data.courses
                            .where((c) => selectedLabIds.contains(c.labId))
                            .toList();
                        if (autoCourses.isEmpty) {
                          return const Text(
                              'Sin cursos todavía: elige un laboratorio arriba o el laboratorio elegido no tiene cursos.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted));
                        }
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in autoCourses)
                              Chip(
                                avatar: const Icon(Icons.check, size: 14),
                                label: Text(c.name,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                        );
                      }),
                    ],
                    if (!isOpenLearning) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: companyId,
                        decoration: const InputDecoration(
                            labelText: 'Empresa patrocinadora'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Ninguna')),
                          for (final c in companies)
                            DropdownMenuItem(
                                value: c.id, child: Text(c.companyName)),
                        ],
                        onChanged: (v) => setState(() => companyId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: donorId,
                        decoration:
                            const InputDecoration(labelText: 'Donante'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Ninguno')),
                          for (final d in donors)
                            DropdownMenuItem(
                                value: d.id, child: Text(d.name)),
                        ],
                        onChanged: (v) => setState(() => donorId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: groupId,
                        decoration: const InputDecoration(
                            labelText: 'Proyecto (equipo)',
                            helperText:
                                'Da acceso al detalle del proyecto y a los avances de todo el equipo'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Ninguno')),
                          for (final g in groups)
                            DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                    '${g.name} · ${data.projectById(g.projectId)?.name ?? "Proyecto eliminado"}')),
                        ],
                        onChanged: (v) => setState(() => groupId = v),
                      ),
                    ],
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
                  // Los cursos de Open Learning sí se asignan a mano aquí.
                  // Los de laboratorio son automáticos por labIds: no se
                  // tocan courseIds para Enactus (se conserva lo que ya
                  // tuviera, como el legado RUTA EXPO — no se pierde nada).
                  if (isOpenLearning) {
                    final managedIds =
                        pickableCourses().map((c) => c.id).toSet();
                    final untouchedIds = student.courseIds
                        .where((id) => !managedIds.contains(id))
                        .toSet();
                    student.courseIds = [
                      ...untouchedIds,
                      ...selectedCourses.where(managedIds.contains),
                    ];
                  }
                  student.studentType = studentType;
                  student.labIds = isOpenLearning ? [] : selectedLabIds.toList();
                  student.extra['companyId'] = isOpenLearning ? null : companyId;
                  student.extra['donorId'] = isOpenLearning ? null : donorId;

                  // Sincroniza el equipo/proyecto en ambas direcciones,
                  // igual que ya hace "Grupos" al editar desde el otro
                  // lado — incluye el curso RUTA NATIONAL EXPO automático.
                  final newGroupId = isOpenLearning ? null : groupId;
                  if (newGroupId != student.groupId) {
                    final oldGroup = data.groupById(student.groupId);
                    if (oldGroup != null && oldGroup.id != newGroupId) {
                      oldGroup.studentIds = oldGroup.studentIds
                          .where((id) => id != student.id)
                          .toList();
                      await data.saveGroup(oldGroup);
                    }
                    if (newGroupId != null) {
                      final newGroup = data.groupById(newGroupId);
                      if (newGroup != null &&
                          !newGroup.studentIds.contains(student.id)) {
                        newGroup.studentIds = [
                          ...newGroup.studentIds,
                          student.id
                        ];
                        await data.saveGroup(newGroup);
                      }
                      final expoCourse = data.courses
                          .where((c) =>
                              c.isRutaExpo &&
                              c.projectId == newGroup?.projectId)
                          .toList();
                      if (expoCourse.isNotEmpty &&
                          !student.courseIds.contains(expoCourse.first.id)) {
                        student.courseIds = [
                          ...student.courseIds,
                          expoCourse.first.id
                        ];
                      }
                    }
                  }
                  student.extra['groupId'] = newGroupId;

                  await data.saveUser(student);
                  await data.notify(student.id, 'Asignaciones actualizadas',
                      'Tu administrador actualizó tus laboratorios, cursos y beneficios.');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Laboratorios (solo Super Admin)
// ---------------------------------------------------------------------------

class AdminLabs extends StatelessWidget {
  const AdminLabs({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Laboratorios',
      subtitle:
          'Áreas de conocimiento de la plataforma: fases, módulos y objetivos de su Ruta de Impacto',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo laboratorio'),
          onPressed: () => _editLab(context, null),
        ),
      ],
      children: [
        ...data.labs.map((l) {
          final mentorNames = l.mentorIds
              .map((id) => data.userById(id)?.name)
              .whereType<String>()
              .join(', ');
          // Combina el patrocinador designado a mano con las empresas que
          // ya tienen presencia real vía un LXD suyo (ver companiesForLab):
          // el campo manual no reemplaza la relación automática, la
          // complementa (ver sponsoredHoursByCompany).
          final sponsorNames = {
            for (final c in data.companiesForLab(l.id)) c.companyName,
            if (l.sponsorCompanyId.isNotEmpty)
              data.userById(l.sponsorCompanyId)?.companyName ?? '',
          }..removeWhere((n) => n.isEmpty);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HoverCard(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => LabRutaEditorView(labId: l.id))),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: AppColors.gold, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(l.description,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        Text(
                          'Mentores: ${mentorNames.isEmpty ? '—' : mentorNames} · '
                          'Patrocinador: ${sponsorNames.isEmpty ? '—' : sponsorNames.join(', ')} · '
                          '${data.coursesByLab(l.id).length} cursos',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_events_outlined, size: 18),
                    color: AppColors.gold,
                    tooltip: 'Editar Ruta de Impacto',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LabRutaEditorView(labId: l.id))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.gold,
                    tooltip: 'Editar datos del laboratorio',
                    onPressed: () => _editLab(context, l),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.statusCritical,
                    onPressed: () async {
                      if (await confirmDialog(context,
                          'Eliminar laboratorio', '¿Eliminar "${l.name}" y dejar sus cursos sin laboratorio?')) {
                        await data.deleteLab(l.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _editLab(BuildContext context, Laboratory? lab) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController(text: lab?.name ?? '');
    final descCtrl = TextEditingController(text: lab?.description ?? '');
    final objCtrl = TextEditingController(text: lab?.objectives ?? '');
    final selectedMentorIds = {...(lab?.mentorIds ?? <String>[])};
    String? sponsorId =
        (lab?.sponsorCompanyId.isEmpty ?? true) ? null : lab!.sponsorCompanyId;
    final mentors = data.usersByRole(Roles.mentor);
    final companies = data.usersByRole(Roles.company);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(lab == null ? 'Nuevo laboratorio' : 'Editar laboratorio',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Descripción')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: objCtrl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Objetivos')),
                  const SizedBox(height: 14),
                  const Text('Mentores encargados (pueden compartir estudiantes)',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  mentors.isEmpty
                      ? const Text('Aún no hay cuentas de Mentor creadas.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final m in mentors)
                              FilterChip(
                                label: Text(m.name,
                                    style: const TextStyle(fontSize: 12)),
                                selected: selectedMentorIds.contains(m.id),
                                selectedColor:
                                    AppColors.gold.withValues(alpha: 0.25),
                                onSelected: (sel) => setState(() => sel
                                    ? selectedMentorIds.add(m.id)
                                    : selectedMentorIds.remove(m.id)),
                              ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: sponsorId,
                    decoration: const InputDecoration(
                        labelText: 'Empresa patrocinadora'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Ninguna')),
                      for (final c in companies)
                        DropdownMenuItem(
                            value: c.id, child: Text(c.companyName)),
                    ],
                    onChanged: (v) => setState(() => sponsorId = v),
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
                if (nameCtrl.text.trim().isEmpty) return;
                await data.saveLab(Laboratory(
                  id: lab?.id ?? data.newId('lab'),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  objectives: objCtrl.text.trim(),
                  mentorIds: selectedMentorIds.toList(),
                  sponsorCompanyId: sponsorId ?? '',
                  // Conserva las fases ya configuradas: si no se pasan,
                  // el constructor las resetearía a 3 fases vacías.
                  phases: lab?.phases,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cursos: todos los cursos de la plataforma, sin importar qué LXD o
// empresa los creó — el Admin ve y administra todo.
// ---------------------------------------------------------------------------

class AdminCourses extends StatefulWidget {
  const AdminCourses({super.key});

  @override
  State<AdminCourses> createState() => _AdminCoursesState();
}

class _AdminCoursesState extends State<AdminCourses> {
  String _filter = 'todos';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    var courses = data.courses;
    if (_filter == 'enactus') {
      courses = courses.where((c) => !c.isOpenLearning).toList();
    } else if (_filter == 'open') {
      courses = courses.where((c) => c.isOpenLearning).toList();
    } else if (_filter == 'sinVincular') {
      courses = courses
          .where((c) => !c.isOpenLearning && linkedModuleLabel(data, c) == null)
          .toList();
    }

    return TabBody(
      title: 'Cursos',
      subtitle:
          'Todos los cursos de la plataforma, sin importar qué LXD o empresa los creó',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final f in const {
              'todos': 'Todos',
              'enactus': 'Enactus',
              'open': 'Open Learning',
              'sinVincular': 'Sin vincular a Ruta',
            }.entries)
              ChoiceChip(
                label: Text(f.value),
                selected: _filter == f.key,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _filter = f.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          const EmptyState(
              icon: Icons.video_library_outlined,
              message: 'No hay cursos para este filtro.')
        else
          ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminCourseCard(course: c),
              )),
      ],
    );
  }
}

class _AdminCourseCard extends StatelessWidget {
  final Course course;
  const _AdminCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final stats = data.courseStats(course);
    final creator =
        course.creatorId.isEmpty ? null : data.userById(course.creatorId);
    final company = creator?.companyId == null
        ? null
        : data.userById(creator!.companyId!);

    final (statusColor, statusIcon) = switch (course.status) {
      'Publicado' => (AppColors.statusGood, Icons.public),
      'Archivado' => (AppColors.statusSerious, Icons.archive_outlined),
      _ => (AppColors.statusWarning, Icons.edit_note),
    };

    return HoverCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CourseEditorView(courseId: course.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_outlined,
                  color: AppColors.gold, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                        creator == null
                            ? 'Sin creador asignado'
                            : 'LXD: ${creator.name}'
                                '${company == null ? '' : ' · ${company.companyName}'}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusChip(
                  label: course.isOpenLearning ? 'Open Learning' : 'Enactus',
                  color: course.isOpenLearning
                      ? AppColors.slateLight
                      : AppColors.gold,
                  icon: course.isOpenLearning
                      ? Icons.public_outlined
                      : Icons.science_outlined),
              const SizedBox(width: 8),
              StatusChip(
                  label: course.status, color: statusColor, icon: statusIcon),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _miniStat(Icons.people_outline, '${stats.enrolled} inscritos'),
              _miniStat(Icons.check_circle_outline,
                  '${stats.completed} completados'),
              _miniStat(Icons.trending_up,
                  '${(stats.avgProgress * 100).round()}% avance'),
              _miniStat(Icons.view_module_outlined,
                  '${course.modules.length} módulos · ${course.lessonCount} lecciones'),
            ],
          ),
          if (!course.isOpenLearning) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final linked = linkedModuleLabel(data, course);
              return Row(
                children: [
                  Icon(
                      linked == null
                          ? Icons.link_off
                          : Icons.check_circle_outline,
                      size: 14,
                      color: linked == null
                          ? AppColors.textMuted
                          : AppColors.statusGood),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                        linked ?? 'Sin vincular a ningún módulo todavía',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Constructor'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseEditorView(courseId: course.id)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('Seguimiento'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseTrackingView(courseId: course.id)),
                ),
              ),
              if (!course.isOpenLearning) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.route_outlined, size: 16),
                  label: const Text('Vincular a Ruta de Impacto'),
                  onPressed: () => showLinkToRutaDialog(context, course),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar curso',
                onPressed: () async {
                  if (await confirmDoubleDialog(
                      context,
                      'Eliminar curso',
                      'Vas a eliminar "${course.name}" con todos sus '
                      'módulos, lecciones y configuración.')) {
                    await data.deleteCourse(course.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Evidencias para donantes
// ---------------------------------------------------------------------------

class AdminEvidences extends StatelessWidget {
  const AdminEvidences({super.key});

  static const _types = ['historia', 'testimonio', 'reporte', 'foto', 'video'];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Evidencias para Donantes',
      subtitle:
          'Historias, testimonios y reportes visibles en el portal de cada donante',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva evidencia'),
          onPressed: () => _editEvidence(context),
        ),
      ],
      children: [
        if (data.evidences.isEmpty)
          const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: 'No hay evidencias cargadas.')
        else
          ...data.evidences.map((e) {
            final donor = data.userById(e.donorId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                onTap: () => _showEvidenceDetail(context, e, donor),
                child: Row(
                  children: [
                    Icon(_typeIcon(e.type),
                        color: AppColors.gold, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.title} (${e.type})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            'Donante: ${donor?.name ?? '—'} · ${e.description}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.statusCritical,
                      onPressed: () async {
                        if (await confirmDialog(context,
                            'Eliminar evidencia', '¿Eliminar "${e.title}"?')) {
                          await data.deleteEvidence(e.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
        'foto' => Icons.photo_outlined,
        'video' => Icons.videocam_outlined,
        'testimonio' => Icons.format_quote_outlined,
        'reporte' => Icons.description_outlined,
        _ => Icons.auto_stories_outlined,
      };

  /// La tarjeta trunca la descripción a 2 líneas — este diálogo muestra el
  /// texto completo (dato ya existente, sin campo nuevo).
  Future<void> _showEvidenceDetail(
      BuildContext context, Evidence e, AppUser? donor) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(_typeIcon(e.type), color: AppColors.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(e.title)),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo: ${e.type}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              Text('Donante: ${donor?.name ?? '—'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              Text('Fecha: ${DateFormat('d MMM yyyy', 'es').format(e.date)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 12),
              Text(e.description, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _editEvidence(BuildContext context) async {
    final data = context.read<DataProvider>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final donors = data.usersByRole(Roles.donor);
    String? donorId = donors.isEmpty ? null : donors.first.id;
    var type = _types.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title:
              const Text('Nueva evidencia', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: donorId,
                  decoration: const InputDecoration(labelText: 'Donante'),
                  items: [
                    for (final d in donors)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() => donorId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final t in _types)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Descripción')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || donorId == null) {
                  return;
                }
                await data.saveEvidence(Evidence(
                  id: data.newId('ev'),
                  donorId: donorId!,
                  type: type,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
