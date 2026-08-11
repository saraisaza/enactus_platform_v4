import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/student_detail_view.dart';
import '../shared/students_map_view.dart';
import '../shared/talent_search_view.dart';

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
            label: 'Mapa de Estudiantes',
            icon: Icons.public_outlined,
            builder: (_) => const StudentsMapView()),
        PortalTab(
            label: 'Mis Laboratorios',
            icon: Icons.science_outlined,
            builder: (_) => const _CompanyLabs()),
        PortalTab(
            label: 'Estudiantes Patrocinados',
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const _CompanyStudents()),
        PortalTab(
            label: 'Mi Equipo LXD',
            icon: Icons.groups_2_outlined,
            builder: (_) => const _CompanyLxdTeam()),
        PortalTab(
            label: 'Mi Equipo Mentor',
            icon: Icons.psychology_alt_outlined,
            builder: (_) => const _CompanyMentorTeam()),
        PortalTab(
            label: 'BuscaTalento',
            icon: Icons.people_alt_outlined,
            builder: (_) => const TalentSearchView()),
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
    final labs = data.labsForCompany(company.id);
    final labParticipants = <String>{
      for (final lab in labs)
        ...data.studentsAndAlumni
            .where((s) => s.labIds.contains(lab.id))
            .map((s) => s.id)
    }.toList();
    final phasesCompleted = labParticipants.fold<int>(
        0,
        (acc, sid) =>
            acc +
            labs.fold<int>(
                0,
                (a2, lab) =>
                    a2 +
                    lab.phases
                        .where((p) => data.isPhaseComplete(sid, lab.id, p))
                        .length));
    final mentorsById = <String, AppUser>{
      for (final lab in labs)
        for (final m in data.mentorsForLab(lab.id)) m.id: m,
    };
    final mentors = mentorsById.values.toList();
    final totalReviews = mentors.fold<int>(
        0, (acc, m) => acc + data.reviewsCountForMentor(m));
    final allObjectives =
        labs.expand((l) => l.phases.expand((p) => p.objectives)).toList();
    final labNames = labs.map((l) => l.name).join(', ');
    final entrepreneurshipObjs = allObjectives
        .where((o) => o.category == ObjectiveCategory.entrepreneurship)
        .toList();
    final businessObjs = allObjectives
        .where((o) => o.category == ObjectiveCategory.business)
        .toList();
    int completions(List<Objective> objs) => labParticipants.fold<int>(
        0,
        (acc, sid) =>
            acc + objs.where((o) => data.isObjectiveComplete(sid, o)).length);

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
        HoverCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: AppColors.gold, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  labs.isEmpty
                      ? '${company.companyName} está formando parte del cambio con Enactus Colombia 💛'
                      : '${company.companyName} está financiando la formación de '
                          '${labParticipants.length} joven(es) en $labNames: hasta hoy, '
                          '${(lessonsDone * 1.5).round()} horas de formación, $phasesCompleted '
                          'fase(s) de Ruta de Impacto y ${completions(allObjectives)} '
                          'objetivo(s) cumplidos gracias a tu aporte. 💛',
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              value: '$phasesCompleted',
              label: 'Fases de Ruta de Impacto completadas',
              icon: Icons.emoji_events_outlined,
              detail: labs.isEmpty
                  ? 'Aún no patrocinas un laboratorio'
                  : 'Entre ${labParticipants.length} estudiantes de $labNames'),
          StatTile(
              value: '${projects.length}',
              label: 'Proyectos apoyados',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${mentors.length}',
              label: 'Mentores activos',
              icon: Icons.psychology_alt_outlined,
              detail: '$totalReviews entrega(s) revisada(s) en total'),
        ]),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Fases de Ruta de Impacto completadas por laboratorio',
          child: labs.isEmpty || phasesCompleted == 0
              ? const EmptyState(
                  icon: Icons.bar_chart_outlined,
                  message: 'Sin fases completadas en tus laboratorios todavía.')
              : SimpleBarChart(
                  maxY: (phasesCompleted.toDouble()).clamp(5, 999),
                  data: [
                    for (final lab in labs)
                      (
                        label: lab.name,
                        value: data.studentsAndAlumni
                            .where((s) => s.labIds.contains(lab.id))
                            .fold<int>(
                                0,
                                (acc, s) =>
                                    acc +
                                    lab.phases
                                        .where((p) => data.isPhaseComplete(
                                            s.id, lab.id, p))
                                        .length)
                            .toDouble(),
                      ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Objetivos de la Ruta de Impacto cumplidos',
          child: allObjectives.isEmpty
              ? const EmptyState(
                  icon: Icons.flag_outlined,
                  message:
                      'Tu Admin y LXD aún no definieron objetivos para tu laboratorio.')
              : (completions(entrepreneurshipObjs) + completions(businessObjs) ==
                      0)
                  ? const EmptyState(
                      icon: Icons.flag_outlined,
                      message:
                          'Tus estudiantes todavía no han cumplido ningún objetivo.')
                  : DonutChart(
                  data: [
                    if (completions(entrepreneurshipObjs) > 0)
                      (
                        label: 'Emprendimiento',
                        value: completions(entrepreneurshipObjs).toDouble(),
                      ),
                    if (completions(businessObjs) > 0)
                      (
                        label: 'Empresariales',
                        value: completions(businessObjs).toDouble(),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Una empresa puede tener varios LXD creando cursos en laboratorios
/// distintos a la vez: aquí se listan todos, uno debajo del otro (no hay
/// un "el laboratorio" único de la empresa, ver [DataProvider.labsForCompany]).
class _CompanyLabs extends StatelessWidget {
  const _CompanyLabs();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForCompany(company.id);

    if (labs.isEmpty) {
      return const TabBody(
        title: 'Mis Laboratorios',
        children: [
          EmptyState(
              icon: Icons.science_outlined,
              message:
                  'Tu empresa aún no tiene laboratorios: crea un LXD (pestaña "Mi Equipo LXD") y pide que vincule uno de sus cursos a un laboratorio.'),
        ],
      );
    }

    return TabBody(
      title: 'Mis Laboratorios',
      subtitle: labs.length == 1
          ? 'Laboratorio patrocinado por ${company.companyName}'
          : '${labs.length} laboratorios patrocinados por ${company.companyName}',
      children: [
        for (var i = 0; i < labs.length; i++) ...[
          if (i > 0) const Divider(height: 40),
          _CompanyLabSection(lab: labs[i], company: company),
        ],
      ],
    );
  }
}

class _CompanyLabSection extends StatelessWidget {
  final Laboratory lab;
  final AppUser company;
  const _CompanyLabSection({required this.lab, required this.company});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    final courses = data.coursesByLab(lab.id);
    // Todo estudiante asignado al laboratorio ve automáticamente todos sus
    // cursos (no hace falta asignarlos aparte).
    final participants = data.studentsAndAlumni
        .where((s) => s.labIds.contains(lab.id))
        .toList();
    final mentorNames = lab.mentorIds
        .map((id) => data.userById(id)?.name)
        .whereType<String>()
        .join(', ');
    final mentors = data.mentorsForLab(lab.id);

    final sponsoredHours =
        data.sponsoredHoursByCompany()[company.companyName] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lab.name,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800,
                color: AppColors.gold)),
        const SizedBox(height: 14),
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
              Text(
                  'Mentores encargados: ${mentorNames.isEmpty ? 'Por asignar' : mentorNames}',
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
        const SectionTitle('Objetivos de la Ruta de Impacto'),
        if (lab.phases.every((p) => p.objectives.isEmpty))
          const EmptyState(
              icon: Icons.flag_outlined,
              message:
                  'Tu Admin y LXD aún no definieron objetivos para este laboratorio.')
        else
          for (final phase in lab.phases)
            if (phase.objectives.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HoverCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          phase.title.isEmpty
                              ? 'Fase ${lab.phases.indexOf(phase) + 1}'
                              : phase.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                      const SizedBox(height: 8),
                      for (final o in phase.objectives)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                  o.category == ObjectiveCategory.entrepreneurship
                                      ? Icons.rocket_launch_outlined
                                      : Icons.business_center_outlined,
                                  size: 15,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(o.text,
                                      style: const TextStyle(fontSize: 13))),
                              StatusChip(
                                label:
                                    '${participants.where((s) => data.isObjectiveComplete(s.id, o)).length}/${participants.length}',
                                color: AppColors.statusGood,
                                icon: Icons.check_circle_outline,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        const SectionTitle('Participantes y su avance'),
        if (participants.isEmpty)
          const EmptyState(
              icon: Icons.groups_outlined,
              message: 'Aún no hay estudiantes inscritos.')
        else
          ...participants.map((s) {
            final avg = courses.isEmpty
                ? 0.0
                : courses.fold<double>(
                        0, (acc, c) => acc + data.courseProgress(s.id, c)) /
                    courses.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StudentDetailView(studentId: s.id))),
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
        const SectionTitle('Mentores y su labor'),
        if (mentors.isEmpty)
          const EmptyState(
              icon: Icons.psychology_alt_outlined,
              message:
                  'Aún no tienes Mentores asignados a este laboratorio (pestaña "Mi Equipo Mentor").')
        else
          ...mentors.map((m) {
            final theirStudents = data.studentsForMentor(m);
            final reviews = data.reviewsCountForMentor(m);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_outlined,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(
                        '${theirStudents.length} estudiante(s) · $reviews entrega(s) revisada(s)',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
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

// ---------------------------------------------------------------------------
// Mi Equipo LXD: la empresa crea y ve sus propios LXD, que diseñan los
// cursos que se vuelven requisito de su laboratorio patrocinado.
// ---------------------------------------------------------------------------

class _CompanyLxdTeam extends StatelessWidget {
  const _CompanyLxdTeam();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final lxds = data.lxdsForCompany(company.id);
    final companyLabIds =
        data.labsForCompany(company.id).map((l) => l.id).toSet();

    return TabBody(
      title: 'Mi Equipo LXD',
      subtitle:
          'Tus LXD diseñan cursos que se vuelven requisito de tus laboratorios patrocinados',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Crear LXD'),
          onPressed: () => _createLxd(context, company),
        ),
      ],
      children: [
        if (lxds.isEmpty)
          const EmptyState(
              icon: Icons.groups_2_outlined,
              message:
                  'Aún no has creado ningún LXD. Crea el primero para diseñar cursos para tu laboratorio.')
        else
          ...lxds.map((lxd) {
            final courses =
                data.courses.where((c) => c.creatorId == lxd.id).toList();
            final linked = courses
                .where((c) =>
                    c.labId.isNotEmpty && companyLabIds.contains(c.labId))
                .length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                child: Row(
                  children: [
                    InitialsAvatar(lxd.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lxd.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(lxd.email,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text(
                              '${courses.length} curso(s) creado(s) · $linked en tus laboratorios',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
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

  Future<void> _createLxd(BuildContext context, AppUser company) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear cuenta de LXD',
            style: TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Este LXD queda vinculado a ${company.companyName}: sus '
                    'cursos podrán asignarse como requisito de tu '
                    'laboratorio patrocinado.',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 14),
                TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Nombre completo')),
                const SizedBox(height: 12),
                TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico')),
                const SizedBox(height: 12),
                TextField(
                    controller: passCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Contraseña')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono')),
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
              if (nameCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  passCtrl.text.isEmpty) {
                return;
              }
              await data.saveUser(AppUser(
                id: data.newId('usr'),
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                password: passCtrl.text,
                role: Roles.lxd,
                phone: phoneCtrl.text.trim(),
                extra: {
                  'companyId': company.id,
                  'company': company.companyName,
                },
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                showSuccessCheck(context, 'LXD creado ✓');
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mi Equipo Mentor: la empresa crea y ve sus propios Mentores, y les
// asigna qué cursos de su laboratorio revisan (entregas y Ruta de Impacto).
// ---------------------------------------------------------------------------

class _CompanyMentorTeam extends StatelessWidget {
  const _CompanyMentorTeam();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final company = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForCompany(company.id);
    final mentorsById = <String, AppUser>{
      for (final lab in labs)
        for (final m in data.mentorsForLab(lab.id)) m.id: m,
    };
    final mentors = mentorsById.values.toList();

    return TabBody(
      title: 'Mi Equipo Mentor',
      subtitle: labs.isEmpty
          ? 'Aún no patrocinas un laboratorio'
          : 'Tus Mentores revisan la Ruta de Impacto y las entregas de '
              '${labs.map((l) => l.name).join(', ')}',
      actions: [
        if (labs.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Crear Mentor'),
            onPressed: () => _createMentor(context, company, labs),
          ),
      ],
      children: [
        if (labs.isEmpty)
          const EmptyState(
              icon: Icons.science_outlined,
              message: 'Tu empresa aún no patrocina un laboratorio.')
        else if (mentors.isEmpty)
          const EmptyState(
              icon: Icons.psychology_alt_outlined,
              message:
                  'Aún no has creado ningún Mentor. Crea el primero para revisar el avance de tus estudiantes.')
        else
          ...mentors.map((mentor) {
            final students = data.studentsForMentor(mentor);
            final reviews = data.reviewsCountForMentor(mentor);
            final assignedCourses = mentor.reviewCourseIds
                .map((id) => data.courseById(id)?.name)
                .whereType<String>()
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                child: Row(
                  children: [
                    InitialsAvatar(mentor.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mentor.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(mentor.email,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text(
                              '${students.length} estudiante(s) a cargo · $reviews entrega(s) revisada(s)',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(
                              assignedCourses.isEmpty
                                  ? 'Revisa todos los cursos de sus laboratorios'
                                  : 'Cursos asignados: $assignedCourses',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Asignar cursos'),
                      onPressed: () =>
                          _assignMentorCourses(context, mentor, labs),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _createMentor(
      BuildContext context, AppUser company, List<Laboratory> labs) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? targetLabId = labs.length == 1 ? labs.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Crear cuenta de Mentor',
              style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Este Mentor revisará la Ruta de Impacto y las '
                      'entregas de tus estudiantes en el laboratorio que '
                      'elijas.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Nombre completo')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Correo electrónico')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: passCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Contraseña')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Teléfono')),
                  if (labs.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: targetLabId,
                      decoration: const InputDecoration(
                          labelText: 'Laboratorio a cargo'),
                      items: [
                        for (final l in labs)
                          DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (v) => setState(() => targetLabId = v),
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
                if (nameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty ||
                    passCtrl.text.isEmpty ||
                    targetLabId == null) {
                  return;
                }
                final lab = labs.firstWhere((l) => l.id == targetLabId);
                final mentor = AppUser(
                  id: data.newId('usr'),
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text,
                  role: Roles.mentor,
                  phone: phoneCtrl.text.trim(),
                  extra: {
                    'companyId': company.id,
                    'company': company.companyName,
                  },
                );
                await data.saveUser(mentor);
                if (!lab.mentorIds.contains(mentor.id)) {
                  lab.mentorIds = [...lab.mentorIds, mentor.id];
                  await data.saveLab(lab);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSuccessCheck(context, 'Mentor creado ✓');
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignMentorCourses(
      BuildContext context, AppUser mentor, List<Laboratory> labs) async {
    final data = context.read<DataProvider>();
    // Un curso solo pertenece a un laboratorio, así que no hay duplicados
    // al juntar los cursos de todos los laboratorios de la empresa.
    final courses = [for (final lab in labs) ...data.coursesByLab(lab.id)];
    final selected = {...mentor.reviewCourseIds};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Cursos de ${mentor.name}',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Si no eliges ninguno, este Mentor revisa todos los cursos de tus laboratorios.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                courses.isEmpty
                    ? const Text('Tus laboratorios no tienen cursos todavía.',
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
                              selected: selected.contains(c.id),
                              selectedColor:
                                  AppColors.gold.withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => sel
                                  ? selected.add(c.id)
                                  : selected.remove(c.id)),
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
                mentor.reviewCourseIds = selected.toList();
                await data.saveUser(mentor);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSuccessCheck(context, 'Cursos actualizados ✓');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
