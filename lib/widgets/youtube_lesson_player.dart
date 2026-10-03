import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/app_theme.dart';
import '../utils/video_watch_tracker.dart';
import '../utils/youtube.dart';
import 'common.dart';

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

  /// Clave fija del reproductor, y no una por video.
  ///
  /// En el navegador el paquete arma la página del reproductor con un
  /// `<script>` en línea que lleva esta clave adentro. Con una clave fija ese
  /// script es SIEMPRE el mismo texto (por origen), así que la CSP lo puede
  /// autorizar por su hash, sin abrir `'unsafe-inline'` para todo el sitio.
  /// Con una clave por video o por instancia, el hash cambiaría cada vez.
  ///
  /// Solo hay un reproductor a la vez (el diálogo de la lección), así que
  /// compartirla no mezcla mensajes entre dos reproductores vivos.
  static const playerKey = 'leccion';

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

    final controller = YoutubePlayerController(
      key: YoutubeLessonPlayer.playerKey,
      params: _params,
    );
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
    return _Caja16x9(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(
          color: Colors.black,
          child: switch (_fase) {
            _Fase.miniatura => _Caratula(
                videoId: widget.videoId,
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
                      child: _Caratula(
                        videoId: widget.videoId,
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

/// 16:9 que responde sus medidas intrínsecas con la proporción, sin
/// preguntarle a lo que tiene adentro.
///
/// Hace falta porque adentro hay `LayoutBuilder` —en la carátula, y en el
/// reproductor del paquete en Android/iOS— y un `LayoutBuilder` no sabe
/// responder medidas intrínsecas: lanza. Un `AlertDialog` las pide siempre
/// (envuelve su contenido en un `IntrinsicWidth`), y la vista previa del
/// editor de lecciones vive en uno. Sin esto, pegar un enlace en el editor
/// rompía el diálogo entero.
class _Caja16x9 extends AspectRatio {
  const _Caja16x9({super.child}) : super(aspectRatio: 16 / 9);

  @override
  RenderAspectRatio createRenderObject(BuildContext context) =>
      _RenderCaja16x9(aspectRatio: aspectRatio);
}

class _RenderCaja16x9 extends RenderAspectRatio {
  _RenderCaja16x9({required super.aspectRatio});

  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? height * aspectRatio : 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite ? height * aspectRatio : 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite ? width / aspectRatio : 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      width.isFinite ? width / aspectRatio : 0;
}

/// La miniatura con el botón de reproducir.
class _Caratula extends StatelessWidget {
  final String videoId;
  final String title;
  final Duration? resumeAt;
  final double? watchedRatio;
  final VoidCallback? onPlay;
  final bool loading;

  const _Caratula({
    required this.videoId,
    required this.title,
    this.resumeAt,
    this.watchedRatio,
    this.onPlay,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // En un teléfono el reproductor mide ~360 px de ancho: el botón y las
      // etiquetas se achican para no tapar la miniatura entera.
      final chico = constraints.maxWidth < 480;
      final resume = resumeAt;

      return KeyboardHoverBuilder(
        onTap: loading ? null : onPlay,
        builder: (context, activo) => Semantics(
          label: loading
              ? 'Cargando el video «$title»'
              : resume == null
                  ? 'Reproducir el video «$title»'
                  : 'Seguir viendo «$title» desde ${formatVideoTime(resume)}',
          excludeSemantics: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                youtubeThumbnailUrl(videoId),
                fit: BoxFit.cover,
                // Un `<img>` del navegador: no necesita CORS y la CSP solo
                // tiene que permitir `img-src https://i.ytimg.com`.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, _, _) => const _FondoSinMiniatura(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const _FondoSinMiniatura(),
              ),
              // Degradé para que las etiquetas se lean sobre cualquier imagen.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xB3000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              Center(
                child: loading
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      )
                    : AnimatedScale(
                        scale: activo ? 1.08 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: chico ? 56 : 72,
                          height: chico ? 56 : 72,
                          decoration: BoxDecoration(
                            color: activo
                                ? AppColors.goldBright
                                : AppColors.gold,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 6)),
                            ],
                          ),
                          // Tinta oscura sobre el ámbar: blanco ahí da 1.6:1.
                          child: Icon(Icons.play_arrow_rounded,
                              color: AppColors.ink, size: chico ? 34 : 44),
                        ),
                      ),
              ),
              Positioned(
                left: chico ? 10 : 14,
                right: chico ? 10 : 14,
                bottom: chico ? 10 : 14,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const _Etiqueta(
                        icon: Icons.smart_display_outlined, text: 'YouTube'),
                    if (loading)
                      const _Etiqueta(
                          icon: Icons.hourglass_empty,
                          text: 'Cargando el video…')
                    else if (resume != null)
                      _Etiqueta(
                          icon: Icons.history,
                          text: 'Seguir desde ${formatVideoTime(resume)}'),
                  ],
                ),
              ),
              if ((watchedRatio ?? 0) > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: watchedRatio,
                    minHeight: 4,
                    backgroundColor: const Color(0x55FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _FondoSinMiniatura extends StatelessWidget {
  const _FondoSinMiniatura();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.slate, AppColors.slateDark],
        ),
      ),
      child: Center(
        child: Icon(Icons.smart_display_outlined,
            color: AppColors.textMuted, size: 48),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Etiqueta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
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
                'YouTube. Puedes intentar de nuevo o verlo directamente allá.',
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
            'Lo borraron de YouTube o lo hicieron privado. Avísale a quien '
                'armó el curso.',
          ),
        YoutubeError.invalidParam => (
            'El video guardado no es válido',
            'Avísale a quien armó el curso para que revise el enlace.',
          ),
        _ => (
            'YouTube no pudo reproducir el video',
            'Prueba de nuevo, o míralo directamente en YouTube.',
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

    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 40, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(detalle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_puedeReintentar)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar'),
                      onPressed: onRetry,
                    ),
                  if (!noExiste)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Ver en YouTube'),
                      onPressed: onOpenYoutube,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `m:ss`, o `h:mm:ss` en videos de una hora o más.
String formatVideoTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
