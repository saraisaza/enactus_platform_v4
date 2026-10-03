import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Un `video_player` falso para las pruebas de widgets.
///
/// Igual que el WebView falso de YouTube: el `VideoPlayerController` y el
/// `VideoPlayer` son los del paquete, de verdad; lo único falso es la
/// plataforma de abajo, que emite los MISMOS eventos que emitiría el `<video>`
/// del navegador (inicializado, buffering, terminado) y contesta la posición
/// que la prueba le fija con [posicion].
class FakeVideoPlayer extends VideoPlayerPlatform {
  final List<String> urls = [];
  final List<String> llamadas = [];
  final Map<int, StreamController<VideoEvent>> _eventos = {};
  final Map<int, Duration> _posiciones = {};
  Duration duracion = const Duration(seconds: 212);

  /// La próxima creación falla como falla un `<video>` sin red.
  bool fallarAlCrear = false;
  int _siguiente = 0;

  static FakeVideoPlayer install() {
    final fake = FakeVideoPlayer();
    VideoPlayerPlatform.instance = fake;
    return fake;
  }

  int get ultimo => _siguiente - 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) =>
      createWithOptions(VideoCreationOptions(
          dataSource: dataSource, viewType: VideoViewType.platformView));

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _siguiente++;
    urls.add(options.dataSource.uri ?? '');
    // El `onCancel` no está de adorno: sin él, `cancel()` devuelve un future
    // de la zona raíz, que el reloj falso de `testWidgets` nunca procesa, y
    // el `dispose` del controlador se queda esperándolo para siempre.
    final eventos = StreamController<VideoEvent>(
        onCancel: () => Future<void>.value());
    _eventos[id] = eventos;
    _posiciones[id] = Duration.zero;
    final fallar = fallarAlCrear;
    fallarAlCrear = false;
    scheduleMicrotask(() {
      if (fallar) {
        eventos.addError(PlatformException(
            code: 'MEDIA_ERR_NETWORK', message: 'Se cortó la conexión'));
      } else {
        eventos.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duracion,
          size: const Size(1280, 720),
        ));
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _eventos[playerId]!.stream;

  void posicion(int playerId, Duration d) => _posiciones[playerId] = d;

  void evento(int playerId, VideoEvent e) => _eventos[playerId]!.add(e);

  @override
  Future<Duration> getPosition(int playerId) async =>
      _posiciones[playerId] ?? Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    llamadas.add('seek ${position.inSeconds}');
    _posiciones[playerId] = position;
  }

  @override
  Future<void> play(int playerId) async => llamadas.add('play');

  @override
  Future<void> pause(int playerId) async => llamadas.add('pause');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      llamadas.add('volume ${volume.toStringAsFixed(1)}');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      llamadas.add('speed $speed');

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setWebOptions(int playerId, VideoPlayerWebOptions options) async {}

  @override
  Future<void> dispose(int playerId) async {
    llamadas.add('dispose');
    await _eventos.remove(playerId)?.close();
  }

  @override
  Widget buildView(int playerId) =>
      SizedBox.expand(key: ValueKey('video-$playerId'));

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      buildView(options.playerId);
}
