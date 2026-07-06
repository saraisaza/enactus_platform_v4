import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
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
    final students = data.usersByRole(Roles.student);

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
    final students = data.usersByRole(Roles.student);

    return TabBody(
      title: 'Asignaciones',
      subtitle:
          'Asigna cursos de laboratorio, empresa patrocinadora y donante a cada estudiante',
      children: [
        if (students.isEmpty)
          const EmptyState(
              icon: Icons.assignment_ind_outlined,
              message: 'No hay estudiantes registrados.')
        else
          ...students.map((s) {
            final courses = data
                .coursesForStudent(s)
                .where((c) => !c.isRutaExpo)
                .map((c) => c.name)
                .join(', ');
            final sponsor =
                s.companyId == null ? null : data.userById(s.companyId!);
            final donor =
                s.donorId == null ? null : data.userById(s.donorId!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.slate,
                      child: Text(s.name[0],
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Cursos: ${courses.isEmpty ? 'ninguno' : courses}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
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
    final labCourses =
        data.courses.where((c) => !c.isRutaExpo).toList();
    final companies = data.usersByRole(Roles.company);
    final donors = data.usersByRole(Roles.donor);
    final selectedCourses = {...student.courseIds};
    String? companyId = student.companyId;
    String? donorId = student.donorId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Asignaciones de ${student.name}',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cursos de laboratorio',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in labCourses)
                        FilterChip(
                          label: Text(c.name,
                              style: const TextStyle(fontSize: 12)),
                          selected: selectedCourses.contains(c.id),
                          selectedColor:
                              AppColors.gold.withValues(alpha: 0.25),
                          onSelected: (sel) => setState(() => sel
                              ? selectedCourses.add(c.id)
                              : selectedCourses.remove(c.id)),
                        ),
                    ],
                  ),
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
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => donorId = v),
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
                // Conserva los cursos RUTA EXPO ya asignados
                final expoIds = student.courseIds
                    .where((id) =>
                        data.courseById(id)?.isRutaExpo ?? false)
                    .toSet();
                student.courseIds =
                    [...expoIds, ...selectedCourses.where((id) =>
                        !(data.courseById(id)?.isRutaExpo ?? false))];
                student.extra['companyId'] = companyId;
                student.extra['donorId'] = donorId;
                await data.saveUser(student);
                await data.notify(student.id, 'Asignaciones actualizadas',
                    'Tu administrador actualizó tus cursos y beneficios.');
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
// Laboratorios (solo Super Admin)
// ---------------------------------------------------------------------------

class AdminLabs extends StatelessWidget {
  const AdminLabs({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Laboratorios',
      subtitle: 'Áreas de conocimiento de la plataforma (solo Super Admin)',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo laboratorio'),
          onPressed: () => _editLab(context, null),
        ),
      ],
      children: [
        ...data.labs.map((l) {
          final mentor = data.userById(l.mentorId);
          final sponsor = l.sponsorCompanyId.isEmpty
              ? null
              : data.userById(l.sponsorCompanyId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HoverCard(
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
                          'Mentor: ${mentor?.name ?? '—'} · '
                          'Patrocinador: ${sponsor?.companyName ?? '—'} · '
                          '${data.coursesByLab(l.id).length} cursos',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.gold,
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
    String? mentorId = (lab?.mentorId.isEmpty ?? true) ? null : lab!.mentorId;
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: mentorId,
                    decoration: const InputDecoration(
                        labelText: 'Mentor encargado'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin asignar')),
                      for (final m in mentors)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (v) => setState(() => mentorId = v),
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
                  mentorId: mentorId ?? '',
                  sponsorCompanyId: sponsorId ?? '',
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
