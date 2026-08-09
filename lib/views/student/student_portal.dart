import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/forum_view.dart';
import '../shared/projects_directory_view.dart';
import 'ruta_impacto_view.dart' show LabsView, RutaImpactoShortcut;
import 'student_calendar_view.dart';
import 'student_courses_view.dart';
import 'student_dashboard_view.dart';

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
            builder: (_) => const StudentDashboardView()),
        PortalTab(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const StudentCalendarView()),
        PortalTab(
            label: 'Mis Cursos',
            icon: Icons.school_outlined,
            builder: (_) => const StudentCoursesView()),
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
