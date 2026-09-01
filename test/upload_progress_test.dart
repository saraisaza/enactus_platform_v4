import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/services/upload_io.dart';

/// La barra de subida tiene que MOVERSE, no saltar de 0 a 1.
///
/// Antes `uploadToSignedUrl` emitía exactamente dos valores porque
/// `package:http` no expone el avance de envío. Con un video de 500 MB —el
/// tope que acepta la API— eso son varios minutos de barra congelada en 0,
/// que es indistinguible de una subida colgada.
///
/// Se prueba contra un servidor de verdad levantado acá, no contra un puerto
/// cerrado: con el socket muriendo al primer trozo la emisión se corta y la
/// prueba mediría el fallo, no el progreso.
///
/// Se prueba la mitad `upload_io`, que es la que corre en `flutter test`. La
/// mitad web usa `XMLHttpRequest.upload.onprogress` y solo existe en el
/// navegador: ahí `flutter analyze` cubre que la firma sea la misma y
/// `flutter build web` que compile.
void main() {
  late HttpServer servidor;
  late Uri destino;
  late List<int> recibido;

  setUp(() async {
    recibido = [];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    destino = Uri.parse('http://127.0.0.1:${servidor.port}/subida');
    servidor.listen((request) async {
      await for (final trozo in request) {
        recibido.addAll(trozo);
      }
      request.response.statusCode = 200;
      await request.response.close();
    });
  });

  tearDown(() => servidor.close(force: true));

  test('el progreso avanza por trozos, no en dos saltos', () async {
    // 300 KB con trozos de 64 KB → cinco trozos, más el 0 inicial y el 1 final.
    final bytes = Uint8List(300 * 1024);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = i % 256;
    }
    final avances = <double>[];

    final status = await putWithProgress(
      url: destino,
      bytes: bytes,
      contentType: 'video/mp4',
      timeout: const Duration(seconds: 20),
      onProgress: avances.add,
    );

    expect(status, 200);
    expect(recibido.length, bytes.length,
        reason: 'El servidor tiene que recibir el archivo entero.');
    expect(recibido, equals(bytes), reason: 'Los bytes llegaron alterados.');

    expect(avances.first, 0, reason: 'Tiene que arrancar en 0.');
    expect(avances.last, 1, reason: 'Tiene que terminar en 1.');
    expect(avances.length, greaterThan(4),
        reason: 'Con 300 KB en trozos de 64 KB deberían llegar varios avisos '
            'intermedios; llegaron ${avances.length}: $avances');

    // Monótono y dentro de rango: una barra que retrocede o se pasa de 1 se ve
    // rota aunque el archivo suba bien.
    for (var i = 1; i < avances.length; i++) {
      expect(avances[i], greaterThanOrEqualTo(avances[i - 1]),
          reason: 'El progreso retrocedió: $avances');
    }
    for (final v in avances) {
      expect(v, inInclusiveRange(0, 1));
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('el 100% se emite al terminar, no antes', () async {
    // El aviso de progreso llega cuando los bytes SALIERON, no cuando el otro
    // lado los confirmó. Anunciar el 100% antes de la respuesta es mentir un
    // poco: la subida todavía puede fallar.
    final avances = <double>[];
    await putWithProgress(
      url: destino,
      bytes: Uint8List(128 * 1024),
      contentType: 'video/mp4',
      timeout: const Duration(seconds: 20),
      onProgress: avances.add,
    );
    expect(avances.where((v) => v == 1).length, 1,
        reason: 'El 1 tiene que emitirse una sola vez, al final: $avances');
    expect(avances.last, 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un archivo vacío no divide por cero', () async {
    final avances = <double>[];
    final status = await putWithProgress(
      url: destino,
      bytes: const [],
      contentType: 'video/mp4',
      timeout: const Duration(seconds: 20),
      onProgress: avances.add,
    );
    expect(status, 200);
    expect(avances, isNotEmpty);
    for (final v in avances) {
      expect(v.isNaN, isFalse, reason: 'Progreso NaN con 0 bytes: $avances');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un servidor que rechaza devuelve su código, no una excepción', () async {
    // S3 responde 403 si la firma venció. Eso tiene que llegar como código
    // para que `ApiService` lo convierta en un error con mensaje, no como un
    // fallo de transporte.
    final rechaza = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => rechaza.close(force: true));
    rechaza.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 403;
      await request.response.close();
    });

    final status = await putWithProgress(
      url: Uri.parse('http://127.0.0.1:${rechaza.port}/x'),
      bytes: Uint8List(1024),
      contentType: 'video/mp4',
      timeout: const Duration(seconds: 20),
    );
    expect(status, 403);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
