import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/submission_attachment.dart';
import '../shared/communication_resources_view.dart';
import '../shared/lab_detail_view.dart';
import '../shared/projects_directory_view.dart' show ProjectsDirectoryView;
import '../shared/user_detail_view.dart';

/// Portal del Mentor: acompaña laboratorios, revisa entregas y coordina
/// mentorías.
///
/// Un mentor **revisa y comenta; no califica**. Es una distinción real del
/// modelo —la nota tiene su propio autor y su propia escala— y el servidor la
/// sostiene: `POST /submissions/:id/review` guarda la retroalimentación sin
/// tocar la nota.
class MentorPortal extends StatelessWidget {
  const MentorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: tr.mentorPortal,
      tabs: [
        PortalTab(
            label: tr.tabMisLaboratorios,
            shortLabel: tr.tabLaboratorios,
            destacada: true,
            icon: Icons.science_outlined,
            builder: (_) => const _MentorLabs()),
        PortalTab(
            label: tr.tabProyectosCorto,
            destacada: true,
            icon: Icons.lightbulb_outline,
            builder: (_) => const ProjectsDirectoryView()),
        PortalTab(
            label: tr.tabCalendario,
            destacada: true,
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _MentorCalendar()),
        PortalTab(
            label: tr.tabEntregas,
            destacada: true,
            icon: Icons.assignment_turned_in_outlined,
            builder: (_) => const _MentorSubmissions()),
        PortalTab(
            label: tr.tabMiPerfil,
            shortLabel: tr.tabPerfilCorto,
            icon: Icons.person_outline,
            builder: (_) => const _MentorProfile()),
        PortalTab(
            label: tr.tabRecursosComunicaciones,
            shortLabel: tr.tabRecursosCorto,
            icon: Icons.perm_media_outlined,
            builder: (_) => const CommunicationResourcesView()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Laboratorios y sus estudiantes
// ---------------------------------------------------------------------------

class _MentorLabs extends StatelessWidget {
  const _MentorLabs();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: tr.tabMisLaboratorios,
      subtitle: tr.mentorLabsSubtitulo,
      children: [
        data.laboratories.when(
          loading: () => const CardListSkeleton(count: 3, height: 140),
          error: (e) => ErrorState(e, onRetry: data.reloadLaboratories),
          data: (labs) => labs.isEmpty
              ? EmptyState(
                  icon: Icons.science_outlined,
                  message: tr.mentorSinLabs)
              : Column(
                  children: [
                    for (final lab in labs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LabCard(lab: lab),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LabCard extends StatelessWidget {
  final Laboratory lab;
  const _LabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '${AppRoutes.labs}/${lab.id}'),
          builder: (_) => LabDetailView(labId: lab.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(lab.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              // Flexible: con la letra agrandada la ficha no cabía junto al
              // nombre del laboratorio.
              Flexible(
                child: StatusChip(
                  label: tr.usuarioEstudiantes(lab.studentsAssigned),
                  color: AppColors.textSecondary,
                  icon: Icons.people_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Las fases con cuántos las completaron: el avance del GRUPO, que es
          // el que le sirve a un mentor. El avance personal de cada estudiante
          // vive en su perfil.
          //
          // `Wrap` y no `Row`: con tres o más fases una fila desborda, y tres
          // fases es lo normal.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phase in lab.phases)
                PhaseBadge(
                  label: phase.title.isEmpty
                      ? tr.rutaFaseNumero(phase.orderIndex)
                      : phase.title,
                  complete: phase.completedByCount >= lab.studentsAssigned &&
                      lab.studentsAssigned > 0,
                  unlocked: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          data.users(laboratoryId: lab.id, include: 'progress').when(
                loading: () => const CardListSkeleton(count: 2, height: 44),
                error: (e) => ErrorBanner(e),
                data: (estudiantes) => estudiantes.isEmpty
                    ? Text(tr.mentorSinEstudiantes,
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted))
                    : Column(
                        children: [
                          for (final e in estudiantes)
                            _StudentRow(student: e),
                        ],
                      ),
              ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final AppUser student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final avance = student.overallProgress?.ratio ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserDetailView(userId: student.id)),
        ),
        // 48 dp de alto mínimo: la fila medía 40 y en el teléfono es el
        // único camino al perfil de cada estudiante.
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              InitialsAvatar(student.name, radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(student.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 90,
                child: ThinProgressBar(value: avance),
              ),
              const SizedBox(width: 8),
              Text('${(avance * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendario
// ---------------------------------------------------------------------------

class _MentorCalendar extends StatelessWidget {
  const _MentorCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: tr.tabCalendario,
      subtitle: tr.mentorCalendarioSubtitulo,
      children: [
        combine2(data.calendarEvents, data.laboratories).when(
          loading: () => const CardListSkeleton(count: 1, height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          data: (values) {
            final (events, labs) = values;
            final meetLink = data.siteContent.valueOrNull?.meetingLink ?? '';

            Future<void> guardar(
              List<CalendarEvent> nuevos,
              String? idQueSeEdita,
            ) async {
              for (final e in nuevos) {
                await data.saveCalendarEvent(e, id: idQueSeEdita);
              }
            }

            return CalendarView(
              events: events,
              canManage: true,
              // Un mentor crea mentorías, no sesiones de Open Learning: el
              // servidor rechaza los otros tipos igual.
              onAddEvent: (day) => showCalendarEventDialog(
                context,
                initialDay: day,
                allowedTypes: const [CalendarEventType.mentoria],
                courses: const [],
                labs: labs,
                defaultMeetLink: meetLink,
                onSave: guardar,
              ),
              onEditEvent: (event) => showCalendarEventDialog(
                context,
                existing: event,
                allowedTypes: const [CalendarEventType.mentoria],
                courses: const [],
                labs: labs,
                defaultMeetLink: meetLink,
                onSave: guardar,
              ),
              onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Entregas: revisar y comentar
// ---------------------------------------------------------------------------

class _MentorSubmissions extends StatelessWidget {
  const _MentorSubmissions();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: tr.tabEntregas,
      subtitle: tr.mentorEntregasSubtitulo,
      children: [
        const _ReviewNotice(),
        const SizedBox(height: 12),
        data.submissions.when(
          loading: () => const CardListSkeleton(count: 4, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadSubmissions),
          data: (entregas) => entregas.isEmpty
              ? EmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  message: tr.mentorSinEntregas)
              : Column(
                  children: [
                    for (final s in entregas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubmissionCard(submission: s),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice();

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              tr.mentorComoMentor,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final revisada = submission.reviewedBy != null;

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(submission.taskName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        // Nombre, curso y lección vienen resueltos con la
                        // entrega: antes eran tres búsquedas por fila.
                        if (submission.authorLabel.isNotEmpty)
                          submission.authorLabel,
                        if (submission.courseName != null)
                          submission.courseName!,
                        fechaCorta(submission.submittedAt),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (revisada)
                StatusChip(
                    label: tr.mentorRevisada,
                    color: AppColors.statusGood,
                    icon: Icons.check_circle_outline)
              else
                StatusChip(
                    label: tr.mentorSinRevisar,
                    color: AppColors.statusSerious,
                    icon: Icons.pending_actions_outlined),
            ],
          ),
          if (submission.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(submission.comment,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          for (final file in submission.files)
            SubmissionAttachmentRow(file: file),
          if (submission.feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tr.mentorSuComentario(submission.feedback),
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: Text(revisada ? tr.mentorEditarComentario : tr.foroRevisar),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _ReviewDialog(submission: submission),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final Submission submission;
  const _ReviewDialog({required this.submission});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _feedback;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _feedback = TextEditingController(text: widget.submission.feedback);
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_feedback.text.trim().isEmpty) {
      setState(() => _error =
          ValidationError(tr.mentorEscribaComentario));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      await data.reviewSubmission(
        submissionId: widget.submission.id,
        feedback: _feedback.text.trim(),
      );
      // El estudiante se entera de que ya la revisaron.
      final studentId = widget.submission.studentId;
      if (studentId != null) {
        // El texto se guarda en español —lo que ve una app vieja— y con su
        // tipo, para que el estudiante lo lea en su idioma.
        final es = lookupAppLocalizations(const Locale('es'));
        await data.notify(
          [studentId],
          title: es.avisoEntregaRevisadaTitulo,
          body: es.avisoMentorComentoCuerpo(widget.submission.taskName),
          kind: 'mentor_comento',
          params: {'tarea': widget.submission.taskName},
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, tr.mentorComentarioGuardado);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: tr.mentorRevisarEntrega,
      maxWidth: 460,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          Text(widget.submission.taskName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            tr.mentorReviseComente,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback,
            enabled: !_saving,
            maxLines: 5,
            decoration:
                InputDecoration(labelText: tr.mentorSuRetro),
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
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return TabBody(
      title: tr.tabMiPerfil,
      subtitle: tr.mentorPerfilSubtitulo,
      children: [
        HoverCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(user.name, large: true, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(user.email,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Etiqueta y valor apilados en pantallas angostas: con la
              // etiqueta fija en 160px se comía la mitad del ancho de un
              // teléfono.
              for (final dato in [
                (tr.perfilTelefonoEtiqueta, user.phone),
                (tr.perfilCiudad, user.city),
                (tr.perfilCargo, '${user.profile['position'] ?? ''}'),
                (tr.perfilEspecialidad, '${user.profile['specialty'] ?? ''}'),
                (tr.perfilIdiomas, '${user.profile['languages'] ?? ''}'),
                (tr.perfilDisponibilidad, '${user.profile['availability'] ?? ''}'),
                (tr.perfilExperiencia, '${user.profile['experience'] ?? ''}'),
              ])
                if (dato.$2.isNotEmpty) _ProfileRow(label: dato.$1, value: dato.$2),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final etiqueta = Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted));
          final valor = Text(value, style: const TextStyle(fontSize: 13.5));

          if (c.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [etiqueta, const SizedBox(height: 2), valor],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: etiqueta),
              Expanded(child: valor),
            ],
          );
        },
      ),
    );
  }
}
