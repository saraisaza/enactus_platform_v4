import 'dart:async';

import 'package:http/http.dart' as http;

/// Subida a S3 **fuera del navegador**, con progreso real por bytes.
///
/// Acá sí se puede usar `package:http`: `StreamedRequest` deja emitir el
/// cuerpo por trozos, y contar lo que ya se emitió es el progreso. En el
/// navegador no alcanza —`fetch` no informa avance de envío— y por eso existe
/// la mitad `upload_web.dart`.
///
/// Devuelve el código HTTP. No interpreta la respuesta: eso lo hace
/// `ApiService`, que es quien conoce los errores de la aplicación.
Future<int> putWithProgress({
  required Uri url,
  required List<int> bytes,
  required String contentType,
  required Duration timeout,
  void Function(double progress)? onProgress,
}) async {
  // 64 KB: bastante grande para no hacer miles de vueltas con un video de
  // 500 MB, bastante chico para que la barra se mueva de forma continua.
  const trozo = 64 * 1024;

  final client = http.Client();
  try {
    final request = http.StreamedRequest('PUT', url)
      ..headers['Content-Type'] = contentType
      ..contentLength = bytes.length;

    onProgress?.call(0);

    unawaited(() async {
      var enviados = 0;
      for (var i = 0; i < bytes.length; i += trozo) {
        final fin = (i + trozo < bytes.length) ? i + trozo : bytes.length;
        request.sink.add(bytes.sublist(i, fin));
        enviados = fin;
        // El último trozo NO reporta 1: el 1 se emite recién con la respuesta,
        // porque el progreso dice que los bytes salieron, no que el otro lado
        // los aceptó — la subida todavía puede fallar con la firma vencida.
        // La mitad web hace exactamente lo mismo desde el evento `load`.
        if (enviados < bytes.length) {
          onProgress?.call(enviados / bytes.length);
        }
        // Se cede el turno para que el socket drene y la interfaz repinte;
        // sin esto la barra saltaría de 0 a 1 igual que antes.
        await Future<void>.delayed(Duration.zero);
      }
      await request.sink.close();
    }());

    final response = await client.send(request).timeout(timeout);
    await response.stream.drain<void>();
    onProgress?.call(1);
    return response.statusCode;
  } on TimeoutException {
    throw const UploadTimeoutException();
  } on http.ClientException catch (e) {
    throw UploadTransportException('No se pudo subir el archivo: ${e.message}');
  } finally {
    client.close();
  }
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
