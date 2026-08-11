import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'course_detail_view.dart';

String _durationLabel(Course course) {
  if (course.estimatedHours > 0) return '${course.estimatedHours} h estimadas';
  final minutes = course.lessonCount * 15;
  return minutes < 60 ? '$minutes min estimados' : '${(minutes / 60).toStringAsFixed(1)} h estimadas';
}

/// Mis Cursos — rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 3): cursos de
/// laboratorio asignados por el administrador, más la Ruta National Expo
/// del equipo (`Course.isRutaExpo`) — trabajo real del equipo, ya no
/// excluido como en la implementación anterior.
class StudentCoursesView extends StatefulWidget {
  const StudentCoursesView({super.key});

  @override
  State<StudentCoursesView> createState() => _StudentCoursesViewState();
}

class _StudentCoursesViewState extends State<StudentCoursesView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForStudent(student);
    // `coursesForStudent` solo empareja por laboratorio (Course.labId), así
    // que nunca incluye la Ruta National Expo (labId vacío, isRutaExpo:
    // true, asignada por courseIds) — se suma aparte, solo en esta
    // pantalla, para no alterar el conteo de "cursos activos" del
    // Dashboard ni de otras pantallas que también llaman a
    // coursesForStudent.
    final expoCourses = data.courses
        .where((c) => c.isRutaExpo && student.courseIds.contains(c.id));
    final allCourses = [...data.coursesForStudent(student), ...expoCourses];

    var courses = allCourses;
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      courses = courses.where((c) {
        final lab = data.labById(c.labId);
        final teacher = c.creatorId.isEmpty ? null : data.userById(c.creatorId);
        final haystack = [c.name, c.description, lab?.name ?? '', teacher?.name ?? '']
            .join(' ')
            .toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    return ContentScreenShell(
      eyebrow: labs.isEmpty ? 'Cursos asignados' : labs.map((l) => l.name).join(' · '),
      title: 'Mis Cursos',
      subtitle: 'Cursos de laboratorio asignados por tu administrador, más la '
          'ruta de preparación de tu equipo para National Expo.',
      searchHint: 'Buscar curso o laboratorio',
      onSearchChanged: (v) => setState(() => _query = v),
      bodyBuilder: (context, colors, isDark) {
        if (courses.isEmpty) {
          return EmptyState(
            icon: Icons.school_outlined,
            title: 'Sin cursos asignados',
            message: allCourses.isEmpty
                ? 'Aún no tienes cursos asignados por tu administrador.'
                : 'Ningún curso coincide con tu búsqueda. Prueba con otro término.',
            primaryLabel: 'Limpiar búsqueda',
            onPrimary: () => setState(() => _query = ''),
            colors: colors,
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          const minCard = 392.0;
          const gap = 20.0;
          final columns =
              math.max(1, ((constraints.maxWidth + gap) / (minCard + gap)).floor());
          final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < courses.length; i++)
                SizedBox(
                  width: cardWidth,
                  child: Entrance(
                    delayMs: 55 * i,
                    child: _CourseCard(course: courses[i], studentId: student.id, colors: colors),
                  ),
                ),
            ],
          );
        });
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final String studentId;
  final ContentColors colors;
  const _CourseCard({required this.course, required this.studentId, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(course.labId);
    final teacher = course.creatorId.isEmpty ? null : data.userById(course.creatorId);
    final progress = data.courseProgress(studentId, course);
    final done = data.progressFor(studentId, course.id).completedLessonIds.length;
    final accent = labColorFor(course.labId);
    final labLabel = course.isRutaExpo ? 'Ruta National Expo' : (lab?.name ?? '');

    void open() => Navigator.push(
        context,
        MaterialPageRoute(
            settings: RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
            builder: (_) => CourseDetailView(courseId: course.id)));

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          transform: Matrix4.translationValues(0, hover ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? accent : colors.border),
            borderRadius: BorderRadius.circular(18),
            boxShadow: hover ? colors.shadow : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: BoxDecoration(color: accent),
                child: Stack(
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: StripePainter())),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color(0x6B0A0C0E),
                              borderRadius: BorderRadius.circular(11)),
                          child: Icon(
                              course.isRutaExpo ? Icons.emoji_events : Icons.play_circle_outline,
                              size: 22,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(course.name.toUpperCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: knockoutHeading(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.02)),
                              if (labLabel.isNotEmpty)
                                Text(labLabel,
                                    style: TextStyle(
                                        fontSize: 12.5, color: Colors.white.withValues(alpha: 0.88))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (course.description.isNotEmpty)
                      Text(course.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, height: 1.5, color: colors.text2)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _MetaChip(icon: Icons.view_module, label: '${course.modules.length} módulos', colors: colors),
                        _MetaChip(icon: Icons.play_lesson, label: '${course.lessonCount} lecciones', colors: colors),
                        _MetaChip(icon: Icons.signal_cellular_alt, label: course.level, colors: colors),
                        _MetaChip(icon: Icons.schedule, label: _durationLabel(course), colors: colors),
                        if (course.generatesCertificate)
                          _MetaChip(icon: Icons.workspace_premium, label: 'Certificado', colors: colors),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('$done de ${course.lessonCount} lecciones · ${(progress * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: colors.text3)),
                    const SizedBox(height: 6),
                    ThinProgressBar(value: progress, color: accent),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              course.isRutaExpo
                                  ? 'Trabajo en equipo'
                                  : 'Docente: ${teacher?.name ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: colors.text3)),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: open,
                          style: TextButton.styleFrom(
                            backgroundColor: colors.goldSoft,
                            foregroundColor: colors.goldInk,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: Text(progress > 0 ? 'Continuar' : 'Comenzar',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ContentColors colors;
  const _MetaChip({required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.text3),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
        ],
      ),
    );
  }
}
