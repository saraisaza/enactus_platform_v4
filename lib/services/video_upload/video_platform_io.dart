import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'picked_video.dart';
import 'upload_types.dart';

/// Un video en disco: se lee por rangos, nunca entero.
class IoPickedVideo extends PickedVideo {
  IoPickedVideo(this.file);

  final File file;

  @override
  String get name => file.uri.pathSegments.last;
  @override
  int get sizeBytes => file.lengthSync();
  @override
  String get mimeType => 'video/mp4';
  @override
  int? get lastModifiedMs => file.lastModifiedSync().millisecondsSinceEpoch;
  @override
  String? get previewUrl => null;

  @override
  Future<Uint8List> readRange(int start, int end) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(end - start);
    } finally {
      await raf.close();
    }
  }
}

/// En escritorio y móvil, `file_picker` da una ruta en disco: eso alcanza
/// para leer por partes sin cargar el video.
Future<PickedVideo?> pickVideoFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['mp4', 'm4v'],
  );
  final path = result?.files.single.path;
  return path == null ? null : IoPickedVideo(File(path));
}

/// Fuera del navegador no hay `<video>` escondido para leer un fotograma: la
/// portada, si se quiere, se sube a mano.
Future<VideoProbe?> probeVideo(PickedVideo video) async => null;

/// La parte sale del archivo en un stream: nunca está entera en memoria.
Future<int> sendVideoPart(
  VideoPart part, {
  required void Function(int sentBytes) onProgress,
  required UploadAbort abort,
}) async {
  final video = part.video;
  final client = http.Client();
  final dejar = abort.onAbort(client.close);
  try {
    final request = http.StreamedRequest('PUT', Uri.parse(part.url))
      ..contentLength = part.sizeBytes;
    final origen = video is IoPickedVideo
        ? video.file.openRead(part.start, part.end)
        : Stream.fromFuture(video.readRange(part.start, part.end));
    var enviados = 0;
    unawaited(origen
        .map((trozo) {
          enviados += trozo.length;
          onProgress(enviados);
          return trozo;
        })
        .pipe(request.sink)
        .catchError((Object _) {}));
    final response =
        await client.send(request).timeout(const Duration(minutes: 5));
    await response.stream.drain<void>();
    return response.statusCode;
  } on TimeoutException {
    throw const PartUploadError(
        'La conexión dejó de responder mientras subía el video.');
  } on http.ClientException {
    if (abort.aborted) throw const UploadCancelled();
    throw const PartUploadError('Se cortó la conexión mientras subía el video.');
  } finally {
    dejar();
    client.close();
  }
}

class _NadaQueEscuchar implements VideoDropListener {
  @override
  void dispose() {}
}

/// Soltar archivos sobre la ventana es cosa del navegador.
VideoDropListener listenForVideoDrops({
  required void Function(bool dragging) onDragging,
  required void Function(PickedVideo video) onDrop,
}) =>
    _NadaQueEscuchar();
