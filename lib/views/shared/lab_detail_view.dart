import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../student/course_detail_view.dart';

/// Detalle de UN laboratorio, sin depender de un estudiante puntual — el
/// destino real de `/laboratorios/:id`.
///
/// Si quien mira es un estudiante con este laboratorio asignado, muestra SU
/// avance por fase, que viene de `/students/:id/ruta-progress`. Para cualquier
/// otro rol muestra el avance AGREGADO del grupo —cuántos de los estudiantes
/// asignados completaron cada fase— que viene con el propio laboratorio.
///
/// Las dos cifras las calcula el servidor con la misma vista de PostgreSQL
/// (`phase_completion`) que decide si se puede emitir un certificado. Antes se
/// calculaban en el navegador, cada una por su cuenta, y podían no coincidir.
class LabDetailView extends StatelessWidget {
  final String labId;
  const LabDetailView({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Laboratorio'),
          Expanded(
            child: data.labById(labId).when(
                  loading: () => const Center(child: BrandLoader()),
                  // Un 403 acá es real: un laboratorio que no es de esta
                  // persona. No se disfraza de "no existe".
                  error: (e) => ErrorState(e,
                      onRetry: () => data.reloadLaboratories()),
                  data: (lab) => _LabBody(lab: lab),
                ),
          ),
        ],
      ),
    );
  }
}

class _LabBody extends StatelessWidget {
  final Laboratory lab;
  const _LabBody({required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final viewer = context.watch<AuthProvider>().currentUser;
    final accent = labColorFor(lab.id);

    // El avance propio solo tiene sentido para un estudiante que además tenga
    // este laboratorio asignado. Para el resto —y para un estudiante mirando
    // un laboratorio ajeno— se muestra el del grupo.
    LabProgress? personal;
    if (viewer != null && Roles.isStudentLike(viewer.role)) {
      personal = data.rutaProgress.valueOrNull?.labById(lab.id);
    }

    return CustomScrollView(
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
                              style: displayHeading(
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
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.textSecondary)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 56, top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                              label:
                                  '${lab.studentsAssigned} estudiante(s) asignado(s)',
                              color: accent,
                              icon: Icons.groups_outlined),
                          if (lab.sponsorName != null)
                            StatusChip(
                                label: lab.sponsorName!,
                                color: AppColors.gold,
                                icon: Icons.volunteer_activism),
                        ],
                      ),
                    ),
                    if (lab.mentors.isNotEmpty) ...[
                      const SectionTitle('Mentores'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Sin enlace al perfil: no existe un endpoint que le
                          // permita a un estudiante leer la cuenta de otra
                          // persona, y no debería. Nombre y foto alcanzan para
                          // saber quién acompaña el laboratorio.
                          for (final mentor in lab.mentors)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InitialsAvatar(mentor.name, radius: 12),
                                  const SizedBox(width: 8),
                                  Text(mentor.name,
                                      style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SectionTitle('Ruta de Impacto'),
                    if (lab.phases.isEmpty)
                      const EmptyState(
                          icon: Icons.route_outlined,
                          message:
                              'Este laboratorio todavía no tiene fases publicadas.')
                    else
                      for (var i = 0; i < lab.phases.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PhaseCard(
                            phase: lab.phases[i],
                            index: i,
                            accent: accent,
                            studentsAssigned: lab.studentsAssigned,
                            // El avance personal viene emparejado por id de
                            // fase, no por posición: si el Admin reordena las
                            // fases, emparejar por índice mostraría el estado
                            // de otra.
                            personal: personal?.phases
                                .where((p) => p.phaseId == lab.phases[i].id)
                                .firstOrNull,
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
          child: Align(
              alignment: Alignment.bottomCenter, child: AppFooter()),
        ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final Phase phase;
  final int index;
  final Color accent;
  final int studentsAssigned;

  /// Avance de quien mira, si es un estudiante de este laboratorio.
  final PhaseProgress? personal;

  const _PhaseCard({
    required this.phase,
    required this.index,
    required this.accent,
    required this.studentsAssigned,
    required this.personal,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final title = phase.title.isEmpty ? 'Fase ${index + 1}' : phase.title;

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              personal != null
                  ? _personalChip(personal!)
                  : _groupChip(),
            ],
          ),
          if (phase.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(phase.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (phase.deadlineDate != null) ...[
            const SizedBox(height: 6),
            Text(
                'Fecha límite: '
                '${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
          if (phase.modules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Sin módulos publicados todavía.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            )
          else ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            for (final module in phase.modules)
              _ModuleRow(module: module, data: data),
          ],
        ],
      ),
    );
  }

  /// Estado de ESTA persona en la fase: bloqueada, vencida, completa.
  /// Todo lo decide el servidor — el desbloqueo, el estado del deadline y la
  /// completitud— y acá solo se elige cómo se dice.
  Widget _personalChip(PhaseProgress progress) {
    final (label, color, icon) = switch (progress) {
      PhaseProgress(isComplete: true) => (
          'Completa',
          AppColors.statusGood,
          Icons.check_circle
        ),
      PhaseProgress(isUnlocked: false) => (
          'Bloqueada — completa la fase anterior',
          AppColors.textMuted,
          Icons.lock_outline
        ),
      PhaseProgress(deadlineStatus: DeadlineStatus.overdue) => (
          'Vencida',
          AppColors.statusCritical,
          Icons.warning_amber_rounded
        ),
      PhaseProgress(deadlineStatus: DeadlineStatus.approaching) => (
          'Por vencer',
          AppColors.statusWarning,
          Icons.hourglass_empty
        ),
      _ => ('Disponible', accent, Icons.hourglass_empty),
    };
    return StatusChip(label: label, color: color, icon: icon);
  }

  /// Estado del GRUPO: cuántos de los asignados completaron la fase.
  Widget _groupChip() {
    if (studentsAssigned == 0) {
      return StatusChip(
          label: 'Sin estudiantes',
          color: AppColors.textMuted,
          icon: Icons.groups_outlined);
    }
    final overdue = phase.deadlineDate != null &&
        DateTime.now().isAfter(phase.deadlineDate!) &&
        phase.completedByCount < studentsAssigned;
    return StatusChip(
      label: '${phase.completedByCount}/$studentsAssigned completaron',
      color: overdue ? AppColors.statusCritical : accent,
      icon: overdue ? Icons.warning_amber_rounded : Icons.groups_outlined,
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final RutaModule module;
  final DataProvider data;
  const _ModuleRow({required this.module, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              module.isMentorshipModule
                  ? Icons.diversity_3
                  : Icons.view_module_outlined,
              size: 15,
              color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title.isEmpty ? 'Módulo' : module.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (module.courseIds.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final courseId in module.courseIds)
                        _CourseChip(courseId: courseId),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nombre de un curso vinculado a un módulo de la Ruta.
///
/// El nombre no viene con el módulo —el módulo solo trae ids— así que se pide
/// el curso. Mientras llega se muestra un esqueleto del tamaño de la píldora,
/// no un hueco que haga saltar el resto de la tarjeta al cargar.
class _CourseChip extends StatelessWidget {
  final String courseId;
  const _CourseChip({required this.courseId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return data.courseById(courseId).when(
          loading: () =>
              Skeleton(width: 110, height: 24, radius: BorderRadius.circular(8)),
          // Un curso que no se puede leer no rompe la tarjeta de la fase: se
          // omite. El error de fondo ya se muestra donde corresponde.
          error: (_) => const SizedBox.shrink(),
          data: (course) => HoverCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    settings: RouteSettings(
                        name: '${AppRoutes.courses}/${course.id}'),
                    builder: (_) => CourseDetailView(courseId: course.id))),
            child:
                Text(course.name, style: const TextStyle(fontSize: 11.5)),
          ),
        );
  }
}
