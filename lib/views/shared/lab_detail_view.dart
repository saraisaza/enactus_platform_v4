import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../student/course_detail_view.dart';
import 'user_detail_view.dart';

/// Detalle de UN laboratorio, sin depender de un estudiante puntual — el
/// destino real de `/laboratorios/:id`. Antes esa ruta con nombre no
/// existía: lo más parecido era `LabDetailBody` (embebida en el portal
/// Estudiante, siempre atada al usuario con sesión) y `LabProgressView`
/// (progreso de UN estudiante puntual, requiere su id además del del
/// laboratorio) — ninguna servía para que Admin/LXD/Mentor/Empresa abrieran
/// un laboratorio desde una tarjeta sin partir de un estudiante.
///
/// Si quien mira es un estudiante/alumni con este laboratorio asignado,
/// muestra SU PROPIO avance por fase (mismo cálculo que `LabDetailBody`).
/// Para cualquier otro caso (otro rol, o un estudiante sin este lab
/// asignado) muestra el avance AGREGADO del grupo: qué fracción de los
/// estudiantes asignados completó cada fase — es el "progreso del
/// estudiante o del grupo según el rol" que pide la auditoría.
class LabDetailView extends StatelessWidget {
  final String labId;
  const LabDetailView({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(labId);

    if (lab == null) {
      return Scaffold(
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Laboratorio'),
            const Expanded(
              child: EmptyState(
                  icon: Icons.science_outlined, message: 'Este laboratorio ya no existe.'),
            ),
          ],
        ),
      );
    }

    final viewer = context.watch<AuthProvider>().currentUser!;
    final personalId =
        Roles.isStudentLike(viewer.role) && viewer.labIds.contains(lab.id) ? viewer.id : null;
    final accent = labColorFor(lab.id);
    final mentors = data.mentorsForLab(lab.id);
    final sponsor = lab.sponsorCompanyId.isEmpty ? null : data.userById(lab.sponsorCompanyId);
    final assigned = data.studentsAndAlumni.where((s) => s.labIds.contains(lab.id)).toList();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Laboratorio'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
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
                                  child: Text(lab.name.toUpperCase(),
                                      style: knockoutHeading(
                                          fontSize: 32,
                                          fontWeight: AppWeights.display,
                                          color: AppColors.textPrimary)),
                                ),
                              ],
                            ),
                            if (lab.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 56, top: 6),
                                child: Text(lab.description,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(left: 56, top: 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatusChip(
                                      label: '${assigned.length} estudiante(s) asignado(s)',
                                      color: accent,
                                      icon: Icons.groups_outlined),
                                  if (sponsor != null)
                                    HoverCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              settings: RouteSettings(
                                                  name: '${AppRoutes.users}/${sponsor.id}'),
                                              builder: (_) => UserDetailView(userId: sponsor.id))),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.volunteer_activism, size: 13, color: AppColors.gold),
                                          const SizedBox(width: 5),
                                          Text(sponsor.companyName,
                                              style: const TextStyle(fontSize: 12, color: AppColors.gold)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (mentors.isNotEmpty) ...[
                              const SectionTitle('Mentores'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final m in mentors)
                                    HoverCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              settings:
                                                  RouteSettings(name: '${AppRoutes.users}/${m.id}'),
                                              builder: (_) => UserDetailView(userId: m.id))),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InitialsAvatar(m.name, radius: 12),
                                          const SizedBox(width: 8),
                                          Text(m.name, style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SectionTitle('Ruta de Impacto'),
                            if (personalId == null && assigned.isEmpty)
                              const EmptyState(
                                  icon: Icons.groups_outlined,
                                  message: 'Aún no hay estudiantes asignados a este laboratorio.')
                            else
                              for (var i = 0; i < lab.phases.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _PhaseCard(
                                    lab: lab,
                                    phase: lab.phases[i],
                                    index: i,
                                    accent: accent,
                                    personalStudentId: personalId,
                                    assigned: assigned,
                                  ),
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

class _PhaseCard extends StatelessWidget {
  final Laboratory lab;
  final Phase phase;
  final int index;
  final Color accent;
  final String? personalStudentId;
  final List<AppUser> assigned;
  const _PhaseCard(
      {required this.lab,
      required this.phase,
      required this.index,
      required this.accent,
      required this.personalStudentId,
      required this.assigned});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final title = phase.title.isEmpty ? 'Fase ${index + 1}' : phase.title;

    late final Widget statusChip;
    if (personalStudentId != null) {
      final unlocked = data.isPhaseUnlocked(personalStudentId!, lab.id, lab, index);
      final complete = data.isPhaseComplete(personalStudentId!, lab.id, phase);
      final deadlineStatus = data.phaseDeadlineStatus(personalStudentId!, lab.id, phase);
      statusChip = StatusChip(
        label: complete
            ? 'Completa'
            : !unlocked
                ? 'Bloqueada — completa la fase anterior'
                : deadlineStatus == DeadlineStatus.overdue
                    ? 'Vencida'
                    : deadlineStatus == DeadlineStatus.approaching
                        ? 'Por vencer'
                        : 'Disponible',
        color: complete
            ? AppColors.statusGood
            : !unlocked
                ? AppColors.textMuted
                : deadlineStatus == DeadlineStatus.overdue
                    ? AppColors.statusCritical
                    : deadlineStatus == DeadlineStatus.approaching
                        ? AppColors.statusWarning
                        : accent,
        icon: complete
            ? Icons.check_circle
            : !unlocked
                ? Icons.lock_outline
                : Icons.hourglass_empty,
      );
    } else {
      final done = assigned.where((s) => data.isPhaseComplete(s.id, lab.id, phase)).length;
      final overdue = phase.deadline.isNotEmpty &&
          DateTime.tryParse(phase.deadline) != null &&
          DateTime.now().isAfter(DateTime.parse(phase.deadline));
      statusChip = StatusChip(
        label: assigned.isEmpty ? 'Sin estudiantes' : '$done/${assigned.length} completaron',
        color: overdue ? AppColors.statusCritical : accent,
        icon: overdue ? Icons.warning_amber_rounded : Icons.groups_outlined,
      );
    }

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              statusChip,
            ],
          ),
          if (phase.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(phase.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (phase.deadline.isNotEmpty && DateTime.tryParse(phase.deadline) != null) ...[
            const SizedBox(height: 6),
            Text('Fecha límite: ${DateFormat('d MMM yyyy', 'es').format(DateTime.parse(phase.deadline))}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          if (phase.modules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Sin módulos publicados todavía.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            )
          else ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            for (final module in phase.modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        module.isMentorshipModule ? Icons.diversity_3 : Icons.view_module_outlined,
                        size: 15,
                        color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(module.title.isEmpty ? 'Módulo' : module.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (module.courseIds.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final cid in module.courseIds)
                                  Builder(builder: (context) {
                                    final course = data.courseById(cid);
                                    if (course == null) return const SizedBox.shrink();
                                    return HoverCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              settings: RouteSettings(
                                                  name: '${AppRoutes.courses}/${course.id}'),
                                              builder: (_) => CourseDetailView(courseId: course.id))),
                                      child: Text(course.name, style: const TextStyle(fontSize: 11.5)),
                                    );
                                  }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
