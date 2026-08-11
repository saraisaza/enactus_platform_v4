import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../student/course_detail_view.dart';
import 'lab_progress_view.dart';
import 'projects_directory_view.dart' show ProjectDetailView;

/// Perfil de UN estudiante, de solo lectura — para que otro rol (LXD,
/// Mentor, Asesor, Empresa, Donante, Admin) vea su información real desde
/// cualquier tarjeta que hoy solo la mostraba en texto o en un tooltip.
/// Editar sigue siendo tarea del propio estudiante o de Admin en su
/// diálogo de usuarios — esta pantalla no tiene ninguna acción de escritura.
class StudentDetailView extends StatelessWidget {
  final String studentId;
  const StudentDetailView({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = data.userById(studentId);

    if (student == null) {
      return Scaffold(
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Estudiante'),
            const Expanded(
              child: EmptyState(
                  icon: Icons.person_outline, message: 'Este estudiante ya no existe.'),
            ),
          ],
        ),
      );
    }

    Group? group;
    for (final g in data.groups) {
      if (g.studentIds.contains(student.id)) {
        group = g;
        break;
      }
    }
    final project = group == null ? null : data.projectById(group.projectId);
    final labs = data.labsForStudent(student);
    final courses = data.coursesForStudent(student);
    final certificates = data.certificatesForStudent(student.id);

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Estudiante'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: AppColors.gold,
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(height: 6),
                            _IdentityHeader(student: student),
                            const SizedBox(height: 22),
                            if (project != null || group != null) ...[
                              SectionTitle('Equipo y proyecto'),
                              _TeamCard(student: student, group: group, project: project),
                              const SizedBox(height: 8),
                            ],
                            if (labs.isNotEmpty) ...[
                              SectionTitle('Laboratorios'),
                              for (final lab in labs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _LabSummaryRow(student: student, lab: lab),
                                ),
                            ],
                            if (courses.isNotEmpty) ...[
                              SectionTitle('Cursos'),
                              for (final c in courses)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _CourseSummaryRow(student: student, course: c),
                                ),
                            ],
                            SectionTitle('Certificados'),
                            if (certificates.isEmpty)
                              const Text('Sin certificados todavía.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                            else
                              for (final cert in certificates)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _CertificateRow(certificate: cert),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  final AppUser student;
  const _IdentityHeader({required this.student});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (student.career.isNotEmpty) student.career,
      if (student.university.isNotEmpty) student.university,
      if (student.city.isNotEmpty) student.city,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(student.name, large: true, radius: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.name,
                  style: knockoutHeading(
                      fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (subtitleParts.isNotEmpty)
                Text(subtitleParts.join(' · '),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                      label: StudentType.label(student.studentType),
                      color: AppColors.gold,
                      icon: Icons.school_outlined),
                  StatusChip(label: student.email, color: AppColors.textMuted, icon: Icons.mail_outline),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final AppUser student;
  final Group? group;
  final Project? project;
  const _TeamCard({required this.student, required this.group, required this.project});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: project == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                  settings: RouteSettings(name: '${AppRoutes.projects}/${project!.id}'),
                  builder: (_) => ProjectDetailView(projectId: project!.id))),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.groups_outlined, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(project?.name ?? group?.name ?? 'Sin proyecto asignado',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (group != null)
                  Text(
                      '${group!.name}'
                      '${group!.university.isEmpty ? '' : ' · ${group!.university}'}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (project != null) const Icon(Icons.arrow_forward, size: 18, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _LabSummaryRow extends StatelessWidget {
  final AppUser student;
  final Laboratory lab;
  const _LabSummaryRow({required this.student, required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final accent = labColorFor(lab.id);
    final phasesDone = lab.phases.where((p) => data.isPhaseComplete(student.id, lab.id, p)).length;
    final progress = data.labModuleProgress(student.id, lab);

    return HoverCard(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LabProgressView(studentId: student.id, labId: lab.id))),
      child: Row(
        children: [
          Container(width: 8, height: 40, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lab.name,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Fase $phasesDone/${lab.phases.length} · ${progress.done}/${progress.total} módulos',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _CourseSummaryRow extends StatelessWidget {
  final AppUser student;
  final Course course;
  const _CourseSummaryRow({required this.student, required this.course});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final progress = data.courseProgress(student.id, course);

    return HoverCard(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings: RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
              builder: (_) => CourseDetailView(courseId: course.id))),
      child: Row(
        children: [
          Expanded(
            child: Text(course.name,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 130, child: ThinProgressBar(value: progress, color: labColorFor(course.labId))),
        ],
      ),
    );
  }
}

class _CertificateRow extends StatelessWidget {
  final Certificate certificate;
  const _CertificateRow({required this.certificate});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_outlined, color: AppColors.gold, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(certificate.labName,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${certificate.code}${certificate.hours > 0 ? ' · ${certificate.hours} h' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
