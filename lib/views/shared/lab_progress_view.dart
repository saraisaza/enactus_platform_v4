import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';

/// Progreso de UN estudiante en UN laboratorio, de solo lectura — para que
/// otro rol (LXD, Mentor, Asesor, Empresa, Donante, Admin) vea mentor,
/// fases y módulos reales de ese estudiante sin poder actuar en su nombre.
/// A diferencia de `LabDetailBody` (la pantalla del propio estudiante), no
/// tiene botón "Empezar/Continuar la fase" ni abre módulos con entregas.
class LabProgressView extends StatelessWidget {
  final String studentId;
  final String labId;
  const LabProgressView({super.key, required this.studentId, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(labId);
    final student = data.userById(studentId);

    if (lab == null || student == null) {
      return Scaffold(
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Laboratorio'),
            const Expanded(
              child: EmptyState(
                  icon: Icons.science_outlined, message: 'Laboratorio no encontrado.'),
            ),
          ],
        ),
      );
    }

    final accent = labColorFor(lab.id);
    final mentors = data.mentorsForLab(lab.id);
    final sponsor =
        lab.sponsorCompanyId.isEmpty ? null : data.userById(lab.sponsorCompanyId);
    final progress = data.labModuleProgress(studentId, lab);
    final phasesDone =
        lab.phases.where((p) => data.isPhaseComplete(studentId, lab.id, p)).length;

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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lab.name.toUpperCase(),
                                          style: knockoutHeading(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary)),
                                      Text('Progreso de ${student.name}',
                                          style: const TextStyle(
                                              fontSize: 13.5, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (lab.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Text(lab.description,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
                              ),
                            StatRow(tiles: [
                              StatTile(
                                  value: '$phasesDone/${lab.phases.length}',
                                  label: 'Fases completas',
                                  icon: Icons.flag_outlined),
                              StatTile(
                                  value: '${progress.done}/${progress.total}',
                                  label: 'Módulos completos',
                                  icon: Icons.task_alt),
                            ]),
                            const SizedBox(height: 8),
                            SectionTitle('Mentor${mentors.length == 1 ? '' : 'es'}'),
                            if (mentors.isEmpty)
                              const Text('Sin mentor asignado todavía.',
                                  style: TextStyle(fontSize: 13.5, color: AppColors.textMuted))
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final m in mentors)
                                    _PersonChip(user: m, subtitle: 'Mentor'),
                                ],
                              ),
                            if (sponsor != null) ...[
                              const SizedBox(height: 10),
                              Text('Empresa patrocinadora: ${sponsor.name}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                            SectionTitle('Fases'),
                            for (var i = 0; i < lab.phases.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReadOnlyPhaseCard(
                                    lab: lab, index: i, studentId: studentId, accent: accent),
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

class _PersonChip extends StatelessWidget {
  final AppUser user;
  final String subtitle;
  const _PersonChip({required this.user, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(user.name),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyPhaseCard extends StatelessWidget {
  final Laboratory lab;
  final int index;
  final String studentId;
  final Color accent;
  const _ReadOnlyPhaseCard(
      {required this.lab, required this.index, required this.studentId, required this.accent});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final phase = lab.phases[index];
    final unlocked = data.isPhaseUnlocked(studentId, lab.id, lab, index);
    final complete = data.isPhaseComplete(studentId, lab.id, phase);
    final published = data.labPhaseContentPublished(phase);
    final deadlineStatus = data.phaseDeadlineStatus(studentId, lab.id, phase);
    final title = phase.title.isEmpty ? 'Fase ${index + 1}' : phase.title;

    final locked = !complete && (!unlocked || !published);
    final overdue = !complete && !locked && deadlineStatus == DeadlineStatus.overdue;

    final (chipColor, chipIcon, chipLabel) = complete
        ? (AppColors.statusGood, Icons.check_circle, 'Completa')
        : overdue
            ? (AppColors.statusCritical, Icons.warning_amber_rounded, 'Vencida')
            : locked
                ? (AppColors.textMuted, Icons.lock_outline, 'Bloqueada')
                : (AppColors.gold, Icons.lock_open, 'Disponible');

    final total = phase.modules.length;
    final done = phase.modules.where((m) => data.isModuleComplete(studentId, lab.id, m)).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: locked ? AppColors.border : accent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${index + 1}. $title',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              StatusChip(label: chipLabel, color: chipColor, icon: chipIcon),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
                !unlocked
                    ? 'Se abre cuando complete la fase anterior.'
                    : 'El LXD aún no publica contenido de esta fase.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ] else ...[
            const SizedBox(height: 10),
            for (final m in phase.modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                        data.isModuleComplete(studentId, lab.id, m)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: data.isModuleComplete(studentId, lab.id, m)
                            ? AppColors.statusGood
                            : AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(m.title.isEmpty ? 'Módulo' : m.title,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  ],
                ),
              ),
            if (total > 0) ...[
              const SizedBox(height: 4),
              Text('$done de $total módulos',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ],
          if (phase.deadline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${overdue ? 'Entrega vencida' : 'Entrega'}: '
              '${DateFormat('d MMM yyyy', 'es').format(DateTime.parse(phase.deadline))}',
              style: TextStyle(
                  fontSize: 12, color: overdue ? AppColors.statusCritical : AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
