import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/glossary.dart';
import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/file_viewer.dart';
import '../../widgets/glosario.dart';
import '../../widgets/lesson_visuals.dart';
import '../../widgets/submission_attachment.dart';
import '../../widgets/video_player_dialog.dart';
import '../../widgets/youtube_lesson_player.dart';
import '../../widgets/visor_pdf.dart';

/// Detalle de un curso: módulos y lecciones de todos los tipos, avance y
/// entregas.
///
/// Por defecto ([studentId] nulo) muestra y deja editar el avance de quien
/// tiene la sesión abierta. Con [studentId] muestra el de ESE estudiante en
/// solo lectura — es como lo abre un Mentor, Asesor o LXD desde el perfil de
/// alguien. El servidor decide si quien pregunta puede: un estudiante pidiendo
/// el avance de otro recibe 403, no una pantalla vacía.
class CourseDetailView extends StatelessWidget {
  final String courseId;
  final String? studentId;

  /// Para quien administra: el curso como lo ve un estudiante, sin entrar a
  /// editarlo y sin avance propio que pedir ni guardar.
  final bool vistaPrevia;

  const CourseDetailView(
      {super.key,
      required this.courseId,
      this.studentId,
      this.vistaPrevia = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final viewer = context.watch<AuthProvider>().currentUser;
    final readOnly =
        vistaPrevia || (studentId != null && studentId != viewer?.id);

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: tr.busquedaTipoCurso),
          Expanded(
            child: combine2(
              data.courseById(courseId),
              vistaPrevia
                  ? AsyncValue.data(CourseProgress.empty(courseId))
                  : data.courseProgress(courseId, studentId: studentId),
            ).when(
              loading: () => const Center(child: BrandLoader()),
              error: (e) => ErrorState(e, onRetry: () async {
                await data.reloadCourse(courseId);
                await data.reloadCourseProgress(courseId,
                    studentId: studentId);
              }),
              data: (values) {
                final (course, progress) = values;
                return _CourseBody(
                  course: course,
                  progress: progress,
                  studentId: studentId,
                  readOnly: readOnly,
                  vistaPrevia: vistaPrevia,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBody extends StatelessWidget {
  final Course course;
  final CourseProgress progress;
  final String? studentId;
  final bool readOnly;
  final bool vistaPrevia;

  const _CourseBody({
    required this.course,
    required this.progress,
    required this.studentId,
    required this.readOnly,
    this.vistaPrevia = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final glosarioAsync = data.glossaryOf(course.id);
    final glosario = glosarioAsync.valueOrNull ?? const CourseGlossary();
    // El repaso se guarda a nombre de quien tiene la sesión: solo si es un
    // estudiante mirando SU curso, no alguien del equipo mirando el de otro.
    final viewer = context.watch<AuthProvider>().currentUser;
    final puedeRepasar =
        !readOnly && viewer != null && Roles.isStudentLike(viewer.role);

    // Las lecciones se hacen en orden: la que le toca y las ya hechas están
    // abiertas; las demás, con candado y el nombre de la que falta.
    final siguiente = progress.nextLessonId;
    final tituloSiguiente = siguiente == null
        ? null
        : course.modules
            .expand((m) => m.lessons)
            .where((l) => l.id == siguiente)
            .firstOrNull
            ?.title;
    final entregas = data.submissions.valueOrNull ?? const <Submission>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
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
                          Text(course.name,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold)),
                          if (course.subtitle.isNotEmpty)
                            Text(course.subtitle,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                        ],
                      ),
                    ),
                    StatusChip(
                        label: course.levelLabel,
                        color: AppColors.slateLight,
                        icon: Icons.signal_cellular_alt),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          course.fullDescription.isNotEmpty
                              ? course.fullDescription
                              : course.description,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (course.estimatedHours > 0)
                            _meta(Icons.schedule,
                                tr.cursoHorasEstimadas(course.estimatedHours)),
                          _meta(Icons.language, course.language),
                          if (course.generatesCertificate)
                            _meta(Icons.workspace_premium_outlined,
                                tr.cursoGeneraCertificado),
                          if (course.laboratoryName != null)
                            _meta(Icons.science_outlined,
                                course.laboratoryName!),
                          for (final tag in course.tags.take(4))
                            _meta(Icons.tag, tag),
                        ],
                      ),
                      if (course.objectives.isNotEmpty) ...[
                        SectionTitle(tr.cursoObjetivos),
                        for (final objective in course.objectives)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 15, color: AppColors.gold),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(objective.text,
                                        style:
                                            const TextStyle(fontSize: 13.5))),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (readOnly) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 17, color: AppColors.textMuted),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                vistaPrevia
                                    ? tr.cursoVistaPreviaTexto
                                    : tr.cursoSoloLectura,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 16),
                  child: ThinProgressBar(
                    value: progress.ratio,
                    tooltip: tr.leccionesDeTotal(progress.completedLessons, progress.totalLessons),
                  ),
                ),
                const SizedBox(height: 16),
                if (course.modules.isEmpty)
                  EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: tr.cursoSinContenido)
                else
                  // Plegables: los terminados, juntos y cerrados al pie; los
                  // demás, abiertos. Y un botón para plegarlos o
                  // desplegarlos todos (recomendaciones del 20 de noviembre).
                  _ModulosPlegables(
                    modulos: course.modules,
                    conDetalle: progress.hasLessonDetail,
                    completo: (m) =>
                        m.lessons.isNotEmpty &&
                        m.lessons.every((l) => progress.isLessonComplete(l.id)),
                    hechas: (m) => m.lessons
                        .where((l) => progress.isLessonComplete(l.id))
                        .length,
                    contenido: (module) => [
                    for (final lesson in module.lessons)
                      // El texto de la lección y su glosario se despliegan
                      // debajo de la tarjeta; tocar la lección sigue abriendo
                      // su contenido, como siempre.
                      LeccionDesplegable(
                        key: ValueKey('leccion-${lesson.id}'),
                        titulo: lesson.title,
                        desplegable: lesson.description.isNotEmpty ||
                            !glosario.isEmpty,
                        panel: (_) => GlosarioDeLeccion(
                          courseId: course.id,
                          leccion: lesson,
                          glosario: glosario,
                          puedeRepasar: puedeRepasar,
                        ),
                        builder: (desplegar) => _LessonTile(
                          lesson: lesson,
                          course: course,
                          done: progress.isLessonComplete(lesson.id),
                          available: progress.isLessonAvailable(lesson.id),
                          lockedBehind: tituloSiguiente,
                          // De quien tiene la sesión: en solo lectura, las
                          // entregas cargadas no son las de esa persona.
                          lastSubmission: readOnly ||
                                  lesson.type != LessonType.activity
                              ? null
                              : entregas
                                  .where((e) => e.lessonId == lesson.id)
                                  .firstOrNull,
                          readOnly: readOnly,
                          desplegar: desplegar,
                          // El propio: lo que el reproductor acaba de guardar,
                          // aunque la lectura del servidor todavía no lo traiga.
                          // El de otra persona: lo que dice su progreso.
                          video: lesson.type != LessonType.video
                              ? null
                              : readOnly
                                  ? progress.videoProgressFor(lesson.id)
                                  : data.myVideoProgress(lesson.id) ??
                                      progress.videoProgressFor(lesson.id),
                        ),
                      ),
                    if (glosario.forModule(module.id).isNotEmpty)
                      GlosarioDelModulo(
                        key: ValueKey('glosario-${module.id}'),
                        courseId: course.id,
                        modulo: module,
                        glosario: glosario,
                        puedeRepasar: puedeRepasar,
                      ),
                  ],
                  ),
                // El glosario acompaña al curso: si no carga, el curso se
                // sigue viendo entero y acá se ofrece reintentar.
                if (glosarioAsync.errorOrNull case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ErrorBanner(error,
                        onRetry: () => data.reloadGlossary(course.id)),
                  ),
                SectionTitle(tr.cursoMisEntregas),
                data.submissions.when(
                  loading: () => const CardListSkeleton(count: 2, height: 90),
                  error: (e) =>
                      ErrorState(e, onRetry: data.reloadSubmissions),
                  data: (all) => _SubmissionsSection(
                    course: course,
                    submissions: all
                        .where((s) => s.courseId == course.id)
                        .toList(),
                    readOnly: readOnly,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
              alignment: Alignment.bottomCenter, child: AppFooter()),
        ),
      ],
    );
  }

  // `Flexible`: un dato largo (el nombre del laboratorio, quién creó el
  // curso) se salía hasta 189 px a 360 dp.
  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Módulos plegables
// ---------------------------------------------------------------------------

/// Los módulos del curso, cada uno plegable.
///
/// Los que no están terminados van abiertos, en su orden. Los terminados se
/// juntan al final en «Módulos completados (N)», cerrado: lo hecho no
/// estorba para encontrar lo que sigue. Arriba, «Plegar todos» /
/// «Desplegar todos».
class _ModulosPlegables extends StatefulWidget {
  final List<CourseModule> modulos;
  final bool Function(CourseModule) completo;
  final int Function(CourseModule) hechas;
  final List<Widget> Function(CourseModule) contenido;

  /// Si el avance ya trae qué lecciones están hechas.
  final bool conDetalle;

  const _ModulosPlegables({
    required this.modulos,
    required this.completo,
    required this.hechas,
    required this.contenido,
    required this.conDetalle,
  });

  @override
  State<_ModulosPlegables> createState() => _ModulosPlegablesState();
}

class _ModulosPlegablesState extends State<_ModulosPlegables> {
  /// Los que la persona cerró (de los pendientes) o abrió (de los hechos).
  final _cerrados = <String>{};
  final _abiertos = <String>{};
  bool _verCompletados = false;

  /// Los que ya estaban terminados al abrir el curso. Solo esos se juntan
  /// abajo: uno que se termina mientras la persona está acá se queda donde
  /// estaba —que desaparezca de golpe al completar la última lección
  /// confunde—, y pasa al grupo la próxima vez que se abra el curso.
  ///
  /// Se fija la primera vez que el avance trae el detalle por lección: antes
  /// de eso (el resumen que llega con la lista de cursos) no se sabe qué
  /// terminó.
  Set<String>? _terminadosAlAbrir;

  bool _agrupado(CourseModule m) =>
      _terminadosAlAbrir?.contains(m.id) ?? widget.completo(m);

  bool _estaAbierto(CourseModule m) => _agrupado(m)
      ? _abiertos.contains(m.id)
      : !_cerrados.contains(m.id);

  void _todos(bool abrir) => setState(() {
        _cerrados.clear();
        _abiertos.clear();
        if (abrir) {
          _abiertos.addAll(widget.modulos.map((m) => m.id));
          _verCompletados = true;
        } else {
          _cerrados.addAll(widget.modulos.map((m) => m.id));
          _verCompletados = false;
        }
      });

  void _alternar(CourseModule m) => setState(() {
        final abierto = _estaAbierto(m);
        if (_agrupado(m)) {
          abierto ? _abiertos.remove(m.id) : _abiertos.add(m.id);
        } else {
          abierto ? _cerrados.add(m.id) : _cerrados.remove(m.id);
        }
      });

  @override
  Widget build(BuildContext context) {
    if (_terminadosAlAbrir == null && widget.conDetalle) {
      _terminadosAlAbrir = {
        for (final m in widget.modulos)
          if (widget.completo(m)) m.id
      };
    }
    final pendientes = [
      for (final m in widget.modulos)
        if (!_agrupado(m)) m
    ];
    final terminados = [
      for (final m in widget.modulos)
        if (_agrupado(m)) m
    ];
    final algunoAbierto = widget.modulos.any(_estaAbierto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('modulos-todos'),
            onPressed: () => _todos(!algunoAbierto),
            icon: Icon(
                algunoAbierto ? Icons.unfold_less : Icons.unfold_more,
                size: 18),
            label: Text(algunoAbierto
                ? tr.cursoPlegarTodos
                : tr.cursoDesplegarTodos),
          ),
        ),
        for (final m in pendientes) ..._modulo(m),
        if (terminados.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Cabecera(
            key: const ValueKey('modulos-completados'),
            titulo: tr.cursoModulosCompletados(terminados.length),
            icono: Icons.task_alt,
            abierto: _verCompletados,
            alTocar: () =>
                setState(() => _verCompletados = !_verCompletados),
            destacada: true,
          ),
          if (_verCompletados)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final m in terminados) ..._modulo(m)],
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _modulo(CourseModule m) {
    final abierto = _estaAbierto(m);
    return [
      const SizedBox(height: 10),
      _Cabecera(
        key: ValueKey('modulo-${m.id}'),
        titulo: m.title,
        detalle: tr.cursoModuloLecciones(widget.hechas(m), m.lessons.length),
        icono: widget.completo(m) ? Icons.check_circle : null,
        abierto: abierto,
        alTocar: () => _alternar(m),
      ),
      if (abierto) ...[
        const SizedBox(height: 8),
        ...widget.contenido(m),
      ],
    ];
  }
}

/// El encabezado de un módulo (o de «Módulos completados»): se toca para
/// abrirlo o cerrarlo.
class _Cabecera extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final IconData? icono;
  final bool abierto;
  final bool destacada;
  final VoidCallback alTocar;

  const _Cabecera({
    super.key,
    required this.titulo,
    required this.abierto,
    required this.alTocar,
    this.detalle,
    this.icono,
    this.destacada = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: abierto,
      child: Material(
        color: destacada ? AppColors.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: abierto ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                if (icono != null) ...[
                  Icon(icono, size: 20, color: AppColors.statusGood),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: displayHeading(
                        fontSize: destacada ? 18 : 22,
                        color: AppColors.textPrimary,
                        height: 1.05),
                  ),
                ),
                if (detalle != null)
                  Text(detalle!,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lección
// ---------------------------------------------------------------------------

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  final bool done;

  /// Si ya le toca: la completó (y la repasa) o es la siguiente.
  final bool available;

  /// La lección que hay que completar antes, para decirlo en el candado.
  final String? lockedBehind;

  /// La última entrega de esta actividad, si es una actividad.
  final Submission? lastSubmission;
  final bool readOnly;

  /// Hasta dónde vio el video; `null` si no es de video o nunca lo abrió.
  final VideoProgress? video;

  /// El botón que despliega el texto y el glosario de la lección, si tiene.
  final Widget? desplegar;

  const _LessonTile({
    required this.lesson,
    required this.course,
    required this.done,
    required this.available,
    required this.readOnly,
    this.lockedBehind,
    this.lastSubmission,
    this.video,
    this.desplegar,
  });

  bool get _locked => !done && !available;

  String get _lockedMessage {
    final anterior = lockedBehind;
    return anterior == null
        ? tr.leccionBloqueadaSinNombre
        : tr.leccionBloqueada(anterior);
  }

  /// "Video · 12 min · Visto 40%", o "· Seguir desde 3:12" si quedó a medias.
  String get _subtitle {
    final partes = [
      lesson.youtubeVideoId != null
          ? tr.leccionVideoYoutube
          : lessonTypeLabel(lesson.type),
      if (lesson.durationMin > 0) '${lesson.durationMin} min',
    ];
    final visto = video?.watchedRatio;
    final resume = video?.resumeAt;
    if (!done && resume != null) {
      partes.add(tr.videoSeguirDesde(formatVideoTime(resume)));
    } else if (visto != null && visto > 0) {
      partes.add(tr.videoVisto((visto * 100).round()));
    }
    // Una actividad entregada y sin aprobar es la razón de que lo siguiente
    // siga cerrado: se dice, para que nadie crea que es un error.
    final entrega = lastSubmission;
    if (!done && entrega != null) {
      partes.add(entrega.isGraded &&
              !GradingMode.isPassing(entrega.grade, entrega.gradingMode)
          ? tr.actividadNoAprobada
          : tr.actividadEnRevision);
    }
    return partes.join(' · ');
  }

  /// Cómo se completa esta lección: lo que dice el indicador mientras está
  /// pendiente. Ya no hay un círculo para marcar a mano.
  String get _howToComplete => switch (lesson.type) {
        LessonType.video => tr.leccionSeCompletaVideo,
        LessonType.pdf || LessonType.resource => tr.leccionSeCompletaLectura,
        LessonType.link => tr.leccionSeCompletaEnlace,
        LessonType.quiz => tr.leccionSeCompletaQuiz,
        LessonType.survey => tr.leccionSeCompletaEncuesta,
        LessonType.activity => tr.leccionSeCompletaActividad,
      };

  @override
  Widget build(BuildContext context) {
    final visto = video?.watchedRatio;
    final locked = _locked;
    final (icono, color, aviso) = done
        ? (Icons.check_circle, AppColors.statusGood, tr.leccionCompletada)
        : locked
            ? (Icons.lock_outline, AppColors.textMuted, _lockedMessage)
            : (Icons.radio_button_unchecked, AppColors.textMuted,
                _howToComplete);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: HoverCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // El candado es del estudiante: quien mira su curso desde el equipo
          // no avanza nada, y puede abrir el material para revisarlo.
          onTap: () => locked && !readOnly
              ? _abrirSiYaLeToca(context)
              : _open(context),
          child: Row(
            children: [
              Icon(lessonTypeIcon(lesson.type),
                  color: locked ? AppColors.textMuted : AppColors.gold,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(_subtitle,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    // Lo visto, como la barrita roja de YouTube bajo la
                    // miniatura: se entiende sin leer el porcentaje.
                    if (!done && visto != null && visto > 0 && visto < 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: visto,
                            minHeight: 3,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.gold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?desplegar,
              // Solo un indicador: completar no se hace tocándolo, sino
              // haciendo la lección (lo decide el servidor). El aviso del
              // Tooltip es también lo que lee un lector de pantalla.
              Tooltip(
                message: aviso,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icono, color: color, key: ValueKey(icono)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Si es el propio estudiante: solo así lo que hace en la lección cuenta
  /// como su avance.
  bool _sigue(BuildContext context) {
    final viewer = context.read<AuthProvider>().currentUser;
    return !readOnly && viewer != null && Roles.isStudentLike(viewer.role);
  }

  /// Completa una lectura, un enlace o un video sin seguimiento después de
  /// recorrerlo. Si con eso quedó una Ruta lista para certificar, se celebra.
  Future<void> _completar(BuildContext context) async {
    if (done || !_sigue(context)) return;
    final data = context.read<DataProvider>();
    try {
      final impact = await data.completeLesson(lesson.id, courseId: course.id);
      if (impact == null || !context.mounted) return;
      showSuccessCheck(
          context,
          impact.newlyCertifiable != null
              ? tr.rutaCompletada
              : tr.leccionCompletadaExclama);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  void _open(BuildContext context) {
    // Video, PDF, recurso y enlace no escriben nada: se abren igual en solo
    // lectura. Quiz, encuesta y actividad SÍ escriben a nombre de quien tiene
    // la sesión, así que atribuirían la respuesta a la persona equivocada.
    if (readOnly &&
        (lesson.type == LessonType.quiz ||
            lesson.type == LessonType.survey ||
            lesson.type == LessonType.activity)) {
      showAppSnack(context,
          tr.cursoNoPuedeResponder);
      return;
    }

    switch (lesson.type) {
      case LessonType.video:
        _openVideo(context);
      case LessonType.pdf:
      case LessonType.resource:
        _openResource(context);
      case LessonType.link:
        _openExternal(context, lesson.externalUrl);
      case LessonType.quiz:
        showDialog(
            context: context,
            builder: (_) => _QuizDialog(lesson: lesson, course: course));
      case LessonType.survey:
        showDialog(
            context: context,
            builder: (_) => _SurveyDialog(lesson: lesson, course: course));
      case LessonType.activity:
        showDialog(
            context: context,
            builder: (_) => _ActivityDialog(lesson: lesson, course: course));
    }
  }

  /// Una lección con candado pudo completarse en otro dispositivo hace un
  /// momento —la anterior, vista en el computador—: antes de decir que falta
  /// algo se le pregunta al servidor, y si ya le toca, se abre.
  Future<void> _abrirSiYaLeToca(BuildContext context) async {
    final data = context.read<DataProvider>();
    await data.avanceDelCursoAlDia(course.id);
    if (!context.mounted) return;
    final progreso = data.courseProgress(course.id).valueOrNull;
    if (progreso != null &&
        (progreso.isLessonComplete(lesson.id) ||
            progreso.nextLessonId == lesson.id)) {
      _open(context);
      return;
    }
    final siguiente = progreso?.nextLessonId;
    final falta = siguiente == null
        ? null
        : course.modules
            .expand((m) => m.lessons)
            .where((l) => l.id == siguiente)
            .firstOrNull
            ?.title;
    showAppSnack(
        context,
        falta == null
            ? tr.leccionBloqueadaSinNombre
            : tr.leccionBloqueada(falta));
  }

  /// El video de YouTube o subido se completa en el servidor con lo que se
  /// ve (el 90%, sin adelantar). Uno de Vimeo, o una lección sin video, no
  /// informa qué se vio: se completa al verlo y cerrarlo.
  Future<void> _openVideo(BuildContext context) async {
    // El avance se guarda solo para el propio estudiante: el equipo puede
    // abrir el curso de alguien, pero mirar el video no es avance suyo.
    final sigue = _sigue(context);
    // Retoma donde quedó, aunque haya sido en otro dispositivo: si lo que
    // hay ya venció, se pregunta antes de abrir (sin esperar más de un par
    // de segundos, para no dejar a nadie mirando una pantalla quieta).
    if (sigue) {
      await context
          .read<DataProvider>()
          .avanceDelCursoAlDia(course.id, soloSiViejo: true)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!context.mounted) return;
    }
    await VideoPlayerDialog.show(
      context,
      lesson,
      courseId: course.id,
      trackProgress: sigue,
    );
    final conSeguimiento =
        lesson.youtubeVideoId != null || lesson.isUploadedVideo;
    if (sigue && !conSeguimiento && context.mounted) await _completar(context);
  }

  /// Abre el PDF o recurso pidiendo su URL firmada. La lección se completa
  /// al recorrerlo: un PDF, al llegar a la última página.
  ///
  /// La firma la emite el servidor tras comprobar que esta persona puede leer
  /// esa key: un archivo de un curso ajeno responde 404 y acá se dice, en vez
  /// de abrir una pestaña en blanco.
  Future<void> _openResource(BuildContext context) async {
    final key = lesson.resourceS3Key;
    if (key == null || key.isEmpty) {
      showAppSnack(context, tr.leccionSinMaterial);
      // Sin material no hay nada que recorrer: la lección no puede dejar el
      // curso trabado por un error de quien lo armó.
      await _completar(context);
      return;
    }
    final data = context.read<DataProvider>();
    try {
      final url = await data.resolveFileUrl(key);
      if (!context.mounted) return;
      await FileViewer.show(context,
          url: url,
          fileName: lesson.resourceFileName,
          s3Key: key,
          onReadToEnd: done || !_sigue(context)
              ? null
              : () => unawaited(_completar(context)));
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  /// Un enlace se completa al abrirlo: lo que hay del otro lado no se ve.
  Future<void> _openExternal(BuildContext context, String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      showAppSnack(context, tr.leccionSinEnlace);
      await _completar(context);
      return;
    }
    // En la app: PDF en el visor propio y el resto en el navegador
    // integrado, sin salir de la lección (ver `abrirRecurso`).
    final ok = await abrirRecurso(context, uri.toString(), titulo: lesson.title);
    if (!context.mounted) return;
    if (!ok) {
      showAppSnack(context, tr.leccionEnlaceNoAbre);
      return;
    }
    await _completar(context);
  }
}

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

/// Quiz con los cinco tipos de pregunta.
///
/// **La corrección la hace el servidor.** La clave de respuestas ya no viaja
/// al navegador —antes venía dentro del curso y cualquiera podía leerla desde
/// las herramientas de desarrollo— así que acá no hay nada que comparar: se
/// mandan las respuestas y vuelve el puntaje con qué preguntas estuvieron
/// bien.
class _QuizDialog extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  const _QuizDialog({required this.lesson, required this.course});

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  /// Respuesta por id de pregunta: índice para `multiple`/`truefalse`, texto
  /// para `short`/`fill`.
  final Map<String, Object> _answers = {};

  /// Orden actual de las opciones en las preguntas de tipo `order`.
  final Map<String, List<String>> _order = {};

  QuizResult? _result;
  bool _sending = false;
  ApiException? _error;

  bool _isAnswered(QuizQuestion question) => switch (question.kind) {
        'multiple' || 'truefalse' => _answers.containsKey(question.id),
        'short' || 'fill' =>
          ((_answers[question.id] as String?) ?? '').trim().isNotEmpty,
        'order' => true,
        _ => false,
      };

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // Aprobar completa la lección en el servidor —la nota es suya, y el
      // completar también—; el provider aplica lo que cambió.
      final result = await context
          .read<DataProvider>()
          .submitQuiz(widget.lesson.id, _answers);
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.lesson.quiz;
    final allAnswered = quiz.every(_isAnswered);
    final result = _result;

    // Pantalla completa en el teléfono y confirmación antes de descartar
    // respuestas sin calificar: antes tocar fuera del recuadro, o "atrás",
    // las borraba sin preguntar.
    return AdaptiveFormShell(
      title: widget.lesson.title,
      maxWidth: 540,
      saving: _sending,
      dirty: _answers.isNotEmpty && result == null,
      onCancel: () => Navigator.pop(context),
      cancelLabel: tr.comunCerrar,
      saveLabel: tr.quizCalificar,
      savingLabel: tr.quizCalificando,
      onSave: allAnswered && quiz.isNotEmpty && result == null ? _submit : null,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quiz.isEmpty)
                Text(tr.quizSinPreguntas,
                    style: TextStyle(color: AppColors.textMuted)),
              for (var i = 0; i < quiz.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('${i + 1}. ${quiz[i].question}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    // Tras corregir se marca cada pregunta, pero nunca se
                    // muestra cuál era la respuesta correcta.
                    if (result != null)
                      Icon(
                          result.isCorrect(quiz[i].id)
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 18,
                          color: result.isCorrect(quiz[i].id)
                              ? AppColors.statusGood
                              : AppColors.statusCritical),
                  ],
                ),
                const SizedBox(height: 4),
                ..._questionWidget(quiz[i]),
                const SizedBox(height: 12),
              ],
              if (result != null)
                StatusChip(
                  label: result.passed
                      ? tr.quizAprobado(result.score)
                      : tr.quizPuntaje(result.score),
                  color: result.passed
                      ? AppColors.statusGood
                      : AppColors.statusCritical,
                  icon: result.passed ? Icons.check : Icons.close,
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(_error!),
              ],
            ],
          ),
    );
  }

  List<Widget> _questionWidget(QuizQuestion question) {
    // Tras corregir, las respuestas quedan fijas: cambiarlas no volvería a
    // calificar y daría a entender que sí.
    final locked = _result != null || _sending;

    switch (question.kind) {
      case 'multiple':
        return [
          for (var o = 0; o < question.options.length; o++)
            RadioListTile<int>(
              dense: true,
              title: Text(question.options[o],
                  style: const TextStyle(fontSize: 13)),
              value: o,
              // ignore: deprecated_member_use
              groupValue: _answers[question.id] as int?,
              activeColor: AppColors.gold,
              // ignore: deprecated_member_use
              onChanged: locked
                  ? null
                  : (v) => setState(() => _answers[question.id] = v!),
            ),
        ];
      case 'truefalse':
        return [
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label) in [(0, tr.quizVerdadero), (1, tr.quizFalso)])
                ChoiceChip(
                  label: Text(label),
                  selected: _answers[question.id] == value,
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected: locked
                      ? null
                      : (_) => setState(() => _answers[question.id] = value),
                ),
            ],
          ),
        ];
      case 'short':
      case 'fill':
        return [
          TextField(
            enabled: !locked,
            decoration: InputDecoration(
              hintText: question.kind == 'fill'
                  ? tr.quizCompleteFrase
                  : tr.quizSuRespuesta,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _answers[question.id] = v),
          ),
        ];
      case 'order':
        final current =
            _order.putIfAbsent(question.id, () => [...question.options]..shuffle());
        return [
          Text(tr.quizUseFlechas,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          for (var o = 0; o < current.length; o++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${o + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(current[o],
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 15),
                    onPressed: o == 0 || locked
                        ? null
                        : () => setState(() => _swap(question.id, o, o - 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 15),
                    onPressed: o == current.length - 1 || locked
                        ? null
                        : () => setState(() => _swap(question.id, o, o + 1)),
                  ),
                ],
              ),
            ),
        ];
      default:
        return const [];
    }
  }

  void _swap(String questionId, int a, int b) {
    final list = _order[questionId]!;
    final tmp = list[a];
    list[a] = list[b];
    list[b] = tmp;
    _answers[questionId] = list.join('|');
  }
}

// ---------------------------------------------------------------------------
// Encuesta: elegir una opción, calificar de 1 a 5 y comentar. No se califica.
// ---------------------------------------------------------------------------

class _SurveyDialog extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  const _SurveyDialog({required this.lesson, required this.course});

  @override
  State<_SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<_SurveyDialog> {
  /// `{ preguntaId: índice de la opción | 1..5 | comentario }`.
  final Map<String, Object> _answers = {};
  bool _loading = true;
  bool _yaRespondio = false;
  bool _cambio = false;
  bool _sending = false;
  ApiException? _error;

  /// Rearma los campos de comentario cuando llega lo que ya había escrito.
  int _generacion = 0;

  List<QuizQuestion> get _preguntas => widget.lesson.quiz;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Si ya la respondió, la encuesta se abre con sus respuestas: puede
  /// cambiarlas y enviarla de nuevo, sin empezar de cero.
  Future<void> _cargar() async {
    try {
      final previas =
          await context.read<DataProvider>().mySurveyResponse(widget.lesson.id);
      if (!mounted) return;
      setState(() {
        if (previas != null) {
          _answers.addAll(previas);
          _yaRespondio = true;
          _generacion++;
        }
        _loading = false;
      });
    } on ApiException {
      // Sin lo anterior igual se puede responder.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _responder(String preguntaId, Object valor) => setState(() {
        _answers[preguntaId] = valor;
        _cambio = true;
      });

  /// Elegir y calificar son obligatorias; el comentario, no.
  bool _respondida(QuizQuestion q) => switch (q.kind) {
        'multiple' => switch (_answers[q.id]) {
            final int i => i >= 0 && i < q.options.length,
            _ => false,
          },
        'scale' => _answers[q.id] is int,
        _ => true,
      };

  bool _esComentario(QuizQuestion q) => q.kind != 'multiple' && q.kind != 'scale';

  /// Por qué todavía no se puede enviar, o `null` si ya se puede.
  String? get _falta {
    if (_preguntas.isEmpty) return tr.encuestaSinPreguntas;
    if (!_preguntas.every(_respondida)) return tr.encuestaFaltanRespuestas;
    // Una encuesta de solo comentarios, enviada en blanco, no dice nada.
    if (_preguntas.every(_esComentario) &&
        !_answers.values.any((v) => v is String && v.trim().isNotEmpty)) {
      return tr.encuestaEscribaComentario;
    }
    return null;
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().answerSurvey(
        widget.lesson.id,
        widget.course.id,
        {
          for (final q in _preguntas)
            if (_answers[q.id] case final valor?)
              if (valor is! String || valor.trim().isNotEmpty) q.id: valor,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, tr.encuestaGracias);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final falta = _falta;
    return AdaptiveFormShell(
      title: widget.lesson.title,
      maxWidth: 520,
      saving: _sending,
      dirty: _cambio,
      onCancel: () => Navigator.pop(context),
      saveLabel: tr.comunEnviar,
      savingLabel: tr.comunEnviando,
      onSave: _loading || falta != null ? null : _send,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: BrandLoader()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.encuestaOpinion,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
                if (_yaRespondio) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppColors.statusGood),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(tr.encuestaYaRespondio,
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                for (var i = 0; i < _preguntas.length; i++) ...[
                  Text('${i + 1}. ${_preguntas[i].question}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _pregunta(_preguntas[i]),
                  const SizedBox(height: 16),
                ],
                if (falta != null)
                  Text(falta,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(_error!),
                ],
              ],
            ),
    );
  }

  Widget _pregunta(QuizQuestion q) {
    switch (q.kind) {
      case 'multiple':
        return Column(
          children: [
            for (var o = 0; o < q.options.length; o++)
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(q.options[o], style: const TextStyle(fontSize: 13)),
                value: o,
                // ignore: deprecated_member_use
                groupValue: _answers[q.id] as int?,
                activeColor: AppColors.gold,
                // ignore: deprecated_member_use
                onChanged: _sending ? null : (v) => _responder(q.id, v!),
              ),
          ],
        );
      case 'scale':
        final elegida = _answers[q.id];
        final extremo1 = q.options.isNotEmpty ? q.options[0].trim() : '';
        final extremo5 = q.options.length > 1 ? q.options[1].trim() : '';
        final etiqueta =
            TextStyle(fontSize: 11.5, color: AppColors.textMuted);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = 1; n <= 5; n++)
                  Semantics(
                    button: true,
                    selected: elegida == n,
                    label: tr.encuestaCalificacion(n),
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('calificar-${q.id}-$n'),
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : () => _responder(q.id, n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: elegida == n
                              ? AppColors.relleno
                              : AppColors.surfaceAlt,
                          border: Border.all(
                              color: elegida == n
                                  ? AppColors.relleno
                                  : AppColors.border),
                        ),
                        child: Text('$n',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: elegida == n
                                    ? AppColors.ink
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ),
              ],
            ),
            if (extremo1.isNotEmpty || extremo5.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  // Las etiquetas quedan bajo el 1 y bajo el 5.
                  width: 5 * 44 + 4 * 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            extremo1.isEmpty ? '' : '1 = $extremo1',
                            style: etiqueta),
                      ),
                      Expanded(
                        child: Text(
                            extremo5.isEmpty ? '' : '5 = $extremo5',
                            textAlign: TextAlign.end,
                            style: etiqueta),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      default:
        return TextFormField(
          key: ValueKey(('comentario', q.id, _generacion)),
          initialValue: _answers[q.id] is String ? _answers[q.id] as String : '',
          enabled: !_sending,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
              hintText: tr.encuestaComentarioOpcional, isDense: true),
          onChanged: (v) => _responder(q.id, v),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Actividad
// ---------------------------------------------------------------------------

class _ActivityDialog extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  const _ActivityDialog({required this.lesson, required this.course});

  @override
  Widget build(BuildContext context) {
    final activity = lesson.activity ?? const ActivityConfig();
    final data = context.watch<DataProvider>();
    final mine = (data.submissions.valueOrNull ?? const <Submission>[])
        .where((s) => s.lessonId == lesson.id)
        .toList();

    final deadline =
        activity.deadline == null ? null : DateTime.tryParse(activity.deadline!);
    final overdue = deadline != null && DateTime.now().isAfter(deadline);

    // «Subir entrega» al frente del título: es lo que se viene a hacer acá,
    // no tiene que esperar al pie del diálogo.
    final subir = ElevatedButton.icon(
      key: const ValueKey('subir-entrega'),
      icon: const Icon(Icons.upload_file, size: 16),
      label: Text(mine.isEmpty ? tr.actividadEntregar : tr.actividadNuevaEntrega),
      onPressed: () {
        Navigator.pop(context);
        showSubmitActivityDialog(context, course, lesson, activity);
      },
    );
    return AlertDialog(
      title: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(lesson.title, style: const TextStyle(fontSize: 18)),
          subir,
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          // Lugar para la etiqueta flotante del primer campo: sin él,
          // el desplazamiento la recortaba («Rol» salía cortado).
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activity.description.isNotEmpty) ...[
                Text(activity.description,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
              ],
              Text(tr.actividadSeCompletaAprobada,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (deadline != null)
                    StatusChip(
                      label:
                          tr.actividadLimite(fechaCorta(deadline)),
                      color: overdue
                          ? AppColors.statusCritical
                          : AppColors.statusWarning,
                      icon: Icons.schedule,
                    ),
                  if (activity.requiresFile)
                    StatusChip(
                        label: tr.actividadArchivoObligatorio,
                        color: AppColors.slateLight,
                        icon: Icons.attach_file),
                  if (activity.requiresText)
                    StatusChip(
                        label: tr.actividadTextoObligatorio,
                        color: AppColors.slateLight,
                        icon: Icons.notes),
                  StatusChip(
                    label: GradingMode.label(activity.gradingMode),
                    color: AppColors.gold,
                    icon: Icons.grade_outlined,
                  ),
                ],
              ),
              if (activity.rubric.isNotEmpty) ...[
                SectionTitle(tr.actividadRubrica),
                for (final item in activity.rubric)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.rule, size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item.criterion,
                                style: const TextStyle(fontSize: 13))),
                        Text('${item.points} pts',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
              if (mine.isNotEmpty) ...[
                SectionTitle(tr.actividadSuEntrega),
                for (final submission in mine)
                  HoverCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  fechaHora(submission.submittedAt),
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ),
                            StatusChip(
                              label: submission.gradeLabel,
                              color: submission.isGraded
                                  ? (GradingMode.isPassing(submission.grade,
                                          submission.gradingMode)
                                      ? AppColors.statusGood
                                      : AppColors.statusCritical)
                                  : AppColors.statusWarning,
                              icon: submission.isGraded
                                  ? Icons.grade
                                  : Icons.hourglass_empty,
                            ),
                          ],
                        ),
                        if (submission.feedback.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                tr.actividadRetroalimentacion(submission.feedback),
                                style: TextStyle(
                                    color: AppColors.gold, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr.comunCerrar)),
      ],
    );
  }
}

/// Entregar una actividad, con las validaciones de su configuración.
Future<void> showSubmitActivityDialog(BuildContext context, Course course,
    Lesson lesson, ActivityConfig config) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _SubmitDialog(course: course, lesson: lesson, config: config),
  );
}

class _SubmitDialog extends StatefulWidget {
  final Course course;
  final Lesson lesson;
  final ActivityConfig config;
  const _SubmitDialog(
      {required this.course, required this.lesson, required this.config});

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  final _comment = TextEditingController();
  final List<UploadedFile> _files = [];
  bool _sending = false;
  ApiException? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.config.requiresText && _comment.text.trim().isEmpty) {
      setState(() => _error = ValidationError(
          tr.actividadRequiereTexto));
      return;
    }
    if (widget.config.requiresFile && _files.isEmpty) {
      setState(() => _error = ValidationError(
          tr.actividadRequiereArchivo));
      return;
    }
    // Una entrega vacía no es una entrega (y el servidor la rechaza).
    if (_comment.text.trim().isEmpty && _files.isEmpty) {
      setState(() => _error = ValidationError(tr.entregaVaciaRuta));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      final entrega = await data.createSubmission(
        courseId: widget.course.id,
        lessonId: widget.lesson.id,
        taskName: widget.lesson.title,
        comment: _comment.text.trim(),
        files: _files.map((f) => f.toJson()).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      _avisarEntrega(context, tr.actividadEntregada, entrega.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: tr.actividadEntregarTitulo(widget.lesson.title),
      maxWidth: 460,
      saving: _sending,
      // Lo escrito y los archivos ya subidos no se pierden por un toque.
      dirty: _comment.text.trim().isNotEmpty || _files.isNotEmpty,
      onCancel: () => Navigator.pop(context),
      saveLabel: tr.comunEnviar,
      savingLabel: tr.comunEnviando,
      onSave: _send,
      child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _comment,
                enabled: !_sending,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: widget.config.requiresText
                      ? tr.actividadRespuestaObligatoria
                      : tr.actividadComentarioOpcional,
                ),
              ),
              const SizedBox(height: 12),
              FileUploadField(
                purpose: 'submission',
                maxFiles: widget.config.maxFiles,
                files: _files,
                enabled: !_sending,
                onChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(_error!),
              ],
            ],
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entregas del curso
// ---------------------------------------------------------------------------

/// La tarjeta de cada entrega en «Mis entregas», para que «Ver entrega» la
/// lleve a la vista.
final Map<String, GlobalKey> _tarjetasDeEntrega = {};

GlobalKey _tarjetaDeEntrega(String id) =>
    _tarjetasDeEntrega.putIfAbsent(id, GlobalKey.new);

/// «Actividad entregada», con «Ver entrega»: baja hasta su tarjeta en «Mis
/// entregas», en esta misma pantalla.
void _avisarEntrega(BuildContext context, String titulo, String entregaId) {
  showSuccessCheck(
    context,
    titulo,
    detalle: tr.entregaRecibidaDetalle,
    accion: tr.actividadVerEntrega,
    alAccion: () {
      final tarjeta = _tarjetaDeEntrega(entregaId).currentContext;
      if (tarjeta != null && tarjeta.mounted) {
        Scrollable.ensureVisible(tarjeta,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.2);
      }
    },
  );
}

class _SubmissionsSection extends StatelessWidget {
  final Course course;
  final List<Submission> submissions;
  final bool readOnly;
  const _SubmissionsSection({
    required this.course,
    required this.submissions,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (submissions.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(tr.actividadSinEntregas,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        for (final submission in submissions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SubmissionCard(
                key: _tarjetaDeEntrega(submission.id),
                submission: submission,
                // La propia, mientras nadie la haya calificado ni comentado:
                // se le pueden quitar archivos o borrarla.
                editable: !readOnly &&
                    !submission.isGraded &&
                    submission.feedback.isEmpty),
          ),
        if (!readOnly) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(tr.actividadEntregaLibre),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _FreeSubmissionDialog(course: course),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  final bool editable;
  const _SubmissionCard(
      {super.key, required this.submission, this.editable = false});

  Future<void> _quitarArchivo(BuildContext context, SubmissionFile file) async {
    final data = context.read<DataProvider>();
    final ok = await confirmDialog(context,
        tr.entregaQuitarArchivoPregunta(file.fileName), tr.entregaQuitarArchivoTexto);
    if (!ok || !context.mounted) return;
    try {
      await data.deleteSubmissionFile(submission.id, file.id);
      if (context.mounted) showSuccessCheck(context, tr.entregaArchivoQuitado);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _borrar(BuildContext context) async {
    final data = context.read<DataProvider>();
    final ok = await confirmDialog(
        context, tr.entregaBorrarPregunta, tr.entregaBorrarTexto);
    if (!ok || !context.mounted) return;
    try {
      await data.deleteSubmission(submission.id);
      if (context.mounted) showSuccessCheck(context, tr.entregaBorrada);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(submission.taskName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              // La nota se muestra en SU escala: 100 no significa lo mismo en
              // `passfail` que en `points100`.
              StatusChip(
                label: submission.gradeLabel,
                color: submission.isGraded
                    ? (GradingMode.isPassing(
                            submission.grade, submission.gradingMode)
                        ? AppColors.statusGood
                        : AppColors.statusCritical)
                    : AppColors.statusWarning,
                icon: submission.isGraded
                    ? Icons.grade
                    : Icons.hourglass_empty,
              ),
            ],
          ),
          if (submission.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(submission.comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          for (final file in submission.files)
            SubmissionAttachmentRow(
              file: file,
              alQuitar: editable ? () => _quitarArchivo(context, file) : null,
            ),
          if (submission.feedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tr.actividadRetroalimentacion(submission.feedback),
                style: TextStyle(color: AppColors.gold, fontSize: 13)),
          ],
          Row(
            children: [
              Expanded(
                child: Text(fechaCorta(submission.submittedAt),
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
              if (editable)
                TextButton.icon(
                  key: ValueKey('borrar-entrega-${submission.id}'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.statusCritical),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(tr.entregaBorrar),
                  onPressed: () => _borrar(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FreeSubmissionDialog extends StatefulWidget {
  final Course course;
  const _FreeSubmissionDialog({required this.course});

  @override
  State<_FreeSubmissionDialog> createState() => _FreeSubmissionDialogState();
}

class _FreeSubmissionDialogState extends State<_FreeSubmissionDialog> {
  final _task = TextEditingController();
  final _comment = TextEditingController();
  final List<UploadedFile> _files = [];
  bool _sending = false;
  ApiException? _error;

  @override
  void dispose() {
    _task.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_task.text.trim().isEmpty) {
      setState(() => _error =
          ValidationError(tr.actividadPongaNombre));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final entrega = await context.read<DataProvider>().createSubmission(
            courseId: widget.course.id,
            taskName: _task.text.trim(),
            comment: _comment.text.trim(),
            files: _files.map((f) => f.toJson()).toList(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      _avisarEntrega(context, tr.actividadEntregaEnviada, entrega.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: tr.actividadNuevaEntrega,
      maxWidth: 440,
      saving: _sending,
      dirty: _task.text.trim().isNotEmpty ||
          _comment.text.trim().isNotEmpty ||
          _files.isNotEmpty,
      onCancel: () => Navigator.pop(context),
      saveLabel: tr.comunEnviar,
      savingLabel: tr.comunEnviando,
      onSave: _send,
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _task,
                  enabled: !_sending,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: obligatorio(tr.actividadNombreTarea),
                          prefixIcon: const Icon(Icons.assignment_outlined, size: 20))),
              const SizedBox(height: 12),
              TextField(
                  controller: _comment,
                  enabled: !_sending,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      InputDecoration(labelText: tr.comunComentario,
                          prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20))),
              const SizedBox(height: 12),
              FileUploadField(
                purpose: 'submission',
                maxFiles: 3,
                files: _files,
                enabled: !_sending,
                onChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(_error!),
              ],
            ],
          ),
    );
  }
}
