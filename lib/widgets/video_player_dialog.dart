import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../services/video_source_io.dart'
    if (dart.library.js_interop) '../services/video_source_web.dart';
import '../utils/app_theme.dart';
import '../utils/orientacion.dart';
import '../utils/responsive.dart';
import '../utils/youtube.dart';
import 'uploaded_lesson_player.dart';
import 'youtube_lesson_player.dart';

/// Reproductor de video de una lección.
///
/// El video tiene tres orígenes y **no se tratan igual**:
///
/// - **`youtube`** — se guardó solo el id. Se reproduce con
///   [YoutubeLessonPlayer]: miniatura primero, reproductor al tocar, y el
///   avance de quien mira se guarda para retomar donde quedó. Las lecciones
///   viejas que guardaron el ENLACE de YouTube como `external` van por acá
///   también ([Lesson.youtubeVideoId] saca el id del enlace).
///
/// - **`external`** — un enlace de Vimeo. En el navegador se embebe en un
///   `<iframe>`; fuera del navegador no hay iframe, así que se abre en la
///   aplicación del sistema. La conversión a URL de *embed* la hace
///   [embedUrlFor]: el enlace que la gente pega NO se deja embeber —responde
///   `X-Frame-Options`— y embeberlo daría un recuadro en blanco sin ningún
///   error visible.
///
/// - **`uploaded`** — un archivo propio. Se reproduce con
///   [UploadedLessonPlayer]: la misma carátula, el mismo 16:9 y el mismo
///   avance guardado que YouTube, con controles propios. El video sale de
///   `GET /lessons/:id/video-url`, una URL firmada de CloudFront con cinco
///   minutos de vigencia. **Nunca por URL firmada de S3**: es una decisión de
///   costo y la API rechaza esas keys con 400.
///
/// Los tres estados son obligatorios, como en el resto de la app: mientras se
/// pide la URL hay un indicador; si falla, el error con botón de reintentar; y
/// si la lección no tiene video, el estado vacío. Una pantalla de video que se
/// queda cargando para siempre es indistinguible de una rota.
///
/// **Tamaño.** En un teléfono el diálogo ocupa la pantalla entera y el video
/// va de borde a borde. En pantallas grandes el video es el 16:9 más grande
/// que entra en la ventana — limitado por el ANCHO y también por el ALTO: en
/// una laptop apaisada el límite es el alto, y un diálogo que solo mirara el
/// ancho dejaría los controles del reproductor fuera de la pantalla.
class VideoPlayerDialog extends StatelessWidget {
  final Lesson lesson;

  /// El curso de la lección, para completarla cuando se terminó de ver.
  /// `null` en una lectura propia de un módulo de la Ruta.
  final String? courseId;

  /// Si se guarda el avance de quien mira. Solo para el propio estudiante: el
  /// equipo mirando el curso de otra persona no escribe avance a su nombre, y
  /// el servidor tampoco se lo permitiría.
  final bool trackProgress;

  const VideoPlayerDialog({
    super.key,
    required this.lesson,
    this.courseId,
    this.trackProgress = false,
  });

  /// En la app, mientras el video está abierto el teléfono puede girarse a
  /// horizontal —el resto de la app es vertical en teléfonos, ver
  /// `utils/orientacion.dart`— y la pantalla no se apaga. Al cerrarlo, todo
  /// vuelve a como estaba.
  static Future<void> show(
    BuildContext context,
    Lesson lesson, {
    String? courseId,
    bool trackProgress = false,
  }) async {
    // Sin esperar ninguna de las dos: el video no depende de que el sistema
    // conteste, y si un complemento no responde, igual tiene que abrirse.
    if (!kIsWeb) {
      unawaited(permitirCualquierOrientacion());
      unawaited(_pantallaEncendida(true));
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => VideoPlayerDialog(
          lesson: lesson,
          courseId: courseId,
          trackProgress: trackProgress,
        ),
      );
    } finally {
      if (!kIsWeb) {
        unawaited(_pantallaEncendida(false));
        unawaited(fijarOrientacionDeLaApp());
      }
    }
  }

  /// Sin el complemento (pruebas, escritorio sin soporte) simplemente no hace
  /// nada: no vale la pena impedir que se vea el video por esto.
  static Future<void> _pantallaEncendida(bool encendida) async {
    try {
      await WakelockPlus.toggle(enable: encendida);
    } catch (_) {}
  }

  /// Ancho máximo del video en pantallas grandes. Más allá de esto el
  /// diálogo deja de parecer un diálogo y la miniatura de YouTube (480 px)
  /// se ve borrosa.
  static const maxVideoWidth = 960.0;

  /// Lo que ocupan el encabezado, el pie y los márgenes del diálogo: es lo que
  /// se le descuenta al alto de la ventana antes de calcular el 16:9.
  static const _chromeHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final header = _Header(title: lesson.title);
    final footer = _Footer(lesson: lesson, courseId: courseId,
        trackProgress: trackProgress);

    final size = MediaQuery.sizeOf(context);

    // Un teléfono acostado también es "compacto" aunque mida más de 600 px
    // de ancho: lo que manda ahí es el alto.
    if (context.isCompact || size.height < 500) {
      // Acostado, el video se limita por el alto para entrar entero.
      final ancho = math.min(size.width, (size.height - 64) * 16 / 9);
      return Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: header,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        width: ancho,
                        child: _body(context, edgeToEdge: ancho >= size.width),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: footer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    const inset = 24.0;
    final porAlto = (size.height - inset * 2 - _chromeHeight) * 16 / 9;
    final ancho = math.max(
      320.0,
      math.min(maxVideoWidth, math.min(size.width - inset * 2 - 40, porAlto)),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(inset),
      child: SizedBox(
        width: ancho + 40,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              _body(context, edgeToEdge: false),
              const SizedBox(height: 12),
              footer,
            ],
          ),
        ),
      ),
    );
  }

  /// [edgeToEdge]: el video toca los bordes de la pantalla, así que va sin
  /// esquinas redondeadas.
  Widget _body(BuildContext context, {required bool edgeToEdge}) {
    final youtubeId = lesson.youtubeVideoId;
    if (youtubeId != null) {
      return _YoutubeBody(
        lesson: lesson,
        videoId: youtubeId,
        courseId: courseId,
        trackProgress: trackProgress,
        borderRadius: edgeToEdge ? 0 : 12,
      );
    }

    final url = lesson.videoUrl;
    if (lesson.isExternalVideo && url != null && url.isNotEmpty) {
      final embed = embedUrlFor(url);
      if (puedeEmbeber && embed != null) {
        return AspectRatio(
            aspectRatio: 16 / 9, child: buildEmbeddedVideo(embed));
      }
      // Un enlace que no es YouTube ni Vimeo —o una plataforma sin iframe—
      // se abre afuera. No se intenta embeber a ciegas: la mayoría de los
      // sitios lo bloquean y el recuadro queda en blanco sin decir por qué.
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _Panel(
          icon: Icons.open_in_new,
          title: tr.videoVer,
          message: tr.videoPestanaNueva,
          action: (tr.videoAbrir, () => _open(context, url)),
        ),
      );
    }

    if (lesson.isUploadedVideo) {
      return _UploadedBody(
        lesson: lesson,
        courseId: courseId,
        trackProgress: trackProgress,
        borderRadius: edgeToEdge ? 0 : 12,
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _Panel(
        icon: Icons.videocam_off_outlined,
        title: tr.videoLeccionSinVideo,
        message: tr.videoCreadorNoCargo,
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.videoEnlaceNoAbre)),
      );
    }
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.play_circle_outline, color: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: tr.comunCerrar,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// El video de YouTube con el avance de quien mira: desde dónde retomar, y
/// qué hacer cuando lo termina.
class _YoutubeBody extends StatelessWidget {
  final Lesson lesson;
  final String videoId;
  final String? courseId;
  final bool trackProgress;
  final double borderRadius;

  const _YoutubeBody({
    required this.lesson,
    required this.videoId,
    required this.courseId,
    required this.trackProgress,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // `watch`: el avance que llega del servidor (o del guardado anterior)
    // puede llegar después de abrir el diálogo, y la carátula lo muestra.
    //
    // El provider se toma ACÁ y los callbacks usan esta referencia, no el
    // `context`: el último guardado sale del `dispose` del reproductor, con
    // este elemento ya desmontándose, y buscar un ancestro ahí lanza.
    final data = trackProgress ? context.watch<DataProvider>() : null;
    final saved = data?.myVideoProgress(lesson.id);

    return YoutubeLessonPlayer(
      videoId: videoId,
      title: lesson.title,
      resumeAt: saved?.resumeAt,
      watchedRatio: saved?.watchedRatio,
      borderRadius: borderRadius,
      onProgress: data == null
          ? null
          : (position, duration) => data.saveVideoProgress(lesson.id,
              positionSec: position, durationSec: duration),
      onWatched: data == null ? null : () => _complete(data),
    );
  }

  Future<void> _complete(DataProvider data) =>
      _completeLesson(data, lesson.id, courseId);
}

/// Ver el video es completarlo, igual que aprobar un quiz completa el suyo.
/// `IfPending`: si ya estaba completa no se toca — un toggle la desmarcaría.
Future<void> _completeLesson(
    DataProvider data, String lessonId, String? courseId) async {
  try {
    if (courseId != null) {
      await data.toggleLessonIfPending(lessonId, courseId);
    } else {
      await data.toggleRutaLessonIfPending(lessonId);
    }
  } on ApiException catch (e) {
    // El video sigue: quien mira puede marcarla a mano desde la lista.
    debugPrint('No se pudo completar $lessonId: ${e.message}');
  }
}

/// El video subido, con el mismo avance que el de YouTube.
class _UploadedBody extends StatelessWidget {
  final Lesson lesson;
  final String? courseId;
  final bool trackProgress;
  final double borderRadius;

  const _UploadedBody({
    required this.lesson,
    required this.courseId,
    required this.trackProgress,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final data = trackProgress ? context.watch<DataProvider>() : null;
    final saved = data?.myVideoProgress(lesson.id);
    final seconds = lesson.videoDurationSec;

    return UploadedLessonPlayer(
      lessonId: lesson.id,
      title: lesson.title,
      durationHint: seconds == null ? null : Duration(seconds: seconds),
      resumeAt: saved?.resumeAt,
      watchedRatio: saved?.watchedRatio,
      borderRadius: borderRadius,
      onProgress: data == null
          ? null
          : (position, duration) => data.saveVideoProgress(lesson.id,
              positionSec: position, durationSec: duration),
      onWatched:
          data == null ? null : () => _completeLesson(data, lesson.id, courseId),
    );
  }
}

/// Debajo del video: que el avance se guarda solo, cuánto vio y si la
/// lección ya está completa.
class _Footer extends StatelessWidget {
  final Lesson lesson;
  final String? courseId;
  final bool trackProgress;

  const _Footer({
    required this.lesson,
    required this.courseId,
    required this.trackProgress,
  });

  @override
  Widget build(BuildContext context) {
    final description = lesson.description.trim();
    final conAvance = lesson.youtubeVideoId != null || lesson.isUploadedVideo;

    final data =
        trackProgress && conAvance ? context.watch<DataProvider>() : null;
    final watched = data?.myVideoProgress(lesson.id)?.watchedRatio;
    final course = courseId;
    final complete = data != null &&
        course != null &&
        (data.courseProgress(course).valueOrNull?.isLessonComplete(lesson.id) ??
            false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty) ...[
          Text(description,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45)),
          const SizedBox(height: 10),
        ],
        if (data != null)
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 15, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                        tr.videoAvanceSeGuarda,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: complete
                    ? Row(
                        key: ValueKey('completa'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 15, color: AppColors.statusGood),
                          SizedBox(width: 6),
                          Text(tr.videoLeccionCompletada,
                              style: TextStyle(
                                  color: AppColors.statusGood,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      )
                    : watched != null && watched > 0
                        ? Text(tr.videoVisto((watched * 100).round()),
                            key: const ValueKey('visto'),
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))
                        : const SizedBox.shrink(key: ValueKey('nada')),
              ),
            ],
          ),
      ],
    );
  }
}

/// Convierte un enlace de YouTube o Vimeo en su URL de *embed*, o `null` si no
/// se reconoce.
///
/// Es función suelta y pública para poder probarla sin montar ningún widget:
/// es la parte con más casos raros de todo el reproductor y la que se rompe en
/// silencio (un iframe mal formado no lanza nada, solo se ve gris).
///
/// El id de YouTube lo saca [youtubeVideoIdFrom], el mismo que usa el editor
/// de lecciones: una sola definición de «qué es un video de YouTube». Se usa
/// `youtube-nocookie.com` en vez de `youtube.com`: no deja cookies de
/// seguimiento hasta que alguien le da play, que es lo correcto para una
/// plataforma educativa.
String? embedUrlFor(String raw) {
  final id = youtubeVideoIdFrom(raw);
  if (id != null) return 'https://www.youtube-nocookie.com/embed/$id';

  final vimeo = vimeoVideoIdFrom(raw);
  if (vimeo != null) return 'https://player.vimeo.com/video/$vimeo';

  return null;
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final (String, VoidCallback)? action;

  const _Panel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(action!.$1),
              onPressed: action!.$2,
            ),
          ],
        ],
      ),
    );
  }
}
