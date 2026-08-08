import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/forum_view.dart';
import '../shared/projects_directory_view.dart';

/// Portal del Asesor Académico: ve el progreso completo (cursos, fases y
/// laboratorios) de los estudiantes de SU universidad, y crea/edita los
/// proyectos de sus equipos.
class AdvisorPortal extends StatelessWidget {
  const AdvisorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Asesor Académico',
      tabs: [
        PortalTab(
            label: 'Dashboard Universidad',
            icon: Icons.account_balance_outlined,
            builder: (_) => const _AdvisorDashboard()),
        PortalTab(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _AdvisorCalendar()),
        PortalTab(
            label: 'Seguimiento Estudiantes',
            icon: Icons.person_search_outlined,
            builder: (_) => const _AdvisorStudents()),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const _AdvisorProjects()),
        PortalTab(
            label: 'Directorio de Proyectos',
            icon: Icons.explore_outlined,
            builder: (_) => const ProjectsDirectoryView()),
        PortalTab(
            label: 'Foro',
            icon: Icons.forum_outlined,
            builder: (_) => const ForumView()),
      ],
    );
  }
}

class _AdvisorDashboard extends StatelessWidget {
  const _AdvisorDashboard();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final advisor = context.watch<AuthProvider>().currentUser!;
    final students = data.studentsForAdvisor(advisor);
    final myGroups = data.groups
        .where((g) => g.university == advisor.university)
        .toList();
    final projectIds = myGroups.map((g) => g.projectId).toSet();
    final activeLabs = students.expand((s) => s.labIds).toSet().length;
    final avgProgress = students.isEmpty
        ? 0.0
        : students.fold<double>(
                0, (acc, s) => acc + data.overallProgress(s)) /
            students.length;

    return TabBody(
      title: advisor.university,
      subtitle: 'Resumen de la actividad Enactus en tu universidad',
      children: [
        StatRow(tiles: [
          StatTile(
              value: '${students.length}',
              label: 'Estudiantes activos',
              icon: Icons.school_outlined),
          StatTile(
              value: '${projectIds.length}',
              label: 'Proyectos',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${(avgProgress * 100).round()}%',
              label: 'Avance promedio',
              icon: Icons.trending_up),
          StatTile(
              value: '$activeLabs',
              label: 'Laboratorios activos',
              icon: Icons.science_outlined),
        ]),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Avance promedio por proyecto (%)',
          child: myGroups.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  message: 'Sin equipos registrados')
              : SimpleBarChart(
                  maxY: 100,
                  data: [
                    for (final g in myGroups)
                      (
                        label: data.projectById(g.projectId)?.name ?? g.name,
                        value: _groupAvg(data, g) * 100,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  double _groupAvg(DataProvider data, Group g) {
    if (g.studentIds.isEmpty) return 0;
    var sum = 0.0;
    var count = 0;
    for (final id in g.studentIds) {
      final s = data.userById(id);
      if (s != null) {
        sum += data.overallProgress(s);
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }
}

class _AdvisorCalendar extends StatelessWidget {
  const _AdvisorCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final advisor = context.watch<AuthProvider>().currentUser!;
    return TabBody(
      title: 'Calendario',
      subtitle:
          'Sesiones sincrónicas y eventos de Ruta de Impacto de los estudiantes de tu universidad',
      children: [
        CalendarView(events: data.calendarEventsFor(advisor)),
      ],
    );
  }
}

class _AdvisorStudents extends StatefulWidget {
  const _AdvisorStudents();

  @override
  State<_AdvisorStudents> createState() => _AdvisorStudentsState();
}

class _AdvisorStudentsState extends State<_AdvisorStudents> {
  String _search = '';
  String _riskFilter = 'todos'; // todos | riesgo | al_dia

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final advisor = context.watch<AuthProvider>().currentUser!;
    var students = data.studentsForAdvisor(advisor);

    if (_search.isNotEmpty) {
      final f = _search.toLowerCase();
      students = students
          .where((s) =>
              s.name.toLowerCase().contains(f) ||
              s.career.toLowerCase().contains(f))
          .toList();
    }
    if (_riskFilter == 'riesgo') {
      students = students
          .where((s) => data.overallProgress(s) < 0.3)
          .toList();
    } else if (_riskFilter == 'al_dia') {
      students = students
          .where((s) => data.overallProgress(s) >= 0.3)
          .toList();
    }

    return TabBody(
      title: 'Seguimiento de Estudiantes',
      subtitle:
          'Estudiantes de ${advisor.university} — progreso, entregas y alertas',
      children: [
        Row(
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o programa',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('Todos'),
              selected: _riskFilter == 'todos',
              selectedColor: AppColors.gold.withValues(alpha: 0.25),
              onSelected: (_) => setState(() => _riskFilter = 'todos'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('En riesgo'),
              selected: _riskFilter == 'riesgo',
              selectedColor: AppColors.statusCritical.withValues(alpha: 0.25),
              onSelected: (_) => setState(() => _riskFilter = 'riesgo'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Al día'),
              selected: _riskFilter == 'al_dia',
              selectedColor: AppColors.statusGood.withValues(alpha: 0.25),
              onSelected: (_) => setState(() => _riskFilter = 'al_dia'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (students.isEmpty)
          const EmptyState(
              icon: Icons.person_search_outlined,
              message: 'No hay estudiantes que coincidan con el filtro.')
        else
          ...students.map((s) => _StudentRow(student: s)),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  final AppUser student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final group = data.groupById(student.groupId);
    final project =
        group == null ? null : data.projectById(group.projectId);
    final progress = data.overallProgress(student);
    final atRisk = progress < 0.3;
    final labs = data.labsForStudent(student);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(student.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      Text(
                        '${student.career} · '
                        'Proyecto: ${project?.name ?? '—'} · '
                        'Etapa: ${project?.stage ?? '—'}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (atRisk)
                  const StatusChip(
                      label: 'Riesgo de abandono',
                      color: AppColors.statusCritical,
                      icon: Icons.warning_amber_outlined)
                else
                  const StatusChip(
                      label: 'Al día',
                      color: AppColors.statusGood,
                      icon: Icons.check),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                    width: 120,
                    child: Text('Progreso en cursos',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted))),
                Expanded(
                  child: ThinProgressBar(
                      value: progress,
                      color: atRisk
                          ? AppColors.statusCritical
                          : AppColors.gold),
                ),
              ],
            ),
            // Detalle por curso
            for (final c in data.coursesForStudent(student))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: ThinProgressBar(
                          value: data.courseProgress(student.id, c),
                          color: AppColors.slateLight),
                    ),
                  ],
                ),
              ),
            // Ruta de Impacto: fase por laboratorio
            if (labs.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final lab in labs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(lab.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var i = 0; i < lab.phases.length; i++)
                            PhaseBadge(
                              label: 'Fase ${i + 1}',
                              complete: data.isPhaseComplete(
                                  student.id, lab.id, lab.phases[i]),
                              unlocked: data.isPhaseUnlocked(
                                  student.id, lab.id, lab, i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proyectos: el Asesor crea y edita los proyectos de los equipos de su
// universidad (Admin conserva su propia vista global de todos los
// proyectos, en la pestaña "Proyectos" de su portal).
// ---------------------------------------------------------------------------

class _AdvisorProjects extends StatelessWidget {
  const _AdvisorProjects();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final advisor = context.watch<AuthProvider>().currentUser!;
    final myGroups =
        data.groups.where((g) => g.university == advisor.university).toList();
    final projectIds = myGroups.map((g) => g.projectId).toSet();
    final projects = data.projects.where((p) => projectIds.contains(p.id)).toList();

    return TabBody(
      title: 'Proyectos',
      subtitle: 'Proyectos de los equipos de ${advisor.university}',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo proyecto'),
          onPressed: () => _editProject(context, null),
        ),
      ],
      children: [
        if (projects.isEmpty)
          const EmptyState(
              icon: Icons.lightbulb_outline,
              message:
                  'Aún no hay proyectos. Créalos aquí y luego vincúlalos a un equipo desde "Grupos" (Admin).')
        else
          ...projects.map((p) => Padding(
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                          ),
                          StatusChip(
                              label: p.stage,
                              color: AppColors.gold,
                              icon: Icons.flag_outlined),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.gold,
                            onPressed: () => _editProject(context, p),
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
    final descCtrl = TextEditingController(text: project?.description ?? '');
    final problemCtrl = TextEditingController(text: project?.problem ?? '');
    final solutionCtrl = TextEditingController(text: project?.solution ?? '');
    final communityCtrl =
        TextEditingController(text: project?.community ?? '');
    final indicatorsCtrl =
        TextEditingController(text: project?.impactIndicators ?? '');
    var stage = project?.stage ?? projectStages.first;
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
                  expoEnabled: project?.expoEnabled ?? false,
                );
                await data.saveProject(saved);
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
