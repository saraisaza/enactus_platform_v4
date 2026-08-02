import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/talent_search_view.dart';

/// Portal del donante: transparencia total sobre el uso de su aporte.
class DonorPortal extends StatelessWidget {
  const DonorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Donante',
      tabs: [
        PortalTab(
            label: 'Mi Impacto',
            icon: Icons.favorite_outline,
            builder: (_) => const _DonorDashboard()),
        PortalTab(
            label: 'Evidencias',
            icon: Icons.photo_library_outlined,
            builder: (_) => const _DonorEvidences()),
        PortalTab(
            label: 'BuscaTalento',
            icon: Icons.people_alt_outlined,
            builder: (_) => const TalentSearchView()),
      ],
    );
  }
}

class _DonorDashboard extends StatelessWidget {
  const _DonorDashboard();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final donor = context.watch<AuthProvider>().currentUser!;
    final supported = data.studentsForDonor(donor.id);

    return TabBody(
      title: 'Gracias, ${donor.name} 💛',
      subtitle: 'Código de impacto: ${donor.impactCode}',
      children: [
        // Código de impacto destacado
        HoverCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2,
                    color: AppColors.gold, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(donor.impactCode,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                            letterSpacing: 1.5)),
                    const Text(
                      'Tu código único de impacto: rastrea todo lo que tu aporte hace posible.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Estudiantes que apoyas'),
        if (supported.isEmpty)
          const EmptyState(
              icon: Icons.school_outlined,
              message:
                  'El administrador aún no ha vinculado estudiantes a tu aporte.')
        else
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > 900 ? 2 : 1;
            final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in supported)
                  SizedBox(width: width, child: _StudentProfileCard(student: s)),
              ],
            );
          }),
      ],
    );
  }
}

/// Tarjeta de perfil: identidad y proyecto del estudiante apoyado, sin
/// detalle de progreso ni de fases (eso lo ve el Asesor).
class _StudentProfileCard extends StatelessWidget {
  final AppUser student;
  const _StudentProfileCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final group = data.groupById(student.groupId);
    final project = group == null ? null : data.projectById(group.projectId);

    return HoverCard(
      child: Row(
        children: [
          InitialsAvatar(student.name,
              large: true, radius: 24, fontSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${student.university} · ${student.career}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                if (project != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Proyecto: ${project.name}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorEvidences extends StatelessWidget {
  const _DonorEvidences();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final donor = context.watch<AuthProvider>().currentUser!;
    final evidences = data.evidencesForDonor(donor.id)
      ..sort((a, b) => b.date.compareTo(a.date));

    return TabBody(
      title: 'Evidencias de tu Impacto',
      subtitle:
          'Historias, testimonios y reportes de los beneficiarios de tu aporte',
      children: [
        if (evidences.isEmpty)
          const EmptyState(
              icon: Icons.photo_library_outlined,
              message: 'Pronto verás aquí las evidencias de tu impacto.')
        else
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > 900 ? 2 : 1;
            final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in evidences)
                  SizedBox(
                    width: width,
                    // Al pasar el mouse la tarjeta se oscurece ligeramente
                    // y aparece "Ver historia →"; clic abre el detalle.
                    child: HoverBuilder(
                      cursor: SystemMouseCursors.click,
                      builder: (context, hover) => GestureDetector(
                        onTap: () => _showStory(context, e),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: hover
                                        ? AppColors.gold
                                        : AppColors.border),
                              ),
                              foregroundDecoration: BoxDecoration(
                                color: hover
                                    ? Colors.black
                                        .withValues(alpha: 0.35)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(_typeIcon(e.type),
                                          color: AppColors.gold,
                                          size: 22),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(e.title,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w700)),
                                      ),
                                      StatusChip(
                                          label: e.type,
                                          color: AppColors.slateLight,
                                          icon: _typeIcon(e.type)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(e.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                      DateFormat('d MMM yyyy')
                                          .format(e.date),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: hover ? 1 : 0,
                                  duration:
                                      const Duration(milliseconds: 180),
                                  child: const Center(
                                    child: Text('Ver historia →',
                                        style: TextStyle(
                                            color: AppColors.goldBright,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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

  void _showStory(BuildContext context, Evidence e) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(_typeIcon(e.type), color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(e.title, style: const TextStyle(fontSize: 18))),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.description,
                  style: const TextStyle(height: 1.6, fontSize: 14)),
              const SizedBox(height: 14),
              Text(
                  '${e.type[0].toUpperCase()}${e.type.substring(1)} · '
                  '${DateFormat('d MMMM yyyy', 'es').format(e.date)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
