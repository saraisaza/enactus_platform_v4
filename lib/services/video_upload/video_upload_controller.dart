import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/textos.dart';
import '../api_service.dart';
import 'mp4_inspector.dart';
import 'picked_video.dart';
import 'upload_resume_store.dart';
import 'upload_types.dart';
import 'video_platform.dart' as platform;
import 'video_uploader.dart';

/// Lo que se elige en el editor de lección: subir un archivo, o pegar un
/// enlace de YouTube. Son dos opciones separadas.
enum VideoSourceMode { youtube, upload }

/// El estado del video que se va a subir, del momento de elegirlo al de
/// terminar de subirlo. Lo maneja el editor de lección; el panel solo lo
/// muestra.
class VideoUploadController extends ChangeNotifier {
  VideoUploadController({
    Future<PickedVideo?> Function()? picker,
    Future<VideoProbe?> Function(PickedVideo video)? prober,
    Future<Mp4Check> Function(PickedVideo video)? checker,
    this.sender,
    this.coverSender,
    this.store = const UploadResumeStore(),
  })  : _picker = picker ?? platform.pickVideoFile,
        _prober = prober ?? platform.probeVideo,
        _checker = checker ?? checkUploadableVideo;

  /// Solo para pruebas: cómo crea el editor de lección su controlador.
  @visibleForTesting
  static VideoUploadController Function()? debugCreate;

  /// El que usa el editor: el de verdad, salvo en las pruebas.
  factory VideoUploadController.forEditor() =>
      debugCreate?.call() ?? VideoUploadController();

  final Future<PickedVideo?> Function() _picker;
  final Future<VideoProbe?> Function(PickedVideo video) _prober;
  final Future<Mp4Check> Function(PickedVideo video) _checker;
  final PartSender? sender;
  final CoverSender? coverSender;
  final UploadResumeStore store;

  PickedVideo? file;
  bool checking = false;

  /// Por qué el archivo elegido no sirve, en palabras de quien lo eligió.
  String? problem;
  VideoProbe? probe;

  Uint8List? customCover;
  String customCoverType = 'image/jpeg';
  String? coverProblem;

  /// Una subida que quedó a medias en esta lección (otra pestaña, un corte).
  PendingUpload? pending;

  bool uploading = false;
  UploadProgress? progress;
  Object? uploadError;
  VideoUploader? _uploader;
  int _eleccion = 0;
  bool _disposed = false;

  bool get ready => file != null && !checking && problem == null;

  /// La portada que se va a subir: la propia, o el fotograma del video.
  Uint8List? get cover => customCover ?? probe?.frameJpeg;
  String get coverType => customCover != null ? customCoverType : 'image/jpeg';

  Future<void> loadPending(String? lessonId) async {
    if (lessonId == null) return;
    pending = await store.find(lessonId);
    _avisar();
  }

  Future<void> pick() async {
    if (uploading) return;
    final elegido = await _picker();
    if (elegido != null) await accept(elegido);
  }

  /// Revisa el archivo antes de aceptarlo: formato y tamaño primero (unos
  /// KB), y después que el navegador lo pueda abrir — lo que además da la
  /// duración y el fotograma de la portada.
  Future<void> accept(PickedVideo elegido) async {
    if (uploading) return;
    final eleccion = ++_eleccion;
    _soltarArchivo();
    file = elegido;
    checking = true;
    _avisar();

    final revision = await _checker(elegido);
    if (eleccion != _eleccion) return;
    if (!revision.ok) {
      problem = revision.problem;
      checking = false;
      _avisar();
      return;
    }

    final muestra = await _prober(elegido);
    if (eleccion != _eleccion) return;
    if (muestra == null && elegido.previewUrl != null) {
      problem = tr.videoNavegadorNoAbre;
    }
    probe = muestra;
    checking = false;
    _avisar();
  }

  /// Quita el archivo elegido (no toca el video que ya tenga la lección).
  void clearFile() {
    if (uploading) return;
    _eleccion++;
    _soltarArchivo();
    _avisar();
  }

  void _soltarArchivo() {
    file?.dispose();
    file = null;
    probe = null;
    problem = null;
    checking = false;
    uploadError = null;
    progress = null;
  }

  /// Una portada propia: JPG, PNG o WebP de hasta 5 MB (es una imagen, se
  /// puede leer entera).
  Future<void> pickCover() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final elegido = result?.files.single;
    final bytes = elegido?.bytes;
    if (elegido == null || bytes == null) return;
    final ext = elegido.extension?.toLowerCase() ?? '';
    if (bytes.length > 5 * 1024 * 1024) {
      coverProblem = tr.videoPortadaPesada(formatMegabytes(bytes.length));
    } else {
      coverProblem = null;
      customCover = bytes;
      customCoverType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
    }
    _avisar();
  }

  void removeCustomCover() {
    customCover = null;
    coverProblem = null;
    _avisar();
  }

  /// Sube el archivo elegido a la lección y devuelve la lección como quedó.
  Future<Map<String, dynamic>> upload({
    required ApiService api,
    required String lessonId,
  }) async {
    final video = file;
    if (video == null) throw StateError('No hay video elegido.');
    uploading = true;
    uploadError = null;
    progress = null;
    _avisar();

    final uploader = VideoUploader(
      api: api,
      lessonId: lessonId,
      video: video,
      sender: sender,
      coverSender: coverSender,
      store: store,
    );
    _uploader = uploader;
    try {
      final segundos = probe?.duration.inSeconds;
      final leccion = await uploader.run(
        onProgress: (p) {
          progress = p;
          _avisar();
        },
        cover: cover,
        coverContentType: coverType,
        durationSec: segundos == null || segundos <= 0 ? null : segundos,
      );
      pending = null;
      return leccion;
    } catch (e) {
      uploadError = e;
      rethrow;
    } finally {
      uploading = false;
      _uploader = null;
      _avisar();
    }
  }

  Future<void> cancelUpload() async {
    await _uploader?.cancel();
  }

  /// Cambia solo la portada de un video que ya está subido.
  Future<void> saveCoverOnly({
    required ApiService api,
    required String lessonId,
  }) async {
    final bytes = customCover;
    if (bytes == null) return;
    final json = Map<String, dynamic>.from(await api.post(
      '/lessons/$lessonId/video-thumbnail-upload-url',
      body: {'contentType': customCoverType, 'sizeBytes': bytes.length},
    ) as Map);
    final url = json['uploadUrl'] as String;
    final enviar = coverSender;
    if (enviar != null) {
      await enviar(url, bytes, customCoverType);
    } else {
      await api.uploadToSignedUrl(
          uploadUrl: url, bytes: bytes, contentType: customCoverType);
    }
    await api.put('/lessons/$lessonId/video-thumbnail',
        body: {'key': json['key']});
  }

  void _avisar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    file?.dispose();
    super.dispose();
  }
}
