import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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
import 'ruta_impacto_view.dart' show LabDetailBody, LabsView, RutaImpactoShortcut;
import 'student_calendar_view.dart';
import 'student_courses_view.dart';
import 'student_dashboard_view.dart';

/// Portal del estudiante. Un estudiante Enactus ve Laboratorios y su Ruta
/// de Impacto; uno de Open Learning solo ve y completa sus cursos
/// asignados (sin laboratorios, fases ni módulos).
class StudentPortal extends StatelessWidget {
  /// Si no es null, se llegó por una URL de detalle de laboratorio
  /// (`/student/lab/<id>` o `/alumni/lab/<id>`): la pestaña "Laboratorios"
  /// se marca activa y su contenido se reemplaza por [LabDetailBody], sin
  /// duplicar la barra lateral.
  final String? openLabId;

  /// Pestaña con la que abrir cuando no hay [openLabId] — usado por
  /// "Todos los laboratorios" al volver de un detalle sin historial de
  /// navegación que hacer pop (p. ej. se entró por URL directa): en vez de
  /// caer al Dashboard, reabre el portal ya en "Laboratorios".
  final String? initialTabLabel;
  const StudentPortal({super.key, this.openLabId, this.initialTabLabel});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentUser!;
    final isEnactus = student.studentType == StudentType.enactus;

    final tabs = [
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
    ];
    final labTabIndex = tabs.indexWhere((t) => t.label == 'Laboratorios');
    final showLabDetail = openLabId != null && labTabIndex >= 0;
    final wantedTabIndex = showLabDetail
        ? labTabIndex
        : (initialTabLabel == null ? -1 : tabs.indexWhere((t) => t.label == initialTabLabel));

    return PortalShell(
      // Mismo portal para estudiante y alumni (ver Roles.isStudentLike):
      // solo cambia el título visible, según lo pidió el usuario ("que se
      // llame alumni").
      portalTitle: 'Portal ${Roles.label(student.role)}',
      tabs: tabs,
      initialSelectedIndex: wantedTabIndex >= 0 ? wantedTabIndex : 0,
      contentOverride: showLabDetail ? LabDetailBody(labId: openLabId!) : null,
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

/// Mi Perfil — rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 7). Cédula,
/// universidad, equipo, proyecto y patrocinador quedan de solo lectura
/// (los asigna el Admin); teléfono, carrera y foto se editan de verdad
/// desde [showEditProfileDialog].
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
    final labs = data.labsForStudent(student);
    final certs = data.certificatesForStudent(student.id);

    // `coursesForStudent` empareja solo por laboratorio: la Ruta National
    // Expo (sin labId) se suma aparte, igual que en Mis Cursos.
    final expoCourses = data.courses
        .where((c) => c.isRutaExpo && student.courseIds.contains(c.id));
    final allCourses = [...data.coursesForStudent(student), ...expoCourses];
    var totalLessons = 0;
    var doneLessons = 0;
    Course? closestCourse;
    var closestProgress = -1.0;
    for (final c in allCourses) {
      totalLessons += c.lessonCount;
      doneLessons += data.progressFor(student.id, c.id).completedLessonIds.length;
      final progress = data.courseProgress(student.id, c);
      if (progress < 1.0 && progress > closestProgress) {
        closestProgress = progress;
        closestCourse = c;
      }
    }

    final eyebrow = student.joinedAt != null
        ? 'Miembro activo desde ${student.joinedAt!.year}'
        : 'Miembro de la comunidad';

    return ContentScreenShell(
      eyebrow: eyebrow,
      title: 'Mi Perfil',
      searchHint: 'Buscar en el portal',
      bodyBuilder: (context, colors, isDark) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IdentityBand(
                student: student, project: project, group: group, colors: colors),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final tiles = [
                _ProfileStat(value: '${allCourses.length}', label: 'Cursos activos'),
                _ProfileStat(value: '$doneLessons/$totalLessons', label: 'Lecciones completadas'),
                _ProfileStat(value: '${labs.length}', label: 'Laboratorios'),
                _ProfileStat(value: '${certs.length}', label: 'Certificados'),
              ];
              final perRow = c.maxWidth > 700 ? 4 : 2;
              final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    SizedBox(
                        width: width,
                        child: _ProfileStatCard(
                            stat: tiles[i], isPrimary: i == 0, colors: colors)),
                ],
              );
            }),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final personal = _GroupCard(
                title: 'Datos personales',
                icon: Icons.badge_outlined,
                rows: [
                  ('Cédula', student.cedula),
                  ('Teléfono', student.phone),
                  ('Correo', student.email),
                  ('Carrera', student.career),
                ],
                colors: colors,
              );
              final enactusLife = _GroupCard(
                title: 'Vida Enactus',
                icon: Icons.workspaces_outlined,
                rows: [
                  ('Universidad', student.university),
                  ('Equipo', group?.name ?? ''),
                  ('Laboratorios', labs.map((l) => l.name).join(', ')),
                  ('Empresa patrocinadora', sponsor?.companyName ?? ''),
                ],
                colors: colors,
              );
              if (c.maxWidth > 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: personal),
                    const SizedBox(width: 20),
                    Expanded(child: enactusLife),
                  ],
                );
              }
              return Column(
                  children: [personal, const SizedBox(height: 20), enactusLife]);
            }),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final projectCard = _ProjectCard(project: project, colors: colors);
              final certCard = _CertificatesCard(
                  certs: certs, closestCourse: closestCourse, colors: colors);
              if (c.maxWidth > 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 130, child: projectCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 100, child: certCard),
                  ],
                );
              }
              return Column(
                  children: [projectCard, const SizedBox(height: 20), certCard]);
            }),
          ],
        );
      },
    );
  }
}

class _IdentityBand extends StatelessWidget {
  final AppUser student;
  final Project? project;
  final Group? group;
  final ContentColors colors;
  const _IdentityBand(
      {required this.student, required this.project, required this.group, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.slate),
                const CustomPaint(painter: StripePainter()),
                if (project != null)
                  Positioned(
                    right: 26,
                    bottom: -22,
                    child: Text(project!.name.toUpperCase(),
                        style: knockoutHeading(
                            fontSize: 104,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold.withValues(alpha: 0.16),
                            height: 1.0)),
                  ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                      border: Border.all(color: colors.surface, width: 5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: student.avatarBase64 != null
                        ? Image.memory(base64Decode(student.avatarBase64!),
                            fit: BoxFit.cover, width: 110, height: 110)
                        : Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
                            style: knockoutHeading(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1400))),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(student.name.toUpperCase(),
                            style: knockoutHeading(
                                fontSize: 44, fontWeight: FontWeight.w800, color: colors.text)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.mail_outline, size: 17, color: colors.text3),
                            const SizedBox(width: 8),
                            Text(student.email,
                                style: TextStyle(fontSize: 14, color: colors.text2)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CredentialChip(
                                icon: Icons.school_outlined,
                                label: Roles.label(student.role),
                                gold: true,
                                colors: colors),
                            if (student.university.isNotEmpty)
                              _CredentialChip(
                                  icon: Icons.apartment_outlined,
                                  label: student.university,
                                  gold: false,
                                  colors: colors),
                            if (student.career.isNotEmpty)
                              _CredentialChip(
                                  icon: Icons.engineering_outlined,
                                  label: student.career,
                                  gold: false,
                                  colors: colors),
                            if (group != null)
                              _CredentialChip(
                                  icon: Icons.groups_outlined,
                                  label: group!.name,
                                  gold: false,
                                  colors: colors),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => showEditProfileDialog(context, student, colors),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text('Editar perfil'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: colors.goldInk, side: BorderSide(color: colors.goldInk)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gold;
  final ContentColors colors;
  const _CredentialChip(
      {required this.icon, required this.label, required this.gold, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: gold ? colors.goldSoft : colors.surface2,
        border: Border.all(color: gold ? colors.goldInk : colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: gold ? colors.goldInk : colors.text2),
          const SizedBox(width: 7),
          Text(label,
              style:
                  TextStyle(fontSize: 12.5, color: gold ? colors.goldInk : colors.text2)),
        ],
      ),
    );
  }
}

class _ProfileStat {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});
}

class _ProfileStatCard extends StatelessWidget {
  final _ProfileStat stat;
  final bool isPrimary;
  final ContentColors colors;
  const _ProfileStatCard({required this.stat, required this.isPrimary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(stat.value,
              style: knockoutHeading(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? colors.goldInk : colors.text,
                  height: 1.0)),
          const SizedBox(height: 6),
          Text(stat.label, style: TextStyle(fontSize: 12.5, color: colors.text3)),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final ContentColors colors;
  const _GroupCard(
      {required this.title, required this.icon, required this.rows, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: colors.goldSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: colors.goldInk),
              ),
              const SizedBox(width: 11),
              Text(title.toUpperCase(),
                  style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: colors.border))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].$1, style: TextStyle(fontSize: 13, color: colors.text3)),
                  Flexible(
                    child: Text(rows[i].$2.isEmpty ? '—' : rows[i].$2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: colors.text)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project? project;
  final ContentColors colors;
  const _ProjectCard({required this.project, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (project == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text('Aún no tienes proyecto asignado.',
            style: TextStyle(fontSize: 13.5, color: colors.text3)),
      );
    }
    final odsColor = project!.ods.isNotEmpty ? odsColorFor(project!.ods.first) : AppColors.gold;
    final odsNum = project!.ods.isNotEmpty ? odsNumberFrom(project!.ods.first) : 1;
    final stageIndex = projectStages.indexOf(project!.stage);
    final currentIndex = stageIndex < 0 ? 0 : stageIndex;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: odsColor),
                const CustomPaint(painter: StripePainter()),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [Colors.transparent, colors.veil],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: -16,
                  child: Text('$odsNum',
                      style: knockoutHeading(
                          fontSize: 78,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.32),
                          height: 1.0)),
                ),
                Positioned(
                  left: 18,
                  top: 16,
                  child: Text('MI PROYECTO',
                      style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 11.5 * 0.16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                ),
                Positioned(
                  left: 18,
                  bottom: 14,
                  child: Text(project!.name.toUpperCase(),
                      style: knockoutHeading(
                          fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (project!.description.isNotEmpty)
                  Text(project!.description,
                      style: TextStyle(fontSize: 14, height: 1.5, color: colors.text2)),
                if (project!.impactIndicators.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(project!.impactIndicators,
                      style: TextStyle(fontSize: 14, color: colors.text2)),
                ],
                const SizedBox(height: 14),
                StageRail(accentColor: odsColor, colors: colors, currentIndex: currentIndex),
                if (project!.ods.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final o in project!.ods) _ProfileOdsTag(label: o, colors: colors),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOdsTag extends StatelessWidget {
  final String label;
  final ContentColors colors;
  const _ProfileOdsTag({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: odsColorFor(label), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
        ],
      ),
    );
  }
}

class _CertificatesCard extends StatelessWidget {
  final List<Certificate> certs;
  final Course? closestCourse;
  final ContentColors colors;
  const _CertificatesCard(
      {required this.certs, required this.closestCourse, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 19, color: colors.goldInk),
              const SizedBox(width: 10),
              Text('Certificados'.toUpperCase(),
                  style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
            ],
          ),
          const SizedBox(height: 16),
          if (certs.isEmpty)
            Builder(builder: (context) {
              final data = context.watch<DataProvider>();
              final student = context.watch<AuthProvider>().currentUser!;
              return DashedRRectBorder(
                color: colors.border,
                radius: 14,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty, size: 32, color: colors.text3),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                            closestCourse == null
                                ? 'Aún no tienes certificados. Completa una Ruta de Impacto para obtener el primero.'
                                : 'Te falta poco para tu primer certificado: '
                                    '"${closestCourse!.name}".',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: colors.text2)),
                      ),
                      if (closestCourse != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ThinProgressBar(
                            value: data.courseProgress(student.id, closestCourse!),
                            color: labColorFor(closestCourse!.labId),
                            tooltip:
                                '${data.progressFor(student.id, closestCourse!.id).completedLessonIds.length} '
                                'de ${closestCourse!.lessonCount} lecciones',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            })
          else
            for (final cert in certs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration:
                      BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium, size: 22, color: colors.goldInk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ruta de Impacto · ${cert.labName}',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: colors.text)),
                            Text('Emitido el ${DateFormat('d MMM yyyy').format(cert.date)}',
                                style: TextStyle(fontSize: 12, color: colors.text3)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.download_outlined, color: colors.goldInk),
                        tooltip: 'Descargar certificado',
                        onPressed: () => PdfService.download(cert),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Editar perfil: solo teléfono, carrera y foto son editables — cédula,
/// universidad, equipo, proyecto y patrocinador los asigna el Admin y
/// quedan de solo lectura en la vista principal.
Future<void> showEditProfileDialog(
    BuildContext context, AppUser student, ContentColors colors) async {
  final phoneCtrl = TextEditingController(text: student.phone);
  final careerCtrl = TextEditingController(text: student.career);
  String? avatarBase64 = student.avatarBase64;
  var saving = false;
  var pickingImage = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Editar perfil', style: TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.gold,
                        backgroundImage:
                            avatarBase64 == null ? null : MemoryImage(base64Decode(avatarBase64!)),
                        child: avatarBase64 != null
                            ? null
                            : Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF1A1400),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 26)),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.slate,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: pickingImage
                                ? null
                                : () async {
                                    setState(() => pickingImage = true);
                                    try {
                                      final result = await FilePicker.pickFiles(
                                        dialogTitle: 'Selecciona una foto',
                                        type: FileType.image,
                                        withData: true,
                                      );
                                      final bytes = result?.files.single.bytes;
                                      if (bytes != null) {
                                        setState(() => avatarBase64 = base64Encode(bytes));
                                      }
                                    } finally {
                                      setState(() => pickingImage = false);
                                    }
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: pickingImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: careerCtrl,
                  decoration: const InputDecoration(labelText: 'Carrera'),
                ),
                const SizedBox(height: 6),
                Text(
                    'Cédula, universidad, equipo, proyecto y empresa patrocinadora '
                    'los asigna tu administrador.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(color: AppColors.statusCritical, fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    final phone = phoneCtrl.text.trim();
                    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 7) {
                      setState(() => error = 'Ingresa un teléfono válido (mínimo 7 dígitos).');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      student.phone = phone;
                      student.career = careerCtrl.text.trim();
                      student.avatarBase64 = avatarBase64;
                      await context.read<DataProvider>().saveUser(student);
                      if (context.mounted) context.read<AuthProvider>().refresh();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showSuccessCheck(context, 'Perfil actualizado ✓');
                      }
                    } catch (_) {
                      setState(() {
                        saving = false;
                        error = 'No se pudo guardar. Intenta de nuevo.';
                      });
                    }
                  },
            child: Text(saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}
