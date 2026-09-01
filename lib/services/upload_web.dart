import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Subida a S3 **en el navegador**, con progreso real por bytes.
///
/// `package:http` no expone el avance de una subida: su `BrowserClient` usa
/// `fetch`, y `fetch` no informa progreso de envío en ningún navegador. Por eso
/// acá se baja a `XMLHttpRequest`, que sí tiene `upload.onprogress` — es la
/// única forma de que la barra se mueva de verdad y no en dos saltos.
///
/// Devuelve el código HTTP. No interpreta la respuesta: eso lo hace
/// `ApiService`, que es quien conoce los errores de la aplicación.
Future<int> putWithProgress({
  required Uri url,
  required List<int> bytes,
  required String contentType,
  required Duration timeout,
  void Function(double progress)? onProgress,
}) {
  final completer = Completer<int>();
  final xhr = web.XMLHttpRequest();

  xhr.open('PUT', url.toString());
  xhr.setRequestHeader('Content-Type', contentType);
  xhr.timeout = timeout.inMilliseconds;

  xhr.upload.addEventListener(
    'progress',
    (web.ProgressEvent event) {
      // `lengthComputable` es falso si el navegador no sabe el total. Se
      // informa igual el avance conocido contra el tamaño que ya tenemos en
      // memoria, que es exacto: los bytes salen de un archivo ya leído.
      final total = event.lengthComputable && event.total > 0
          ? event.total
          : bytes.length;
      if (total > 0) {
        onProgress?.call((event.loaded / total).clamp(0.0, 1.0));
      }
    }.toJS,
  );

  void terminar(int status) {
    if (!completer.isCompleted) completer.complete(status);
  }

  void fallar(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  xhr.addEventListener(
    'load',
    (web.Event _) {
      // El 100% se emite al terminar y no en el último `progress`: el evento
      // de progreso llega cuando los bytes SALIERON, no cuando S3 los
      // confirmó. Mostrar 100% antes de la confirmación es mentir un poco.
      onProgress?.call(1);
      terminar(xhr.status);
    }.toJS,
  );

  xhr.addEventListener(
    'error',
    ((web.Event _) {
      fallar(const UploadTransportException(
          'No se pudo subir el archivo: la conexión se interrumpió.'));
    }).toJS,
  );

  xhr.addEventListener(
    'abort',
    ((web.Event _) {
      fallar(const UploadTransportException('La subida se canceló.'));
    }).toJS,
  );

  xhr.addEventListener(
    'timeout',
    ((web.Event _) {
      fallar(const UploadTimeoutException());
    }).toJS,
  );

  onProgress?.call(0);
  xhr.send(Uint8List.fromList(bytes).toJS);
  return completer.future;
}

/// La conexión se cortó durante la subida.
class UploadTransportException implements Exception {
  final String message;
  const UploadTransportException(this.message);
  @override
  String toString() => message;
}

/// La subida superó el tiempo máximo.
class UploadTimeoutException implements Exception {
  const UploadTimeoutException();
  @override
  String toString() => 'La subida tardó demasiado.';
}
