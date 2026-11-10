import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_states.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/projects_directory_view.dart' show ProjectDetailView;
import 'course_detail_view.dart';

/// Lo que la persona tiene esta semana, en una frase: sus cursos y sus
/// entregas y, si tiene laboratorios, cuántos y con cuántas entregas.
///
/// Va debajo del saludo, donde antes decía «Aún no tiene proyecto asignado»
/// —que a quien no es de un equipo de Enactus no le decía nada, y a quien sí
/// lo es tampoco le decía qué hacer—.
String resumenDeLaSemana({
  required int cursosActivos,
  required int entregasDeCursos,
  required int laboratorios,
  required int entregasDeLaboratorios,
}) {
  final deCursos = entregasDeCursos == 0
      ? tr.dashboardSemanaSinEntregas
      : cursosActivos == 0
          ? tr.dashboardSemanaSoloEntregas(entregasDeCursos)
          : tr.dashboardSemanaCursosYEntregas(cursosActivos, entregasDeCursos);
  // Una empresa y un Open Learning no tienen laboratorios: ni se nombran.
  if (laboratorios == 0) return deCursos;
  final deLaboratorios = entregasDeLaboratorios == 0
      ? tr.dashboardSemanaLabsSinEntregas(laboratorios)
      : tr.dashboardSemanaLabsConEntregas(laboratorios, entregasDeLaboratorios);
  return '$deCursos $deLaboratorios';
}

/// Las entregas sin hacer que vencen entre [lunes] y [domingo].
List<Entrega> entregasDeLaSemana(
        List<Entrega> todas, DateTime lunes, DateTime domingo) =>
    [
      for (final e in todas)
        if (!e.done && e.venceEntre(lunes, domingo)) e,
    ];

/// Dashboard del estudiante: lo que tiene esta semana, el acceso rápido a su
/// curso o a la fase de su laboratorio, progreso por curso, pendientes
/// priorizados, última entrega calificada y estado del proyecto.
///
/// Nada de esto se calcula acá. El avance por curso, el desbloqueo de módulos
/// y el estado de cada fecha límite los resuelve el servidor y llegan ya
/// hechos: antes se recalculaban en cada `build()`, y dos tarjetas de la misma
/// pantalla podían discrepar.
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({super.key});

  /// El resumen de la semana, o `null` mientras falta algún dato: decir «no
  /// tiene entregas» antes de saberlo sería afirmar algo que quizá no es.
  String? _resumen(DataProvider data, AppUser student, DateTime lunes,
      DateTime domingo) {
    final cursos = data.courses.valueOrNull;
    final entregas = data.entregas.valueOrNull;
    if (cursos == null || entregas == null) return null;
    var laboratorios = 0;
    if (student.isEnactusStudent) {
      final ruta = data.rutaProgress;
      // Si la Ruta no llegó, se dice lo de los cursos y nada de laboratorios.
      if (ruta.valueOrNull == null && ruta.errorOrNull == null) return null;
      laboratorios = ruta.valueOrNull?.laboratories.length ?? 0;
    }
    final semana = entregasDeLaSemana(entregas, lunes, domingo);
    return resumenDeLaSemana(
      cursosActivos: [
        for (final c in cursos)
          if (data.courseProgress(c.id).valueOrNull?.isComplete != true) c,
      ].length,
      entregasDeCursos: semana.where((e) => !e.esDeLaboratorio).length,
      laboratorios: laboratorios,
      entregasDeLaboratorios: semana.where((e) => e.esDeLaboratorio).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    // "Semana del 5 al 11 de octubre"; en inglés siempre con el mes en las
    // dos fechas ("Week of Oct 5 to Oct 11").
    final eyebrow = monday.month == sunday.month && Idioma.instancia.codigo == 'es'
        ? tr.dashboardSemanaDel(dia(monday), diaMes(sunday))
        : tr.dashboardSemanaDel(diaMesCorto(monday), diaMesCorto(sunday));

    return ContentScreenShell(
      eyebrow: eyebrow,
      title: tr.dashboardHola(student.name.split(' ').first),
      // Mientras carga va un espacio, para que la cabecera no salte cuando
      // llegue la frase.
      subtitle: _resumen(data, student, monday, sunday) ??
          (data.entregas.errorOrNull == null ? '\u00A0' : null),
      searchHint: tr.perfilBuscarPortal,
      trailingBuilder: (context, colors, isDark) =>
          _OverallProgress(student: student, colors: colors),
      bodyBuilder: (context, colors, isDark) => data.courses.when(
        loading: () => const CardListSkeleton(count: 3),
        error: (e) => ErrorState(e, onRetry: data.reloadCourses),
        data: (courses) {
          if (courses.isEmpty) {
            // Sin cursos todavía puede haber un laboratorio asignado, con su
            // Ruta: antes esta pantalla decía «todo por empezar» y no
            // mostraba por dónde.
            final ruta = student.isEnactusStudent ? data.rutaProgress : null;
            if (ruta != null &&
                ruta.valueOrNull == null &&
                ruta.errorOrNull == null) {
              return const CardListSkeleton(count: 3);
            }
            if (ruta?.valueOrNull?.laboratories.isEmpty ?? true) {
              return EmptyState(
                icon: Icons.school_outlined,
                title: tr.dashboardTodoPorEmpezar,
                message: tr.dashboardSinCursos,
                primaryLabel: tr.comunActualizar,
                onPrimary: data.reloadCourses,
                colors: colors,
              );
            }
          }
          return _DashboardBody(
              student: student, courses: courses, colors: colors);
        },
      ),
    );
  }
}

/// El anillo de avance del encabezado.
///
/// Se cuentan lecciones, no se promedian porcentajes: un curso de 40 lecciones
/// y uno de 4 no pesan lo mismo, y promediar sus porcentajes diría que sí.
class _OverallProgress extends StatelessWidget {
  final AppUser student;
  final ContentColors colors;
  const _OverallProgress({required this.student, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final courses = data.courses.valueOrNull;

    var totalLessons = 0;
    var doneLessons = 0;
    if (courses != null) {
      for (final course in courses) {
        final progress = data.courseProgress(course.id).valueOrNull;
        if (progress == null) continue;
        totalLessons += progress.totalLessons;
        doneLessons += progress.completedLessons;
      }
    }
    final ratio = totalLessons == 0 ? 0.0 : doneLessons / totalLessons;
    // Una empresa no tiene laboratorios: ni siquiera «0 laboratorios».
    final labCount = student.esDeEmpresa
        ? null
        : student.isEnactusStudent
            ? data.rutaProgress.valueOrNull?.laboratories.length
            : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressRing(
              value: ratio,
              size: 96,
              strokeWidth: 10,
              percentFontSize: 24,
              colors: colors),
          const SizedBox(width: 20),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr.dashboardProgresoGeneral,
                    style: TextStyle(fontSize: 13, color: colors.text3)),
                const SizedBox(height: 4),
                Text(tr.leccionesDeTotal(doneLessons, totalLessons),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                const SizedBox(height: 4),
                Text(
                    tr.dashboardCursosActivos(courses?.length ?? 0) +
                        (labCount == null
                            ? ''
                            : ' · ${tr.dashboardLaboratorios(labCount)}'),
                    style: TextStyle(fontSize: 12.5, color: colors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final AppUser student;
  final List<Course> courses;
  final ContentColors colors;
  const _DashboardBody(
      {required this.student, required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final team = student.team;
    // Los proyectos son de Enactus: en una empresa no hay tarjeta de proyecto.
    final project = team == null || student.esDeEmpresa
        ? null
        : data.projectById(team.projectId).valueOrNull;

    return LayoutBuilder(builder: (context, c) {
      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
              child: _ContinueCard(
                  student: student, courses: courses, colors: colors)),
          if (courses.isNotEmpty) ...[
            const SizedBox(height: 20),
            Entrance(
                delayMs: 90,
                child: _CourseProgressCard(courses: courses, colors: colors)),
          ],
        ],
      );
      final right = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
              delayMs: 60,
              child: _PendingCard(
                  student: student, courses: courses, colors: colors)),
          const SizedBox(height: 20),
          Entrance(delayMs: 150, child: _RecentActivityCard(colors: colors)),
          if (project != null) ...[
            const SizedBox(height: 20),
            Entrance(
                delayMs: 210,
                child: _ProjectCard(project: project, colors: colors)),
          ],
        ],
      );
      if (c.maxWidth > 800) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 155, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 100, child: right),
          ],
        );
      }
      return Column(children: [left, const SizedBox(height: 20), right]);
    });
  }
}

/// El acceso rápido: el curso que tiene a medias o, si no tiene ninguno, la
/// fase en curso de cada laboratorio asignado.
///
/// Un empleado de una empresa y un Open Learning solo tienen cursos, así que
/// siempre ven su curso. Un estudiante de Enactus ve su curso mientras tenga
/// uno a medias y, cuando no, por dónde va en su laboratorio.
class _ContinueCard extends StatelessWidget {
  final AppUser student;
  final List<Course> courses;
  final ContentColors colors;
  const _ContinueCard(
      {required this.student, required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    Course? course;
    CourseProgress? progress;
    for (final candidate in courses) {
      final state = data.courseProgress(candidate.id).valueOrNull;
      if (state != null && !state.isComplete) {
        course = candidate;
        progress = state;
        break;
      }
    }

    if (course == null || progress == null) {
      final laboratorios = student.isEnactusStudent
          ? [
              for (final lab in data.rutaProgress.valueOrNull?.laboratories ??
                  const <LabProgress>[])
                if (!lab.isComplete && lab.phases.isNotEmpty) lab,
            ]
          : const <LabProgress>[];
      if (laboratorios.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < laboratorios.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              _LabPhaseCard(
                  student: student, lab: laboratorios[i], colors: colors),
            ],
          ],
        );
      }
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.goldInk, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(tr.dashboardTodoCompletado,
                  style: TextStyle(fontSize: 14, color: colors.text2)),
            ),
          ],
        ),
      );
    }

    final accent = labColorFor(course.laboratoryId ?? '');
    final tinta = inkSobre(accent);
    final compacto = context.isCompact;
    final courseId = course.id;

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
          Container(
            // Sin ancho, el `Container` se ajusta al `Stack`, y el `Stack` al
            // texto más largo: la banda de color terminaba antes del borde de
            // la tarjeta. No se veía mientras el título iba a 38 px porque
            // llenaba la fila igual; al bajarlo en teléfono quedó a la vista.
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(color: accent),
            child: Stack(
              children: [
                const Positioned.fill(
                    child: CustomPaint(painter: StripePainter())),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr.dashboardContinueDonde,
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 12 * 0.16,
                            fontWeight: FontWeight.w600,
                            color: tinta.withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    Text(course.name.toUpperCase(),
                        style: displayHeading(
                            fontSize: compacto ? 24 : 38,
                            fontWeight: AppWeights.display,
                            color: tinta)),
                    // El nombre del laboratorio viene con el curso: no hace
                    // falta pedirlo aparte por cada tarjeta.
                    if (course.laboratoryName != null &&
                        !Idioma.instancia.deEmpresa) ...[
                      const SizedBox(height: 4),
                      Text(course.laboratoryName!,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: tinta.withValues(alpha: 0.88))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThinProgressBar(value: progress.ratio, color: accent),
                      const SizedBox(height: 6),
                      Text(
                          tr.leccionesDeTotal(progress.completedLessons, progress.totalLessons),
                          style:
                              TextStyle(fontSize: 12.5, color: colors.text3)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 19),
                  label: Text(tr.comunContinuar),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(
                              name: '${AppRoutes.courses}/$courseId'),
                          builder: (_) =>
                              CourseDetailView(courseId: courseId))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso rápido a la fase en curso de un laboratorio: en cuál va, cuánto
/// lleva, cuándo vence y un botón que lo deja ahí.
class _LabPhaseCard extends StatelessWidget {
  final AppUser student;
  final LabProgress lab;
  final ContentColors colors;
  const _LabPhaseCard(
      {required this.student, required this.lab, required this.colors});

  @override
  Widget build(BuildContext context) {
    // La que le toca: la primera sin completar, en el orden de la Ruta.
    final indice = lab.phases.indexWhere((p) => !p.isComplete);
    final numero = indice < 0 ? lab.phases.length : indice + 1;
    final fase = lab.phases[numero - 1];
    final accent = labColorFor(lab.laboratoryId);
    final tinta = inkSobre(accent);
    final compacto = context.isCompact;
    final vence = fase.deadlineDate;

    void abrir() => Navigator.pushNamed(context,
        '${AppRoutes.forRole(student.role)}/lab/${lab.laboratoryId}');

    return Container(
      key: ValueKey('acceso-laboratorio-${lab.laboratoryId}'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(color: accent),
            child: Stack(
              children: [
                const Positioned.fill(
                    child: CustomPaint(painter: StripePainter())),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr.dashboardFaseEnCurso,
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 12 * 0.16,
                            fontWeight: FontWeight.w600,
                            color: tinta.withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    Text(
                        (fase.title.isEmpty
                                ? tr.rutaFaseNumero(numero)
                                : fase.title)
                            .toUpperCase(),
                        style: displayHeading(
                            fontSize: compacto ? 24 : 38,
                            fontWeight: AppWeights.display,
                            color: tinta)),
                    const SizedBox(height: 4),
                    Text(lab.laboratoryName,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: tinta.withValues(alpha: 0.88))),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThinProgressBar(value: fase.ratio, color: accent),
                      const SizedBox(height: 6),
                      Text(
                          [
                            tr.rutaFaseDe(numero, lab.phases.length),
                            tr.rutaModulosDeTotal(
                                fase.modulesDone, fase.modulesTotal),
                            if (vence != null)
                              tr.labFechaLimite(fechaCorta(vence)),
                          ].join(' · '),
                          style:
                              TextStyle(fontSize: 12.5, color: colors.text3)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 19),
                  label: Text(tr.dashboardIrALaFase),
                  onPressed: abrir,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  final List<Course> courses;
  final ContentColors colors;
  const _CourseProgressCard({required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr.dashboardProgresoPorCurso.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 16),
          for (final course in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: KeyboardHoverBuilder(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: RouteSettings(
                            name: '${AppRoutes.courses}/${course.id}'),
                        builder: (_) =>
                            CourseDetailView(courseId: course.id))),
                builder: (context, hover) => Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: colors.text)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ThinProgressBar(
                          value:
                              data.courseProgress(course.id).valueOrNull?.ratio ??
                                  0,
                          color: labColorFor(course.laboratoryId ?? '')),
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

class _PendingRow {
  final IconData icon;
  final Color color;
  final String title;
  final String meta;
  final VoidCallback? onTap;
  const _PendingRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.meta,
      this.onTap});
}

/// Pendientes, en orden de urgencia: fases vencidas, entregas de esta semana,
/// mentorías por confirmar, cursos a medias y tareas del checklist del equipo.
///
/// Qué está vencido, qué está desbloqueado y qué está completo lo dice el
/// servidor. Un Open Learning no tiene fases ni mentorías —y pedirlas le daría
/// 403— así que para esas cuentas la tarjeta solo lista cursos.
class _PendingCard extends StatelessWidget {
  final AppUser student;
  final List<Course> courses;
  final ContentColors colors;
  const _PendingCard(
      {required this.student, required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final overdue = <_PendingRow>[];
    final deLaSemana = <_PendingRow>[];
    final mentoring = <_PendingRow>[];
    final toContinue = <_PendingRow>[];
    final teamTasks = <_PendingRow>[];

    if (student.isEnactusStudent) {
      final ruta = data.rutaProgress.valueOrNull;
      for (final lab in ruta?.laboratories ?? const <LabProgress>[]) {
        for (final phase in lab.phases) {
          if (phase.deadlineStatus == DeadlineStatus.overdue) {
            overdue.add(_PendingRow(
              icon: Icons.warning_amber_rounded,
              color: AppColors.statusCritical,
              title:
                  tr.dashboardFaseVencida(
                      phase.title.isEmpty ? tr.comunFase : phase.title),
              meta: lab.laboratoryName,
              onTap: () => Navigator.pushNamed(context,
                  '${AppRoutes.forRole(student.role)}/lab/${lab.laboratoryId}'),
            ));
          }
          for (final module in phase.modules) {
            if (!module.isMentorshipModule) continue;
            if (module.isUnlocked && !module.isComplete) {
              mentoring.add(_PendingRow(
                icon: Icons.diversity_3,
                color: AppColors.gold,
                title:
                    tr.dashboardConfirmarMentoria(
                        phase.title.isEmpty ? tr.comunFase : phase.title),
                meta: lab.laboratoryName,
                onTap: () => Navigator.pushNamed(
                    context,
                    '${AppRoutes.forRole(student.role)}'
                    '/lab/${lab.laboratoryId}'),
              ));
            }
          }
        }
      }
    }

    // Las entregas que el encabezado cuenta: acá se ve cuáles son.
    final hoy = DateTime.now();
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    for (final entrega in entregasDeLaSemana(
        data.entregas.valueOrNull ?? const <Entrega>[],
        lunes,
        lunes.add(const Duration(days: 6)))) {
      // Una fase que ya venció sale arriba como «fase vencida»: no dos veces.
      if (entrega.tipo == TipoDeEntrega.faseDeLaboratorio &&
          entrega.dueDate.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
        continue;
      }
      final cursoId = entrega.courseId;
      final labId = entrega.laboratoryId;
      deLaSemana.add(_PendingRow(
        icon: Icons.assignment_outlined,
        color: labColorFor(labId ?? ''),
        title: tr.dashboardEntregaPendiente(entrega.title.isEmpty
            ? tr.rutaFaseNumero(entrega.phaseOrder ?? 1)
            : entrega.title),
        meta: [
          if (!entrega.esDeLaboratorio && entrega.courseName != null)
            entrega.courseName!
          else if (entrega.laboratoryName != null)
            entrega.laboratoryName!,
          tr.dashboardVenceEl(diaMesCorto(entrega.dueDate)),
        ].join(' · '),
        onTap: !entrega.esDeLaboratorio && cursoId != null
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    settings:
                        RouteSettings(name: '${AppRoutes.courses}/$cursoId'),
                    builder: (_) => CourseDetailView(courseId: cursoId)))
            : labId != null
                ? () => Navigator.pushNamed(context,
                    '${AppRoutes.forRole(student.role)}/lab/$labId')
                : null,
      ));
    }

    for (final course in courses) {
      final progress = data.courseProgress(course.id).valueOrNull;
      if (progress == null || progress.isComplete) continue;
      toContinue.add(_PendingRow(
        icon: Icons.play_circle_outline,
        color: labColorFor(course.laboratoryId ?? ''),
        title: tr.dashboardContinuarCurso(course.name),
        meta: (Idioma.instancia.deEmpresa ? null : course.laboratoryName) ??
            (course.isRutaExpo
                ? tr.cursoRutaNationalExpo
                : student.esDeEmpresa
                    ? tr.busquedaTipoCurso
                    : 'Open Learning'),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                settings:
                    RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
                builder: (_) => CourseDetailView(courseId: course.id))),
      ));
    }

    final team = student.team;
    // Los equipos y su checklist de National Expo son de Enactus.
    final group = team == null || student.esDeEmpresa
        ? null
        : data.groupById(team.groupId).valueOrNull;
    if (group != null) {
      for (final item in group.pendingChecklist) {
        teamTasks.add(_PendingRow(
          icon: Icons.description_outlined,
          color: AppColors.textMuted,
          title: item.label,
          meta: tr.dashboardChecklistExpo,
          onTap: () => _showChecklistDialog(context, colors, group.checklist),
        ));
      }
    }

    final items = [
      ...overdue,
      ...deLaSemana,
      ...mentoring,
      ...toContinue,
      ...teamTasks,
    ].take(6).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr.dashboardPendientes.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(tr.dashboardAlDia,
                style: TextStyle(fontSize: 13.5, color: colors.text3))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KeyboardHoverBuilder(
                  onTap: item.onTap,
                  builder: (context, hover) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border(left: BorderSide(color: item.color, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 19, color: item.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13.5, color: colors.text)),
                              Text(item.meta,
                                  style: TextStyle(
                                      fontSize: 12, color: colors.text3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Checklist RUTA NATIONAL EXPO del equipo, de solo lectura.
///
/// No existe ninguna pantalla que lo edite, y la API tampoco expone escritura:
/// llega dentro del equipo (`GET /groups/:id`). Construir esa edición sería
/// una función nueva, no una migración.
void _showChecklistDialog(
    BuildContext context, ContentColors colors, List<ChecklistItem> items) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(tr.dashboardChecklistTitulo),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                        item.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color:
                            item.done ? AppColors.statusGood : colors.text3),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                fontSize: 13.5, color: colors.text))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(tr.comunCerrar)),
      ],
    ),
  );
}

class _RecentActivityCard extends StatelessWidget {
  final ContentColors colors;
  const _RecentActivityCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr.dashboardActividadReciente.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 14),
          // `/submissions` ya devuelve solo las propias cuando quien pregunta
          // es un estudiante.
          data.submissions.when(
            loading: () => const CardSkeleton(height: 80),
            error: (e) =>
                ErrorState(e, onRetry: data.reloadSubmissions, compact: true),
            data: (all) => _lastGraded(context, all),
          ),
        ],
      ),
    );
  }

  Widget _lastGraded(BuildContext context, List<Submission> all) {
    final graded = all.where((s) => s.isGraded).toList()
      ..sort((a, b) => b.gradedAt!.compareTo(a.gradedAt!));

    if (graded.isEmpty) {
      return Text(tr.dashboardSinCalificadas,
          style: TextStyle(fontSize: 13.5, color: colors.text3));
    }

    final data = context.watch<DataProvider>();
    final submission = graded.first;
    final courseId = submission.courseId;
    final course =
        courseId == null ? null : data.courseById(courseId).valueOrNull;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(14)),
              // La nota se muestra en SU escala: un 100 significa cosas
              // distintas en `passfail` y en `points100`.
              child: Text(submission.gradeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.goldInk,
                      height: 1.1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(submission.taskName,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.text)),
                  Text(
                      tr.dashboardCalificadoEl(
                              fechaCorta(submission.gradedAt!)) +
                          (course?.creatorName == null
                              ? ''
                              : ' · ${course!.creatorName}'),
                      style: TextStyle(fontSize: 12, color: colors.text3)),
                ],
              ),
            ),
          ],
        ),
        if (submission.feedback.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Text('"${submission.feedback}"',
              style:
                  TextStyle(fontSize: 13, height: 1.55, color: colors.text2)),
        ],
      ],
    );

    if (course == null) return content;
    return KeyboardHoverBuilder(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings:
                  RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
              builder: (_) => CourseDetailView(courseId: course.id))),
      builder: (context, hover) => content,
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final ContentColors colors;
  const _ProjectCard({required this.project, required this.colors});

  @override
  Widget build(BuildContext context) {
    final odsColor =
        project.ods.isNotEmpty ? odsColorFor(project.ods.first) : AppColors.relleno;
    final stageIndex = projectStages.indexOf(project.stage);
    final currentIndex = stageIndex < 0 ? 0 : stageIndex;

    return KeyboardHoverBuilder(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings:
                  RouteSettings(name: '${AppRoutes.projects}/${project.id}'),
              builder: (_) => ProjectDetailView(projectId: project.id))),
      builder: (context, hover) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: hover ? AppColors.gold : colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr.dashboardSuProyecto.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.text3,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(project.name.toUpperCase(),
                style: displayHeading(
                    fontSize: 30,
                    fontWeight: AppWeights.display,
                    color: colors.text)),
            const SizedBox(height: 14),
            StageRail(
                accentColor: odsColor,
                colors: colors,
                currentIndex: currentIndex),
            if (project.impactIndicators.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(project.impactIndicators,
                  style: TextStyle(fontSize: 13, color: colors.text2)),
            ],
          ],
        ),
      ),
    );
  }
}
