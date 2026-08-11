import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/student_detail_view.dart';

/// Portal del Mentor (rol nuevo, sin relación con el "mentor" anterior,
/// que ahora es LXD). El Mentor no crea cursos: revisa la Ruta de Impacto
/// y las entregas de los estudiantes de sus laboratorios, y se une a la
/// reunión del módulo de mentoría de cada fase.
class MentorPortal extends StatelessWidget {
  const MentorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Mentor',
      tabs: [
        PortalTab(
            label: 'Mis Laboratorios',
            icon: Icons.science_outlined,
            builder: (_) => const _MentorLabs()),
        PortalTab(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _MentorCalendar()),
        PortalTab(
            label: 'Entregas',
            icon: Icons.assignment_turned_in_outlined,
            builder: (_) => const _MentorSubmissions()),
        PortalTab(
            label: 'Mi Perfil',
            icon: Icons.person_outline,
            builder: (_) => const _MentorProfile()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mis Laboratorios: estudiantes y avance de su Ruta de Impacto por fase
// ---------------------------------------------------------------------------

class _MentorLabs extends StatelessWidget {
  const _MentorLabs();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForMentor(mentor);

    return TabBody(
      title: 'Mis Laboratorios',
      subtitle: 'Laboratorios donde revisas la Ruta de Impacto de los estudiantes',
      children: [
        if (labs.isEmpty)
          const EmptyState(
              icon: Icons.science_outlined,
              message:
                  'Tu Admin aún no te asignó a ningún laboratorio (se hace desde la pestaña Laboratorios).')
        else
          for (final lab in labs) ...[
            SectionTitle(lab.name),
            _LabStudents(lab: lab),
          ],
      ],
    );
  }
}

class _LabStudents extends StatelessWidget {
  final Laboratory lab;
  const _LabStudents({required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = data.studentsAndAlumni
        .where((s) => s.labIds.contains(lab.id))
        .toList();

    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: EmptyState(
            icon: Icons.groups_outlined,
            message: 'Aún no hay estudiantes asignados a este laboratorio.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          for (final s in students)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoverCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StudentDetailView(studentId: s.id))),
                child: Row(
                  children: [
                    InitialsAvatar(s.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(s.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    for (var i = 0; i < lab.phases.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: PhaseBadge(
                          label: 'Fase ${i + 1}',
                          complete: data.isPhaseComplete(
                              s.id, lab.id, lab.phases[i]),
                          unlocked: data.isPhaseUnlocked(
                              s.id, lab.id, lab, i),
                        ),
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

// ---------------------------------------------------------------------------
// Calendario: eventos de Ruta de Impacto y reuniones de mentoría de sus
// laboratorios
// ---------------------------------------------------------------------------

class _MentorCalendar extends StatelessWidget {
  const _MentorCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final myLabs = data.labsForMentor(mentor);
    return TabBody(
      title: 'Calendario',
      subtitle:
          'Agenda eventos de la Ruta de Impacto y reuniones de mentoría de tus laboratorios',
      children: [
        CalendarView(
          events: data.calendarEventsFor(mentor),
          canManage: true,
          onAddEvent: (day) => showCalendarEventDialog(
            context,
            initialDay: day,
            allowedTypes: const [
              CalendarEventType.rutaImpacto,
              CalendarEventType.mentoria,
            ],
            courses: const [],
            labs: myLabs,
            defaultMeetLink: data.siteContent.meetingLink,
            onSave: (events) async {
              for (final e in events) {
                await data.saveCalendarEvent(e);
              }
            },
          ),
          onEditEvent: (event) => showCalendarEventDialog(
            context,
            existing: event,
            allowedTypes: const [
              CalendarEventType.rutaImpacto,
              CalendarEventType.mentoria,
            ],
            courses: const [],
            labs: myLabs,
            defaultMeetLink: data.siteContent.meetingLink,
            onSave: (events) async {
              for (final e in events) {
                await data.saveCalendarEvent(e);
              }
            },
          ),
          onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Entregas: revisión con comentario (el Mentor no califica, solo el LXD)
// ---------------------------------------------------------------------------

class _MentorSubmissions extends StatelessWidget {
  const _MentorSubmissions();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForMentor(mentor);

    // Entregas de cursos asignados a algún módulo de la Ruta de Impacto de
    // los laboratorios de este mentor — si además tiene cursos específicos
    // asignados (por Admin o por la empresa aliada), se acota a esos.
    final moduleCourseIds = <String>{};
    for (final lab in labs) {
      for (final phase in lab.phases) {
        for (final m in phase.modules) {
          moduleCourseIds.addAll(m.courseIds);
        }
      }
    }
    final courseIds = mentor.reviewCourseIds.isEmpty
        ? moduleCourseIds
        : moduleCourseIds.intersection(mentor.reviewCourseIds.toSet());
    final submissions = data.submissions
        .where((s) => courseIds.contains(s.courseId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return TabBody(
      title: 'Entregas',
      subtitle: mentor.reviewCourseIds.isEmpty
          ? 'Revisa y comenta las entregas de la Ruta de Impacto (la calificación la da el LXD)'
          : 'Cursos asignados: ${mentor.reviewCourseIds.map((id) => data.courseById(id)?.name).whereType<String>().join(', ')}',
      children: [
        if (submissions.isEmpty)
          const EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              message:
                  'No hay entregas para revisar todavía (aparecen cuando tu Admin asigna cursos a los módulos de una fase).')
        else
          ...submissions.map((s) {
            final student =
                s.studentId.isEmpty ? null : data.userById(s.studentId);
            final course = data.courseById(s.courseId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.taskName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(
                            '${student?.name ?? '—'} · ${course?.name ?? ''} · '
                            '${DateFormat('d MMM yyyy').format(s.date)}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          if (s.comment.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(s.comment,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ),
                          if (s.feedback.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Tu comentario: ${s.feedback}',
                                  style: const TextStyle(
                                      color: AppColors.gold, fontSize: 12.5)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _review(context, s),
                      child: Text(
                          s.feedback.isEmpty ? 'Comentar' : 'Editar'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _review(BuildContext context, Submission s) async {
    final data = context.read<DataProvider>();
    final feedbackCtrl = TextEditingController(text: s.feedback);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revisar: ${s.taskName}',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: feedbackCtrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Comentario (sin nota: el Mentor no califica)'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              s.feedback = feedbackCtrl.text.trim();
              await data.saveSubmission(s);
              if (s.studentId.isNotEmpty) {
                await data.notify(s.studentId, 'Entrega revisada',
                    '"${s.taskName}" tiene un comentario nuevo de tu Mentor.');
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Perfil
// ---------------------------------------------------------------------------

class _MentorProfile extends StatelessWidget {
  const _MentorProfile();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForMentor(mentor);

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
      subtitle: 'Información visible para administradores y estudiantes',
      children: [
        HoverCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mentor.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(mentor.email,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const Divider(height: 32),
              row('Laboratorios', labs.map((l) => l.name).join(', ')),
              row('Teléfono', mentor.phone),
              row('Ciudad', mentor.city),
            ],
          ),
        ),
      ],
    );
  }
}
