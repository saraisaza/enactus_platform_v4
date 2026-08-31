import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/students_map_view.dart';
import '../shared/talent_search_view.dart';
import '../shared/user_detail_view.dart';

/// Portal del Donante: a quiénes apoya, dónde están y qué se logró con su
/// aporte.
///
/// Su alcance —"los estudiantes que apoya"— lo aplica el servidor. La
/// excepción deliberada es BuscaTalento, que muestra a toda la red eduXaction:
/// esa pantalla existe para descubrir a alguien que todavía no conoce.
class DonorPortal extends StatelessWidget {
  const DonorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Donante',
      tabs: [
        PortalTab(
            label: 'Mi Impacto',
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const _DonorDashboard()),
        PortalTab(
            label: 'Mapa de Estudiantes',
            icon: Icons.public,
            builder: (_) => const StudentsMapView()),
        PortalTab(
            label: 'Evidencias',
            icon: Icons.photo_library_outlined,
            builder: (_) => const _DonorEvidences()),
        PortalTab(
            label: 'BuscaTalento',
            icon: Icons.search,
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
    final donante = context.watch<AuthProvider>().currentUser;

    return TabBody(
      title: 'Mi Impacto',
      subtitle: 'A quiénes apoyás y cómo van',
      children: [
        if ((donante?.impactCode ?? '').isNotEmpty) ...[
          HoverCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Código de impacto: ${donante!.impactCode}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        combine2(data.users(include: 'team,progress'), data.evidences).when(
          loading: () => const CardListSkeleton(count: 2, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadEvidences),
          data: (values) {
            final (estudiantes, evidencias) = values;
            final conAvance = estudiantes
                .where((e) => (e.overallProgress?.coursesTotal ?? 0) > 0)
                .toList();
            final promedio = conAvance.isEmpty
                ? 0.0
                : conAvance
                        .map((e) => e.overallProgress!.ratio)
                        .reduce((a, b) => a + b) /
                    conAvance.length;

            return Column(
              children: [
                StatRow(tiles: [
                  StatTile(
                      value: '${estudiantes.length}',
                      label: 'Estudiantes apoyados',
                      icon: Icons.school_outlined),
                  StatTile(
                      value: '${(promedio * 100).round()}%',
                      label: 'Avance promedio',
                      icon: Icons.trending_up),
                  StatTile(
                      value: '${evidencias.length}',
                      label: 'Evidencias recibidas',
                      icon: Icons.photo_library_outlined),
                ]),
                const SectionTitle('Estudiantes que apoyás'),
                if (estudiantes.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline,
                    message: 'Todavía no hay estudiantes vinculados a tu '
                        'aporte. En cuanto tu administrador asigne alguno, '
                        'aparecerá acá.',
                  )
                else
                  for (final e in estudiantes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentCard(student: e),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final AppUser student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final avance = student.overallProgress;

    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserDetailView(userId: student.id)),
      ),
      child: Row(
        children: [
          InitialsAvatar(student.name, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (student.university.isNotEmpty) student.university,
                    if (student.team != null) student.team!.projectName,
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 90, child: ThinProgressBar(value: avance?.ratio ?? 0)),
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

    return TabBody(
      title: 'Evidencias de Impacto',
      subtitle: 'Fotos, historias y reportes de lo que tu aporte hizo posible',
      children: [
        data.evidences.when(
          loading: () => const CardListSkeleton(count: 3, height: 120),
          error: (e) => ErrorState(e, onRetry: data.reloadEvidences),
          data: (evidencias) => evidencias.isEmpty
              ? const EmptyState(
                  icon: Icons.photo_library_outlined,
                  message: 'Todavía no hay evidencias para tu aporte.')
              : Column(
                  children: [
                    for (final ev in evidencias)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EvidenceCard(evidence: ev),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final Evidence evidence;
  const _EvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism_outlined,
                  color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(evidence.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusChip(
                  label: Evidence.typeLabel(evidence.type),
                  color: AppColors.textSecondary,
                  icon: Icons.label_outline),
            ],
          ),
          if (evidence.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(evidence.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text(DateFormat('d MMM yyyy').format(evidence.evidenceDate),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          if (evidence.s3Key != null) ...[
            const SizedBox(height: 10),
            // Un botón visible siempre, no revelado por hover: en una pantalla
            // táctil el hover no existe y la acción quedaba invisible.
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver archivo'),
                onPressed: () => _abrir(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    final clave = evidence.s3Key;
    if (clave == null) return;
    final data = context.read<DataProvider>();
    try {
      // La URL firmada vence en una hora: se pide al tocar, no al dibujar.
      final url = await data.resolveFileUrl(clave);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          'No pudimos mostrar este archivo. Puede que no sea '
                          'una imagen.'),
                    )),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}
