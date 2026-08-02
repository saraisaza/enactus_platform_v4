import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/forum_view.dart';
import '../shared/projects_directory_view.dart';
import 'course_detail_view.dart';
import 'ruta_impacto_view.dart' show LabsView, RutaImpactoShortcut;

/// Portal del estudiante. Un estudiante Enactus ve Laboratorios y su Ruta
/// de Impacto; uno de Open Learning solo ve y completa sus cursos
/// asignados (sin laboratorios, fases ni módulos).
class StudentPortal extends StatelessWidget {
  const StudentPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentUser!;
    final isEnactus = student.studentType == StudentType.enactus;

    return PortalShell(
      // Mismo portal para estudiante y alumni (ver Roles.isStudentLike):
      // solo cambia el título visible, según lo pidió el usuario ("que se
      // llame alumni").
      portalTitle: 'Portal ${Roles.label(student.role)}',
      tabs: [
        PortalTab(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            builder: (_) => const _StudentDashboard()),
        PortalTab(
            label: 'Mis Cursos',
            icon: Icons.school_outlined,
            builder: (_) => const _StudentCourses()),
        if (isEnactus) ...[
          PortalTab(
              label: 'Laboratorios',
              icon: Icons.science_outlined,
              builder: (_) => const LabsView()),
          PortalTab(
              label: 'Ruta de Impacto',
              icon: Icons.emoji_events_outlined,
              builder: (_) => const RutaImpactoShortcut()),
          PortalTab(
              label: 'Directorio de Proyectos',
              icon: Icons.explore_outlined,
              builder: (_) => const ProjectsDirectoryView()),
          PortalTab(
              label: 'Foro',
              icon: Icons.forum_outlined,
              builder: (_) => const ForumView()),
        ],
        PortalTab(
            label: 'Certificados',
            icon: Icons.workspace_premium_outlined,
            builder: (_) => const _StudentCertificates()),
        PortalTab(
            label: 'Mi Perfil',
            icon: Icons.person_outline,
            builder: (_) => const _StudentProfile()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _StudentDashboard extends StatelessWidget {
  const _StudentDashboard();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final courses = data.coursesForStudent(student);
    final group = data.groupById(student.groupId);
    final project =
        group == null ? null : data.projectById(group.projectId);
    final overall = data.overallProgress(student);

    final pendingTasks = <String>[];
    for (final c in courses) {
      final progress = data.courseProgress(student.id, c);
      if (progress < 1.0) {
        pendingTasks.add('Continuar "${c.name}"');
      }
    }

    return TabBody(
      title: 'Hola, ${student.name.split(' ').first} 👋',
      subtitle: project != null
          ? 'Proyecto: ${project.name} · Etapa: ${project.stage}'
          : 'Aún no tienes proyecto asignado',
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 800;
          final ring = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ProgressRing(value: overall, label: 'Progreso general'),
          );
          final chart = ChartCard(
            title: 'Progreso por curso (%)',
            height: 220,
            child: courses.isEmpty
                ? const EmptyState(
                    icon: Icons.school_outlined,
                    message: 'Sin cursos asignados')
                : SimpleBarChart(
                    maxY: 100,
                    data: [
                      for (final course in courses)
                        (
                          label: course.name.split(' ').take(2).join(' '),
                          value:
                              data.courseProgress(student.id, course) * 100,
                        ),
                    ],
                  ),
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Entrance(child: ring),
                    const SizedBox(width: 12),
                    Expanded(child: Entrance(delayMs: 120, child: chart)),
                  ],
                )
              : Column(children: [
                  Entrance(child: ring),
                  const SizedBox(height: 12),
                  Entrance(delayMs: 120, child: chart),
                ]);
        }),
        const SectionTitle('Entregas y tareas pendientes'),
        if (pendingTasks.isEmpty)
          const EmptyState(
              icon: Icons.check_circle_outline,
              message: '¡Estás al día! No tienes pendientes.')
        else
          ...pendingTasks.take(6).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions,
                          color: AppColors.statusWarning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mis Cursos
// ---------------------------------------------------------------------------

class _StudentCourses extends StatelessWidget {
  const _StudentCourses();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final courses =
        data.coursesForStudent(student).where((c) => !c.isRutaExpo).toList();

    return TabBody(
      title: 'Mis Cursos',
      subtitle: 'Cursos de laboratorio asignados por tu administrador',
      children: [
        if (courses.isEmpty)
          const EmptyState(
              icon: Icons.school_outlined,
              message: 'Aún no tienes cursos asignados.')
        else
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > 900 ? 2 : 1;
            final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final course in courses)
                  SizedBox(
                    width: width,
                    child: _CourseCard(course: course, studentId: student.id),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final String studentId;
  const _CourseCard({required this.course, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(course.labId);
    final creator =
        course.creatorId.isEmpty ? null : data.userById(course.creatorId);
    final progress = data.courseProgress(studentId, course);
    final done = data
        .progressFor(studentId, course.id)
        .completedLessonIds
        .length;
    final durationMin = course.lessonCount * 15; // estimado 15 min/lección

    void open() => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CourseDetailView(courseId: course.id)),
        );

    // Al pasar el mouse: la tarjeta se eleva, el borde pasa a amarillo y
    // aparece el detalle (LXD, duración, avance) con el botón Continuar.
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: open,
        child: AnimatedScale(
          scale: hover ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hover ? AppColors.surfaceAlt : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hover ? AppColors.gold : AppColors.border,
                  width: hover ? 1.2 : 1),
              boxShadow: hover
                  ? const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 18,
                          offset: Offset(0, 6)),
                    ]
                  : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedScale(
                      scale: hover ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.play_circle_outline,
                          color: AppColors.gold, size: 26),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(course.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    AnimatedOpacity(
                      opacity: hover ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Text('Ver curso →',
                          style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lab != null)
                  Text(lab.name,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ThinProgressBar(
                    value: progress,
                    tooltip: '$done de ${course.lessonCount} lecciones'),
                const SizedBox(height: 6),
                Text(
                    '${course.modules.length} módulos · ${course.lessonCount} lecciones',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                // Detalle extra que aparece solo en hover
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: hover
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${creator != null ? 'Docente: ${creator.name} · ' : ''}'
                            '~$durationMin min',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text(
                              progress > 0 ? 'Continuar' : 'Comenzar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(fontSize: 12.5),
                          ),
                          onPressed: open,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Certificados
// ---------------------------------------------------------------------------

class _StudentCertificates extends StatelessWidget {
  const _StudentCertificates();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final certs = data.certificatesForStudent(student.id);

    return TabBody(
      title: 'Mis Certificados',
      subtitle: 'Certificados emitidos por tus LXD al completar una Ruta de Impacto',
      children: [
        if (certs.isEmpty)
          const EmptyState(
              icon: Icons.workspace_premium_outlined,
              message:
                  'Aún no tienes certificados.\nCompleta tus cursos para obtenerlos.')
        else
          ...certs.map((cert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HoverBuilder(
                  builder: (context, hover) => AnimatedScale(
                    scale: hover ? 1.02 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hover
                            ? AppColors.surfaceAlt
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                hover ? AppColors.gold : AppColors.border),
                        boxShadow: hover
                            ? const [
                                BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 18,
                                    offset: Offset(0, 6)),
                              ]
                            : const [],
                      ),
                      child: Row(
                        children: [
                          AnimatedScale(
                            scale: hover ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(Icons.workspace_premium,
                                color: AppColors.gold, size: 34),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ruta de Impacto · ${cert.labName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  'Emitido el ${DateFormat('d MMM yyyy').format(cert.date)} · '
                                  'Por: ${cert.issuerName} · Código: ${cert.code}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // El botón de descarga aparece al pasar el mouse
                          AnimatedOpacity(
                            opacity: hover ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Descargar'),
                                onPressed: hover
                                    ? () => PdfService.download(cert)
                                    : null,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('Ver PDF'),
                            onPressed: () => PdfService.preview(cert),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Perfil
// ---------------------------------------------------------------------------

class _StudentProfile extends StatelessWidget {
  const _StudentProfile();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final group = data.groupById(student.groupId);
    final project = group == null ? null : data.projectById(group.projectId);
    final sponsor =
        student.companyId == null ? null : data.userById(student.companyId!);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 160,
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13))),
              Expanded(
                  child: Text(value.isEmpty ? '—' : value,
                      style: const TextStyle(fontSize: 14))),
            ],
          ),
        );

    return TabBody(
      title: 'Mi Perfil',
      children: [
        HoverCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(student.name,
                      large: true, radius: 30, fontSize: 26),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(student.email,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),
              row('Cédula', student.cedula),
              row('Teléfono', student.phone),
              row('Universidad', student.university),
              row('Carrera', student.career),
              row('Equipo', group?.name ?? '—'),
              row('Proyecto', project?.name ?? '—'),
              row('Empresa patrocinadora', sponsor?.companyName ?? '—'),
            ],
          ),
        ),
      ],
    );
  }
}
