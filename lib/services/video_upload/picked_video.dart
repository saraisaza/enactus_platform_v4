import 'dart:math' as math;
import 'dart:typed_data';

/// Un video elegido para subir, **sin leerlo entero**.
///
/// Un video de 500 MB leído en memoria tumba la pestaña en más de un
/// teléfono, y no hace falta: para revisar el formato alcanza con leer unos
/// KB de la cabecera ([readRange]), y cada parte de la subida sale directo del
/// archivo. En el navegador es un `File` (que es un `Blob`: cortarlo no copia
/// nada); en escritorio y móvil, una ruta en disco.
abstract class PickedVideo {
  String get name;
  int get sizeBytes;

  /// El tipo que informó el sistema, o `''` si no lo sabe.
  String get mimeType;

  /// Fecha de modificación, para reconocer el MISMO archivo al retomar.
  int? get lastModifiedMs;

  /// URL local para la vista previa (`blob:` en el navegador), o `null` si la
  /// plataforma no la tiene.
  String? get previewUrl;

  /// Los bytes de `[start, end)`.
  Future<Uint8List> readRange(int start, int end);

  /// Suelta lo que haya tomado (la URL `blob:`).
  void dispose() {}

  /// Mismo nombre, mismo tamaño y misma fecha: es el mismo archivo.
  String get fingerprint => '$name|$sizeBytes|${lastModifiedMs ?? 0}';

  /// La extensión en minúsculas, sin el punto.
  String get extension {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }
}

/// Un video en memoria. Para las pruebas: la app nunca carga uno entero.
class MemoryPickedVideo extends PickedVideo {
  MemoryPickedVideo(
    this.name,
    this.bytes, {
    this.mimeType = 'video/mp4',
    this.lastModifiedMs = 1,
    this.previewUrl,
  });

  @override
  final String name;
  final Uint8List bytes;
  @override
  final String mimeType;
  @override
  final int? lastModifiedMs;
  @override
  final String? previewUrl;

  @override
  int get sizeBytes => bytes.length;

  @override
  Future<Uint8List> readRange(int start, int end) async =>
      Uint8List.sublistView(bytes, start, math.min(end, bytes.length));
}
