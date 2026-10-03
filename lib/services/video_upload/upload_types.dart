import 'dart:typed_data';

import 'picked_video.dart';

/// Lo que el navegador sabe del video sin subirlo: duración, tamaño de la
/// imagen y un fotograma para la portada.
class VideoProbe {
  const VideoProbe({
    required this.duration,
    required this.width,
    required this.height,
    this.frameJpeg,
  });

  final Duration duration;
  final int width;
  final int height;

  /// Un fotograma en JPEG, para la portada automática. `null` si no se pudo.
  final Uint8List? frameJpeg;
}

/// Una parte del video, con la URL firmada para subirla.
class VideoPart {
  const VideoPart({
    required this.url,
    required this.video,
    required this.partNumber,
    required this.start,
    required this.end,
  });

  final String url;
  final PickedVideo video;
  final int partNumber;
  final int start;
  final int end;

  int get sizeBytes => end - start;
}

/// Cancelar una subida: corta lo que esté en vuelo y no deja empezar más.
class UploadAbort {
  bool _aborted = false;
  final List<void Function()> _listeners = [];

  bool get aborted => _aborted;

  void abort() {
    if (_aborted) return;
    _aborted = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  /// Avisa al cancelar. Devuelve con qué dejar de escuchar.
  void Function() onAbort(void Function() listener) {
    if (_aborted) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

/// Quien subía la canceló.
class UploadCancelled implements Exception {
  const UploadCancelled();
  @override
  String toString() => 'La subida se canceló.';
}

/// Una parte no llegó: se cortó la conexión o S3 la rechazó.
class PartUploadError implements Exception {
  const PartUploadError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sube UNA parte y devuelve el código HTTP de S3. Informa los bytes enviados
/// de esa parte con [onProgress].
typedef PartSender = Future<int> Function(
  VideoPart part, {
  required void Function(int sentBytes) onProgress,
  required UploadAbort abort,
});

/// Escucha archivos soltados sobre la página. Ver `listenForVideoDrops`.
abstract class VideoDropListener {
  void dispose();
}
