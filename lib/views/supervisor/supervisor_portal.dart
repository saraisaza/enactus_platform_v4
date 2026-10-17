import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../lxd/course_tracking_view.dart';
import '../lxd/lxd_portal.dart' show VistaDeCalificaciones;

/// Portal del Manager / Supervisor de una empresa cliente.
///
/// Acompaña a la gente de su empresa: cómo va cada persona, qué entregó (y la
/// califica, si quiere), cómo va cada curso y quién se certificó. Qué personas,
/// entregas, cursos y certificados ve lo decide el servidor —solo los de su
/// empresa—: acá no se filtra nada.
class SupervisorPortal extends StatelessWidget {
  const SupervisorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: tr.supervisorPortal,
      tabs: [
        // En la barra, el rótulo corto: el largo no cabe. El título de la
        // pestaña sí dice «Personas de su empresa».
        PortalTab(
            label: tr.supervisorTabGenteCorto,
            shortLabel: tr.supervisorTabGenteCorto,
            destacada: true,
            icon: Icons.groups_outlined,
            builder: (_) => const _SuGente()),
        PortalTab(
            label: tr.tabCalificaciones,
            shortLabel: tr.tabCalificarCorto,
            destacada: true,
            icon: Icons.grading_outlined,
            builder: (_) => VistaDeCalificaciones(
                subtitulo: tr.supervisorEntregasSubtitulo)),
        PortalTab(
            // No son «mis» capacitaciones: el supervisor no las crea.
            label: tr.supervisorTabCapacitaciones,
            shortLabel: tr.tabCursosCorto,
            destacada: true,
            icon: Icons.school_outlined,
            builder: (_) => const _SusCursos()),
        PortalTab(
            label: tr.tabCalendario,
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _SuCalendario()),
        PortalTab(
            label: tr.tabCertificados,
            icon: Icons.workspace_premium_outlined,
            builder: (_) => const _SusCertificados()),
      ],
    );
  }
}

/// Los eventos de su empresa y de sus capacitaciones. Solo los ve: los crean
/// el LXD de la empresa y el admin.
class _SuCalendario extends StatelessWidget {
  const _SuCalendario();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return TabBody(
      title: tr.tabCalendario,
      subtitle: tr.calendarioSupervisorSubtitulo,
      children: [
        data.calendarEvents.when(
          loading: () => const CardListSkeleton(count: 1, height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          data: (events) => CalendarView(events: events),
        ),
      ],
    );
  }
}

/// La gente de su empresa, con su avance general.
class _SuGente extends StatelessWidget {
  const _SuGente();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return TabBody(
      title: tr.supervisorTabGente,
      subtitle: tr.supervisorGenteSubtitulo,
      children: [
        data.users(role: 'student,alumni', include: 'progress').when(
              loading: () => const CardListSkeleton(count: 4, height: 72),
              error: (e) => ErrorState(e),
              data: (gente) => gente.isEmpty
                  ? EmptyState(
                      icon: Icons.groups_outlined,
                      message: tr.supervisorSinGente)
                  : Column(
                      children: [
                        for (final persona in gente)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _Persona(persona: persona),
                          ),
                      ],
                    ),
            ),
      ],
    );
  }
}

class _Persona extends StatelessWidget {
  final AppUser persona;
  const _Persona({required this.persona});

  @override
  Widget build(BuildContext context) {
    final avance = persona.overallProgress;
    return HoverCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context)
          .pushNamed('${AppRoutes.users}/${persona.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.relleno,
            child: Text(
              persona.name.isEmpty ? '?' : persona.name[0].toUpperCase(),
              style: TextStyle(
                  color: AppColors.ink, fontWeight: AppWeights.uiSemibold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.name,
                    style: const TextStyle(
                        fontWeight: AppWeights.uiSemibold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                if (avance == null || avance.coursesTotal == 0)
                  Text(tr.supervisorSinCursos,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted))
                else ...[
                  ThinProgressBar(value: avance.ratio),
                  const SizedBox(height: 4),
                  Text(
                    tr.supervisorCursosTerminados(
                        avance.coursesDone, avance.coursesTotal),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Los cursos de su gente; cada uno abre el seguimiento, que el servidor
/// acota a las personas de su empresa.
class _SusCursos extends StatelessWidget {
  const _SusCursos();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return TabBody(
      title: tr.supervisorTabCapacitaciones,
      subtitle: tr.supervisorCursosSubtitulo,
      children: [
        data.courses.when(
          loading: () => const CardListSkeleton(count: 3, height: 72),
          error: (e) => ErrorState(e, onRetry: data.reloadCourses),
          data: (cursos) => cursos.isEmpty
              ? EmptyState(
                  icon: Icons.school_outlined, message: tr.supervisorSinCursosAun)
              : Column(
                  children: [
                    for (final curso in cursos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: HoverCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CourseTrackingView(courseId: curso.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.school_outlined, color: AppColors.gold),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(curso.name,
                                    style: const TextStyle(
                                        fontWeight: AppWeights.uiSemibold,
                                        color: AppColors.textPrimary)),
                              ),
                              Text(tr.supervisorVerAvance,
                                  style: TextStyle(
                                      color: AppColors.gold, fontSize: 13)),
                              Icon(Icons.chevron_right, color: AppColors.gold),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Quién de su empresa se certificó.
class _SusCertificados extends StatelessWidget {
  const _SusCertificados();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return TabBody(
      title: tr.tabCertificados,
      subtitle: tr.supervisorCertificadosSubtitulo,
      children: [
        data.certificates.when(
          loading: () => const CardListSkeleton(count: 3, height: 64),
          error: (e) => ErrorState(e, onRetry: data.reloadCertificates),
          data: (certificados) => certificados.isEmpty
              ? EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  message: tr.supervisorSinCertificados)
              : Column(
                  children: [
                    for (final c in certificados)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: HoverCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(Icons.workspace_premium_outlined,
                                  color: AppColors.gold),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.studentName,
                                        style: const TextStyle(
                                            fontWeight: AppWeights.uiSemibold,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        '${c.titulo} · ${fechaCorta(c.issuedAt)}',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
