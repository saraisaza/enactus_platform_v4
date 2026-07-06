import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Portal corporativo: indicadores de impacto y laboratorio patrocinado.
class CompanyPortal extends StatelessWidget {
  const CompanyPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Corporativo',
      tabs: [
        PortalTab(
            label: 'Impacto',
            icon: Icons.insights_outlined,
            builder: (_) => const _CompanyDashboard()),
        PortalTab(
            label: 'Mi Laboratorio',
            icon: Icons.science_outlined,
            builder: (_) => const _CompanyLab()),
        PortalTab(
            label: 'Estudiantes Patrocinados',
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const _CompanyStudents()),
      ],
    );
  }
}

class _CompanyDashboard extends StatefulWidget {
  const _CompanyDashboard();

  @override
  State<_CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<_CompanyDashboard> {
  String _period = 'Todo 2026';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final sponsored = data.studentsForCompany(company.id);
    final universities = sponsored.map((s) => s.university).toSet()
      ..remove('');
    final certCount = sponsored.fold<int>(
        0, (acc, s) => acc + data.certificatesForStudent(s.id).length);
    final projects = sponsored
        .map((s) => data.groupById(s.groupId)?.projectId)
        .whereType<String>()
        .toSet();
    // Horas de formación estimadas: lecciones completadas * 1.5 h
    final lessonsDone = sponsored.fold<int>(0, (acc, s) {
      var done = 0;
      for (final c in data.coursesForStudent(s)) {
        done += data.progressFor(s.id, c.id).completedLessonIds.length;
      }
      return acc + done;
    });

    return TabBody(
      title: 'Impacto de ${company.companyName}',
      subtitle: 'Resultados de tu alianza con Enactus Colombia',
      actions: [
        DropdownButton<String>(
          value: _period,
          dropdownColor: AppColors.surfaceAlt,
          items: const [
            DropdownMenuItem(value: 'Todo 2026', child: Text('Todo 2026')),
            DropdownMenuItem(value: 'Q1 2026', child: Text('Q1 2026')),
            DropdownMenuItem(value: 'Q2 2026', child: Text('Q2 2026')),
          ],
          onChanged: (v) => setState(() => _period = v!),
        ),
      ],
      children: [
        StatRow(tiles: [
          StatTile(
              value: '${sponsored.length}',
              label: 'Estudiantes impactados',
              icon: Icons.school_outlined,
              detail: '$certCount certificados\n'
                  '${projects.length} proyectos\n'
                  '${universities.length} universidades'),
          StatTile(
              value: '${universities.length}',
              label: 'Universidades participantes',
              icon: Icons.account_balance_outlined,
              detail: universities.isEmpty
                  ? 'Sin universidades aún'
                  : universities.join('\n')),
          StatTile(
              value: '${(lessonsDone * 1.5).round()} h',
              label: 'Horas de formación',
              icon: Icons.schedule_outlined,
              detail:
                  '$lessonsDone lecciones completadas × 1.5 h estimadas'),
          StatTile(
              value: '$certCount',
              label: 'Certificaciones emitidas',
              icon: Icons.workspace_premium_outlined,
              detail: 'Certificados PDF emitidos a tus estudiantes'),
          StatTile(
              value: '${sponsored.length * 2}',
              label: 'Mentorías realizadas',
              icon: Icons.psychology_outlined,
              trend: '↑ +8 este mes'),
          StatTile(
              value: '${projects.length}',
              label: 'Proyectos apoyados',
              icon: Icons.lightbulb_outline),
        ]),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Mentorías realizadas por mes ($_period)',
          child: const SimpleLineChart(
            data: [
              (label: 'Ene', value: 2),
              (label: 'Feb', value: 4),
              (label: 'Mar', value: 5),
              (label: 'Abr', value: 4),
              (label: 'May', value: 7),
              (label: 'Jun', value: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanyLab extends StatelessWidget {
  const _CompanyLab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(company.sponsoredLabId);

    if (lab == null) {
      return const TabBody(
        title: 'Mi Laboratorio',
        children: [
          EmptyState(
              icon: Icons.science_outlined,
              message: 'Tu empresa aún no patrocina un laboratorio.'),
        ],
      );
    }

    final courses = data.coursesByLab(lab.id);
    final courseIds = courses.map((c) => c.id).toSet();
    final participants = data
        .usersByRole('student')
        .where((s) => s.courseIds.any(courseIds.contains))
        .toList();
    final mentor = data.userById(lab.mentorId);

    final sponsoredHours =
        data.sponsoredHoursByCompany()[company.companyName] ?? 0;

    return TabBody(
      title: lab.name,
      subtitle: 'Laboratorio patrocinado por ${company.companyName}',
      children: [
        if (sponsoredHours > 0) ...[
          HoverCard(
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism,
                    color: AppColors.gold, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${company.companyName} ha patrocinado $sponsoredHours '
                    'horas de formación completadas por estudiantes 💛',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Objetivos',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.gold)),
              const SizedBox(height: 6),
              Text(lab.objectives),
              const SizedBox(height: 12),
              Text('Mentor encargado: ${mentor?.name ?? 'Por asignar'}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SectionTitle('Contenido del laboratorio'),
        ...courses.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.video_library_outlined,
                        color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${c.modules.length} módulos · ${c.lessonCount} lecciones',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
        const SectionTitle('Participantes y su avance'),
        if (participants.isEmpty)
          const EmptyState(
              icon: Icons.groups_outlined,
              message: 'Aún no hay estudiantes inscritos.')
        else
          ...participants.map((s) {
            final avg = courses
                    .where((c) => s.courseIds.contains(c.id))
                    .fold<double>(
                        0, (acc, c) => acc + data.courseProgress(s.id, c)) /
                courses.where((c) => s.courseIds.contains(c.id)).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                        width: 200,
                        child: Text(s.name,
                            overflow: TextOverflow.ellipsis)),
                    Expanded(child: ThinProgressBar(value: avg)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _CompanyStudents extends StatelessWidget {
  const _CompanyStudents();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final sponsored = data.studentsForCompany(company.id);

    return TabBody(
      title: 'Estudiantes Patrocinados',
      subtitle:
          'Estudiantes que reciben apoyo directo de ${company.companyName}',
      children: [
        if (sponsored.isEmpty)
          const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: 'Aún no tienes estudiantes patrocinados.')
        else
          ...sponsored.map((s) {
            final group = data.groupById(s.groupId);
            final project =
                group == null ? null : data.projectById(group.projectId);
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
                            '${s.university} · ${s.career} · '
                            'Proyecto: ${project?.name ?? '—'}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          ThinProgressBar(
                              value: data.overallProgress(s)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
