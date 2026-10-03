import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/video_watch_tracker.dart';
import '../utils/youtube.dart';
import 'common.dart';
import 'lesson_video_shell.dart';

export 'lesson_video_shell.dart' show formatVideoTime;

/// Reproductor de una lección de YouTube, siempre en 16:9.
///
/// **Primero la miniatura, después el reproductor.** El reproductor de
/// YouTube es una página web entera adentro de la nuestra (en el navegador, un
/// iframe; en las apps, un WebView): crearlo cuesta y descarga varios cientos
/// de KB. Así que hasta que alguien toca «reproducir» se muestra solo la
/// miniatura, y recién ahí se crea — con lo que además YouTube no sabe nada
/// de quien abrió la lección sin mirar el video.
///
/// **El avance lo decide [VideoWatchTracker]**, no este widget: acá solo se
/// le pasan los eventos del reproductor. Con [onProgress] y [onWatched] en
/// `null` no se sigue nada — es la vista previa del LXD, o alguien del equipo
/// mirando el curso de un estudiante.
///
/// **Si no carga, lo dice.** Un reproductor que se queda en la ruedita para
/// siempre es indistinguible de uno roto, y en el navegador la causa más
/// probable es invisible: la CSP del sitio bloqueando el script de YouTube
/// (ver MIGRACION_FRONT.md, «Reproductor de YouTube»). Pasado [loadTimeout]
/// se muestra el error con la salida de verlo en YouTube.
class YoutubeLessonPlayer extends StatefulWidget {
  const YoutubeLessonPlayer({
    super.key,
    required this.videoId,
    required this.title,
    this.resumeAt,
    this.watchedRatio,
    this.onProgress,
    this.onWatched,
    this.loadTimeout = const Duration(seconds: 20),
    this.borderRadius = 12,
  });

  final String videoId;
  final String title;

  /// Desde dónde arrancar. `null` = desde el principio.
  final Duration? resumeAt;

  /// Cuánto había visto (0..1), para la barrita sobre la miniatura.
  final double? watchedRatio;

  /// Posición y duración en segundos, cuando conviene guardarlas.
  final void Function(int positionSec, int? durationSec)? onProgress;

  /// Pasó el 90% o terminó. Llega una sola vez.
  final VoidCallback? onWatched;

  final Duration loadTimeout;

  /// 0 cuando el video va de borde a borde (un teléfono): esquinas redondeadas
  /// contra el borde de la pantalla se ven como un error.
  final double borderRadius;

  /// Id fijo del reproductor, y no uno por video.
  ///
  /// En el navegador el paquete arma la página del reproductor con un
  /// `<script>` en línea que lleva este id adentro. Con un id fijo ese script
  /// es SIEMPRE el mismo texto (por origen), así que la CSP lo puede autorizar
  /// por su hash, sin abrir `'unsafe-inline'` para todo el sitio. Con uno por
  /// video o por instancia —lo que hace el paquete solo— el hash cambiaría
  /// cada vez.
  ///
  /// Solo hay un reproductor a la vez (el diálogo de la lección), así que
  /// compartirlo no mezcla mensajes entre dos reproductores vivos.
  static const playerId = 'youtube_leccion';

  @override
  State<YoutubeLessonPlayer> createState() => _YoutubeLessonPlayerState();
}

enum _Fase { miniatura, cargando, listo, error }

class _YoutubeLessonPlayerState extends State<YoutubeLessonPlayer> {
  _Fase _fase = _Fase.miniatura;
  YoutubePlayerController? _controller;
  VideoWatchTracker? _tracker;
  final List<StreamSubscription<Object?>> _subs = [];

  /// El error que informó YouTube; `null` si el problema fue que no cargó.
  YoutubeError? _errorYoutube;

  /// `playVideo()` se pide una sola vez, cuando el video queda listo.
  bool _pidioPlay = false;

  /// Cada intento invalida los anteriores: un timeout viejo no puede marcar
  /// como fallido un reintento que sí cargó.
  int _intento = 0;

  static const _params = YoutubePlayerParams(
    showControls: true,
    showFullscreenButton: true,
    // Los videos relacionados del final, solo del mismo canal: una lección
    // no debería terminar ofreciendo cualquier cosa de YouTube.
    strictRelatedVideos: true,
    // Los subtítulos quedan a elección de cada quien (botón CC); forzarlos
    // pisaría la preferencia de su cuenta.
    enableCaption: false,
    captionLanguage: 'es',
    interfaceLanguage: 'es',
    playsInline: true,
    // Una posición por segundo alcanza para guardar el avance; las diez por
    // segundo de fábrica son tráfico de más entre el reproductor y Flutter.
    videoStateUpdateInterval: 1000,
  );

  bool get _sigueAvance =>
      widget.onProgress != null || widget.onWatched != null;

  Future<void> _activar() async {
    final intento = ++_intento;
    _soltarReproductor();

    final controller = _ControladorLeccion(params: _params);
    if (_sigueAvance) {
      _tracker = VideoWatchTracker(
        onSave: (p, d) => widget.onProgress?.call(p, d),
        onWatched: widget.onWatched,
      );
    }
    _subs
      ..add(controller.stream.listen(_alCambiar))
      ..add(controller.videoStateStream.listen(_alAvanzar));

    setState(() {
      _controller = controller;
      _fase = _Fase.cargando;
      _errorYoutube = null;
      _pidioPlay = false;
    });

    try {
      // `cue` y no `load`: si el navegador no deja arrancar solo, el video
      // queda listo con el botón de play de YouTube a la vista. Con `load`
      // quedaría en «sin empezar» debajo de la carátula, sin forma de tocarlo.
      await controller
          .cueVideoById(
            videoId: widget.videoId,
            startSeconds: widget.resumeAt?.inSeconds.toDouble(),
          )
          .timeout(widget.loadTimeout);
    } catch (_) {
      // Timeout o un reproductor que nunca dijo «listo»: se informa igual.
      if (mounted && intento == _intento && _fase == _Fase.cargando) {
        setState(() => _fase = _Fase.error);
      }
    }
  }

  void _alCambiar(YoutubePlayerValue value) {
    final controller = _controller;
    if (!mounted || controller == null) return;

    final duracion = value.metaData.duration;
    if (duracion > Duration.zero) _tracker?.duration(duracion);

    if (value.hasError) {
      _tracker?.close();
      setState(() {
        _errorYoutube = value.error;
        _fase = _Fase.error;
      });
      return;
    }

    switch (value.playerState) {
      case PlayerState.cued:
        if (!_pidioPlay) {
          _pidioPlay = true;
          unawaited(controller.playVideo());
        }
        _marcarListo();
      case PlayerState.playing:
      case PlayerState.buffering:
        _marcarListo();
      case PlayerState.paused:
        _tracker?.paused();
        _marcarListo();
      case PlayerState.ended:
        _tracker?.ended();
      case PlayerState.unknown:
      case PlayerState.unStarted:
        break;
    }
  }

  void _alAvanzar(YoutubeVideoState state) {
    final duracion = _controller?.value.metaData.duration;
    _tracker?.position(
      state.position,
      duration: duracion == null || duracion == Duration.zero ? null : duracion,
    );
  }

  void _marcarListo() {
    if (_fase == _Fase.cargando) setState(() => _fase = _Fase.listo);
  }

  /// Guarda lo que haya quedado y suelta el reproductor anterior.
  void _soltarReproductor() {
    _tracker?.close();
    _tracker = null;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    final anterior = _controller;
    _controller = null;
    if (anterior != null) unawaited(anterior.close());
  }

  @override
  void dispose() {
    _soltarReproductor();
    super.dispose();
  }

  Future<void> _abrirEnYoutube() async {
    final desde = widget.resumeAt?.inSeconds;
    final uri = Uri.parse(youtubeWatchUrl(widget.videoId) +
        (desde == null ? '' : '&t=${desde}s'));
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showAppSnack(context, 'No se pudo abrir YouTube.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VideoBox16x9(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(
          color: Colors.black,
          child: switch (_fase) {
            _Fase.miniatura => LessonVideoCover(
                image: _Miniatura(widget.videoId),
                sourceLabel: 'YouTube',
                sourceIcon: Icons.smart_display_outlined,
                title: widget.title,
                resumeAt: widget.resumeAt,
                watchedRatio: widget.watchedRatio,
                onPlay: _activar,
              ),
            _Fase.error => _Fallo(
                error: _errorYoutube,
                onRetry: _activar,
                onOpenYoutube: _abrirEnYoutube,
              ),
            _Fase.cargando || _Fase.listo => Stack(
                fit: StackFit.expand,
                children: [
                  YoutubePlayer(
                    controller: _controller!,
                    aspectRatio: 16 / 9,
                    backgroundColor: Colors.black,
                  ),
                  // La misma carátula con la ruedita, hasta que el reproductor
                  // está listo: así la miniatura no "salta" a un cuadro negro.
                  IgnorePointer(
                    ignoring: _fase == _Fase.listo,
                    child: AnimatedOpacity(
                      opacity: _fase == _Fase.listo ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: LessonVideoCover(
                        image: _Miniatura(widget.videoId),
                        sourceLabel: 'YouTube',
                        sourceIcon: Icons.smart_display_outlined,
                        title: widget.title,
                        resumeAt: widget.resumeAt,
                        watchedRatio: widget.watchedRatio,
                        loading: true,
                      ),
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

/// El controlador del paquete con el id fijo y sin `key`.
///
/// El paquete arma el id del reproductor a partir de `key`, pero también usa
/// `key` como id del VIDEO: su capa de carga pide la miniatura
/// `i3.ytimg.com/vi_webp/<key>/…`. Con `key: 'leccion'` pedía una imagen que
/// no existe, y en el sitio la CSP la bloqueaba con un error en la consola en
/// cada reproducción. Sin `key` esa capa no pide nada —la miniatura ya la
/// pone la carátula— y el id se fija acá.
class _ControladorLeccion extends YoutubePlayerController {
  _ControladorLeccion({super.params});

  // El paquete lo marca @internal, pero lo lee siempre por este getter: el
  // canal de mensajes, la página del reproductor, el filtro de eventos y el
  // cierre. Si una versión nueva dejara de hacerlo, el reproductor no
  // arrancaría y lo atrapan las pruebas de `youtube_player_test.dart`.
  @override
  String get playerId => YoutubeLessonPlayer.playerId;
}

/// No cargó, o YouTube no lo deja ver acá. Siempre con una salida.
class _Fallo extends StatelessWidget {
  final YoutubeError? error;
  final VoidCallback onRetry;
  final VoidCallback onOpenYoutube;

  const _Fallo({
    required this.error,
    required this.onRetry,
    required this.onOpenYoutube,
  });

  /// Qué pasó, en palabras de quien lo está mirando.
  (String, String) get _mensaje => switch (error) {
        null => (
            'No se pudo cargar el reproductor',
            'Puede ser la conexión, o que el navegador esté bloqueando a '
                'YouTube. Puede intentar de nuevo o verlo directamente allá.',
          ),
        YoutubeError.notEmbeddable ||
        YoutubeError.sameAsNotEmbeddable ||
        YoutubeError.sameAsNotEmbeddable2 =>
          (
            'Este video solo se puede ver en YouTube',
            'Quien lo subió no permite reproducirlo fuera de YouTube.',
          ),
        YoutubeError.videoNotFound || YoutubeError.cannotFindVideo => (
            'Este video ya no está disponible',
            'Lo borraron de YouTube o lo hicieron privado. Avísele a quien '
                'armó el curso.',
          ),
        YoutubeError.invalidParam => (
            'El video guardado no es válido',
            'Avísele a quien armó el curso para que revise el enlace.',
          ),
        _ => (
            'YouTube no pudo reproducir el video',
            'Pruebe de nuevo, o mírelo directamente en YouTube.',
          ),
      };

  bool get _puedeReintentar =>
      error == null ||
      error == YoutubeError.html5Error ||
      error == YoutubeError.unknown;

  @override
  Widget build(BuildContext context) {
    final (titulo, detalle) = _mensaje;
    final noExiste = error == YoutubeError.videoNotFound ||
        error == YoutubeError.cannotFindVideo;
    return LessonVideoFailure(
      title: titulo,
      detail: detalle,
      onRetry: _puedeReintentar ? onRetry : null,
      secondary:
          noExiste ? null : ('Ver en YouTube', Icons.open_in_new, onOpenYoutube),
    );
  }
}

/// La miniatura de YouTube. Un `<img>` del navegador: no necesita CORS y la
/// CSP solo tiene que permitir `img-src https://i.ytimg.com`.
class _Miniatura extends StatelessWidget {
  final String videoId;
  const _Miniatura(this.videoId);

  @override
  Widget build(BuildContext context) => Image.network(
        youtubeThumbnailUrl(videoId),
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => const VideoCoverFallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const VideoCoverFallback(),
      );
}
