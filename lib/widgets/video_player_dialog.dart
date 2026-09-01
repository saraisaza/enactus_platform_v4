import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../services/video_source_io.dart'
    if (dart.library.js_interop) '../services/video_source_web.dart';
import '../utils/app_theme.dart';

/// Reproductor de video de una lección.
///
/// El video tiene dos orígenes y **no se tratan igual**:
///
/// - **`external`** — un enlace de YouTube o Vimeo. En el navegador se embebe
///   en un `<iframe>`; fuera del navegador no hay iframe, así que se abre en la
///   aplicación del sistema. La conversión a URL de *embed* la hace
///   [embedUrlFor]: el enlace que la gente pega (`youtube.com/watch?v=…`) NO se
///   deja embeber —responde `X-Frame-Options`— y embeberlo daría un recuadro en
///   blanco sin ningún error visible.
///
/// - **`uploaded`** — un archivo propio. Se pide `GET /lessons/:id/video-url`,
///   que devuelve una URL firmada de CloudFront con cinco minutos de vigencia,
///   y se reproduce con un `<video>` HTML5. **Nunca por URL firmada de S3**: es
///   una decisión de costo y la API rechaza esas keys con 400.
///
/// Los tres estados son obligatorios, como en el resto de la app: mientras se
/// pide la URL hay un indicador; si falla, el error con botón de reintentar; y
/// si la lección no tiene video, el estado vacío. Una pantalla de video que se
/// queda cargando para siempre es indistinguible de una rota.
class VideoPlayerDialog extends StatelessWidget {
  final Lesson lesson;
  const VideoPlayerDialog({super.key, required this.lesson});

  static Future<void> show(BuildContext context, Lesson lesson) {
    return showDialog(
      context: context,
      builder: (_) => VideoPlayerDialog(lesson: lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_outline, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(lesson.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(aspectRatio: 16 / 9, child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final url = lesson.videoUrl;
    if (lesson.isExternalVideo && url != null && url.isNotEmpty) {
      final embed = embedUrlFor(url);
      if (puedeEmbeber && embed != null) return buildEmbeddedVideo(embed);
      // Un enlace que no es YouTube ni Vimeo —o una plataforma sin iframe—
      // se abre afuera. No se intenta embeber a ciegas: la mayoría de los
      // sitios lo bloquean y el recuadro queda en blanco sin decir por qué.
      return _Panel(
        icon: Icons.open_in_new,
        title: 'Ver el video',
        message: 'Se abre en una pestaña nueva.',
        action: ('Abrir video', () => _open(context, url)),
      );
    }

    if (lesson.isUploadedVideo) {
      return _UploadedVideo(lessonId: lesson.id);
    }

    return const _Panel(
      icon: Icons.videocam_off_outlined,
      title: 'Esta lección todavía no tiene video',
      message: 'Quien la creó aún no le cargó ninguno.',
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace del video.')),
      );
    }
  }
}

/// Convierte un enlace de YouTube o Vimeo en su URL de *embed*, o `null` si no
/// se reconoce.
///
/// Es función suelta y pública para poder probarla sin montar ningún widget:
/// es la parte con más casos raros de todo el reproductor y la que se rompe en
/// silencio (un iframe mal formado no lanza nada, solo se ve gris).
///
/// Se usa `youtube-nocookie.com` en vez de `youtube.com`: no deja cookies de
/// seguimiento hasta que alguien le da play, que es lo correcto para una
/// plataforma educativa.
String? embedUrlFor(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasAuthority) return null;

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? youtube() {
    if (host == 'youtu.be') {
      return segments.isEmpty ? null : segments.first;
    }
    if (host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'youtube-nocookie.com') {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      // `/embed/ID` y `/shorts/ID` traen el id en la ruta.
      if (segments.length >= 2 &&
          (segments.first == 'embed' || segments.first == 'shorts')) {
        return segments[1];
      }
    }
    return null;
  }

  final id = youtube();
  if (id != null && RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(id)) {
    return 'https://www.youtube-nocookie.com/embed/$id';
  }

  if (host == 'vimeo.com' || host == 'player.vimeo.com') {
    // El id de Vimeo es el último segmento numérico: cubre `vimeo.com/123`,
    // `vimeo.com/channels/staffpicks/123` y `player.vimeo.com/video/123`.
    for (final segment in segments.reversed) {
      if (RegExp(r'^\d+$').hasMatch(segment)) {
        return 'https://player.vimeo.com/video/$segment';
      }
    }
  }

  return null;
}

/// Video propio: pide la URL firmada y la reproduce.
class _UploadedVideo extends StatefulWidget {
  final String lessonId;
  const _UploadedVideo({required this.lessonId});

  @override
  State<_UploadedVideo> createState() => _UploadedVideoState();
}

class _UploadedVideoState extends State<_UploadedVideo> {
  VideoPlayerController? _controller;
  Object? _playbackError;
  String? _preparedUrl;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Se prepara el reproductor una sola vez por URL.
  ///
  /// La URL se refresca sola al vencer (cinco minutos), y sin esta guarda cada
  /// rebuild del provider crearía un controlador nuevo y dejaría el anterior
  /// vivo: el video se reiniciaría solo y se filtrarían controladores.
  void _prepare(String url) {
    if (_preparedUrl == url) return;
    _preparedUrl = url;
    final anterior = _controller;
    _controller = null;
    _playbackError = null;

    createSignedVideoController(url).then((controller) {
      anterior?.dispose();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    }).catchError((Object error) {
      anterior?.dispose();
      if (mounted) setState(() => _playbackError = error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return data.lessonVideoUrl(widget.lessonId).when(
          loading: () => const _Panel(
            icon: Icons.hourglass_empty,
            title: 'Preparando el video…',
            message: 'Pidiendo el permiso de reproducción.',
          ),
          error: (e) => _ErrorPanel(
            error: e,
            onRetry: () => data.reloadLessonVideoUrl(widget.lessonId),
          ),
          data: (url) {
            // No se llama dentro del build: crear el controlador dispara un
            // `setState`, y hacerlo durante la construcción es un error.
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _prepare(url));

            final error = _playbackError;
            if (error != null) {
              return _Panel(
                icon: Icons.error_outline,
                title: 'No se pudo reproducir el video',
                message: '$error',
                action: (
                  'Reintentar',
                  () {
                    setState(() {
                      _preparedUrl = null;
                      _playbackError = null;
                    });
                    data.reloadLessonVideoUrl(widget.lessonId);
                  }
                ),
              );
            }

            final controller = _controller;
            if (controller == null) {
              return const _Panel(
                icon: Icons.hourglass_empty,
                title: 'Cargando el video…',
                message: 'Ya casi.',
              );
            }
            return _Surface(controller: controller);
          },
        );
  }
}

/// El `<video>` con sus controles.
class _Surface extends StatefulWidget {
  final VideoPlayerController controller;
  const _Surface({required this.controller});

  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          VideoProgressIndicator(widget.controller, allowScrubbing: true),
          Center(
            child: IconButton(
              iconSize: 56,
              color: Colors.white,
              icon: Icon(
                widget.controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
              ),
              onPressed: () => setState(() {
                widget.controller.value.isPlaying
                    ? widget.controller.pause()
                    : widget.controller.play();
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error de la API con reintento, en el mismo formato que el resto de la app.
class _ErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // El 503 de un entorno sin CloudFront no es un fallo de la persona ni un
    // error de red: se dice qué pasa en vez de "algo salió mal".
    final sinCdn = error is ApiException &&
        (error as ApiException).code == 'cdn_not_configured';

    return _Panel(
      icon: sinCdn ? Icons.cloud_off_outlined : Icons.wifi_off_outlined,
      title: sinCdn
          ? 'Reproducción no disponible en este entorno'
          : 'No pudimos preparar el video',
      message: error is ApiException
          ? (error as ApiException).message
          : '$error',
      action: sinCdn ? null : ('Reintentar', onRetry),
    );
  }
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
