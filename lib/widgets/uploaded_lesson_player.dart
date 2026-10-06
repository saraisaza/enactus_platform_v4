import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/video_watch_tracker.dart';
import 'fullscreen_io.dart' if (dart.library.js_interop) 'fullscreen_web.dart';
import 'lesson_video_shell.dart';
import 'video_controls.dart';

/// Crea el controlador de `video_player` para una URL. Las pruebas lo
/// reemplazan; la app usa el de siempre.
typedef VideoControllerFactory = VideoPlayerController Function(String url);

/// Reproductor del video SUBIDO de una lección, siempre en 16:9.
///
/// Mismo recorrido que el de YouTube, para que quien mira no note de dónde
/// viene el video: la portada con el botón de reproducir, el video recién al
/// tocarlo, el avance guardado ([VideoWatchTracker]) y, si algo falla, el
/// error con «Reintentar».
///
/// El video sale de CloudFront con una URL firmada que vence a los cinco
/// minutos ([LessonVideoSource]). Se pide al abrir —para mostrar la portada—
/// y otra vez al tocar «reproducir» si ya venció. Alcanza: CloudFront valida
/// la firma al abrir la conexión, así que un video de una hora se ve entero.
///
/// Con [localUrl] reproduce un archivo que todavía no se subió (la vista
/// previa del editor, con la URL `blob:` del navegador) y no pide nada.
class UploadedLessonPlayer extends StatefulWidget {
  const UploadedLessonPlayer({
    super.key,
    required this.title,
    this.lessonId,
    this.localUrl,
    this.localThumbnail,
    this.durationHint,
    this.resumeAt,
    this.watchedRatio,
    this.onProgress,
    this.onWatched,
    this.borderRadius = 12,
    this.loadTimeout = const Duration(seconds: 30),
    this.controllerFactory,
  }) : assert(lessonId != null || localUrl != null);

  final String title;
  final String? lessonId;
  final String? localUrl;
  final Uint8List? localThumbnail;

  /// Para la etiqueta de la portada, antes de cargar nada.
  final Duration? durationHint;
  final Duration? resumeAt;
  final double? watchedRatio;
  final void Function(int positionSec, int? durationSec)? onProgress;
  final VoidCallback? onWatched;
  final double borderRadius;
  final Duration loadTimeout;
  final VideoControllerFactory? controllerFactory;

  @override
  State<UploadedLessonPlayer> createState() => _UploadedLessonPlayerState();
}

enum _Fase { portada, cargando, listo, error }

class _UploadedLessonPlayerState extends State<UploadedLessonPlayer> {
  _Fase _fase = _Fase.portada;
  VideoPlayerController? _controller;
  VideoWatchTracker? _tracker;
  LessonVideoSource? _fuente;
  Object? _error;
  bool _estabaReproduciendo = false;
  bool _pantallaCompleta = false;

  /// Cada intento invalida los anteriores: uno viejo que termina tarde no
  /// puede pisar a uno nuevo que sí cargó.
  int _intento = 0;

  /// El provider se toma al montar: el último guardado sale del `dispose`,
  /// con el elemento desmontándose, y buscar un ancestro ahí lanza.
  DataProvider? _data;

  bool get _sigueAvance =>
      widget.onProgress != null || widget.onWatched != null;

  @override
  void initState() {
    super.initState();
    if (widget.localUrl == null) {
      _data = context.read<DataProvider>();
      // Solo para la portada: si falla, se ve el fondo genérico y el error
      // real, si lo hay, aparece al tocar «reproducir».
      unawaited(_pedirFuente().then((_) {}, onError: (Object _) {}));
    }
  }

  Future<LessonVideoSource> _pedirFuente() async {
    final fuente = await _data!.fetchLessonVideoSource(widget.lessonId!);
    if (mounted) setState(() => _fuente = fuente);
    return fuente;
  }

  Future<void> _activar() async {
    final intento = ++_intento;
    _soltar();
    setState(() {
      _fase = _Fase.cargando;
      _error = null;
    });

    try {
      final fuente = _fuente;
      final url = widget.localUrl ??
          (fuente != null && fuente.isFresh ? fuente : await _pedirFuente())
              .url;
      final controller = widget.controllerFactory?.call(url) ??
          VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize().timeout(widget.loadTimeout);
      if (!mounted || intento != _intento) return;

      final duracion = controller.value.duration;
      final desde = widget.resumeAt;
      // Retomar casi al final no tiene sentido: se empieza de nuevo.
      if (desde != null &&
          desde > Duration.zero &&
          desde < duracion - const Duration(seconds: 3)) {
        await controller.seekTo(desde);
      }
      if (_sigueAvance) {
        _tracker = VideoWatchTracker(
          onSave: (p, d) => widget.onProgress?.call(p, d),
          onWatched: widget.onWatched,
        )..duration(duracion);
      }
      controller.addListener(_alCambiar);
      setState(() => _fase = _Fase.listo);
      // Si el navegador no deja arrancar solo, queda en pausa con el botón
      // grande a la vista: un toque más y arranca.
      await controller.play();
    } catch (e) {
      if (!mounted || intento != _intento) return;
      _soltar();
      setState(() {
        _fase = _Fase.error;
        _error = e;
      });
    }
  }

  void _alCambiar() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final v = controller.value;
    if (v.hasError) {
      _tracker?.close();
      setState(() {
        _fase = _Fase.error;
        _error = v.errorDescription;
      });
      return;
    }
    _tracker?.position(v.position, duration: v.duration);
    if (_estabaReproduciendo && !v.isPlaying) {
      if (v.isCompleted) {
        _tracker?.ended();
      } else {
        _tracker?.paused();
      }
    }
    _estabaReproduciendo = v.isPlaying;
  }

  /// Guarda lo que haya quedado y suelta el controlador.
  void _soltar() {
    _tracker?.close();
    _tracker = null;
    final anterior = _controller;
    _controller = null;
    _estabaReproduciendo = false;
    if (anterior != null) {
      anterior.removeListener(_alCambiar);
      unawaited(anterior.dispose());
    }
  }

  @override
  void dispose() {
    _intento++;
    _soltar();
    super.dispose();
  }

  Future<void> _alternarPantallaCompleta() async {
    final controller = _controller;
    // Salir lo maneja la ruta de pantalla completa: acá solo se entra.
    if (controller == null || _pantallaCompleta) return;
    // Un solo lugar a la vez para el video: mientras está en pantalla
    // completa, acá queda la portada. En el navegador el video es UN
    // elemento `<video>`, y dos widgets mostrándolo se lo robarían.
    setState(() => _pantallaCompleta = true);
    unawaited(enterSystemFullscreen());
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _PantallaCompleta(controller: controller),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
    unawaited(exitSystemFullscreen());
    if (mounted) setState(() => _pantallaCompleta = false);
  }

  @override
  Widget build(BuildContext context) {
    return VideoBox16x9(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(
          color: Colors.black,
          child: switch (_fase) {
            _Fase.portada => _portada(onPlay: _activar),
            _Fase.cargando => _portada(loading: true),
            _Fase.error => _falla(),
            _Fase.listo when _pantallaCompleta => _portada(loading: false),
            _Fase.listo => _video(),
          },
        ),
      ),
    );
  }

  Widget _video() {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(controller),
          ),
        ),
        LessonVideoControls(
          controller: controller,
          isFullscreen: false,
          onToggleFullscreen: _alternarPantallaCompleta,
          autofocus: true,
        ),
      ],
    );
  }

  Widget _portada({VoidCallback? onPlay, bool loading = false}) {
    final miniatura = _miniatura();
    final duracion = widget.durationHint;
    return LessonVideoCover(
      image: miniatura,
      sourceLabel: duracion != null && duracion > Duration.zero
          ? formatVideoTime(duracion)
          : tr.tipoArchivoVideo,
      sourceIcon: duracion != null && duracion > Duration.zero
          ? Icons.schedule
          : Icons.movie_outlined,
      title: widget.title,
      resumeAt: widget.resumeAt,
      watchedRatio: widget.watchedRatio,
      onPlay: onPlay,
      loading: loading,
    );
  }

  Widget? _miniatura() {
    final local = widget.localThumbnail;
    if (local != null) {
      return Image.memory(local, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final url = _fuente?.thumbnailUrl;
    if (url == null) return null;
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Un `<img>` del navegador: sin CORS, y la CSP solo tiene que permitir
      // `img-src https://videos.eduxaction.com`.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) => const VideoCoverFallback(),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const VideoCoverFallback(),
    );
  }

  Widget _falla() {
    final error = _error;
    // Reintentar un 503 de configuración no arregla nada: no se ofrece. El
    // mensaje del servidor dice QUÉ falta, que es lo que necesita el equipo.
    if (error is ApiException && error.code == 'cdn_not_configured') {
      return LessonVideoFailure(
        title: tr.videoNoDisponibleEntorno,
        detail: error.message,
      );
    }
    if (error is NotFoundError) {
      return LessonVideoFailure(
        title: tr.videoYaNoDisponible,
        detail: tr.videoAviseCreador,
      );
    }
    return LessonVideoFailure(
      title: tr.videoNoCarga,
      detail: tr.videoPuedeSerConexion,
      onRetry: _activar,
    );
  }
}

/// El video ocupando toda la pantalla, con los mismos controles.
class _PantallaCompleta extends StatefulWidget {
  const _PantallaCompleta({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_PantallaCompleta> createState() => _PantallaCompletaState();
}

class _PantallaCompletaState extends State<_PantallaCompleta> {
  StreamSubscription<void>? _salida;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    // Esc lo maneja el navegador: sale de SU pantalla completa y avisa. Se
    // cierra la nuestra también, o quedaría un video tapando la app sin el
    // modo que la justifica.
    _salida = onSystemFullscreenExit(_salir);
  }

  /// Sale UNA vez, y solo si esta ruta sigue arriba.
  ///
  /// Salir con el botón (o con F) cierra esta ruta y después saca al
  /// navegador de pantalla completa; el navegador avisa esa salida, y sin esta
  /// guarda ese aviso volvía a cerrar «la ruta de arriba» — que para entonces
  /// era el diálogo de la lección.
  void _salir() {
    if (_saliendo || !mounted) return;
    _saliendo = true;
    _salida?.cancel();
    final ruta = ModalRoute.of(context);
    if (ruta != null && ruta.isCurrent) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _salida?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
            LessonVideoControls(
              controller: controller,
              isFullscreen: true,
              onToggleFullscreen: _salir,
              autofocus: true,
            ),
          ],
        ),
      ),
    );
  }
}
