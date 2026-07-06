import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Portal del Asesor Académico: solo ve estudiantes de SU universidad.
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
            label: 'Seguimiento Estudiantes',
            icon: Icons.person_search_outlined,
            builder: (_) => const _AdvisorStudents()),
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
    final expoTeams = myGroups.where((g) {
      final p = data.projectById(g.projectId);
      return p?.expoEnabled ?? false;
    }).length;
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
              value: '$expoTeams',
              label: 'Equipos en National Expo',
              icon: Icons.emoji_events_outlined),
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
    final expoSubmissions =
        group == null ? 0 : data.submissionsForGroup(group.id).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.slate,
                  child: Text(student.name[0],
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700)),
                ),
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
                        'Etapa: ${project?.stage ?? '—'} · '
                        'Entregas EXPO del equipo: $expoSubmissions',
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
                        c.isRutaExpo ? 'RUTA EXPO' : c.name,
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
          ],
        ),
      ),
    );
  }
}
