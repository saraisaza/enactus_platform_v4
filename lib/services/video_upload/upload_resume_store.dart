import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una subida que quedó a medias, para retomarla.
class PendingUpload {
  const PendingUpload({
    required this.lessonId,
    required this.key,
    required this.uploadId,
    required this.fingerprint,
    required this.fileName,
    required this.sizeBytes,
    required this.partSizeBytes,
    required this.partCount,
    required this.startedAt,
  });

  final String lessonId;
  final String key;
  final String uploadId;

  /// Nombre, tamaño y fecha del archivo: retomar con OTRO archivo mezclaría
  /// partes de dos videos.
  final String fingerprint;
  final String fileName;
  final int sizeBytes;
  final int partSizeBytes;
  final int partCount;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'key': key,
        'uploadId': uploadId,
        'fingerprint': fingerprint,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'partSizeBytes': partSizeBytes,
        'partCount': partCount,
        'startedAt': startedAt.toIso8601String(),
      };

  static PendingUpload? fromJson(Map<String, dynamic> j) {
    try {
      return PendingUpload(
        lessonId: j['lessonId'] as String,
        key: j['key'] as String,
        uploadId: j['uploadId'] as String,
        fingerprint: j['fingerprint'] as String,
        fileName: j['fileName'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        partSizeBytes: (j['partSizeBytes'] as num).toInt(),
        partCount: (j['partCount'] as num).toInt(),
        startedAt: DateTime.parse(j['startedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Dónde se anota la subida en curso de cada lección.
///
/// Si la pestaña se cierra o se corta la luz a mitad de un video de 400 MB,
/// las partes que ya llegaron siguen en S3. Con lo anotado acá, al volver a
/// elegir el MISMO archivo se pregunta qué partes hay y se sigue desde ahí.
///
/// Vive en el navegador de quien sube (`shared_preferences`): es una
/// comodidad de esa persona en ese equipo, no un dato de la plataforma. Si se
/// pierde, la subida empieza de cero y nada se rompe.
class UploadResumeStore {
  const UploadResumeStore();

  static const _prefijo = 'enactus.subidaDeVideo.';

  /// S3 descarta las subidas sin terminar al día (regla de ciclo de vida del
  /// bucket); anotarlas más tiempo sería prometer algo que ya no existe.
  static const vigencia = Duration(hours: 23);

  Future<PendingUpload?> find(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefijo$lessonId');
      if (raw == null) return null;
      final pending =
          PendingUpload.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (pending == null ||
          DateTime.now().difference(pending.startedAt) > vigencia) {
        await prefs.remove('$_prefijo$lessonId');
        return null;
      }
      return pending;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PendingUpload pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_prefijo${pending.lessonId}', jsonEncode(pending.toJson()));
    } catch (_) {
      // Sin almacenamiento local se sube igual; solo no se podrá retomar.
    }
  }

  Future<void> clear(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefijo$lessonId');
    } catch (_) {}
  }
}
