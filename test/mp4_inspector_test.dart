import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/services/video_upload/mp4_inspector.dart';
import 'package:enactus_platform/services/video_upload/picked_video.dart';

import 'helpers/mp4_sintetico.dart';

/// Cuenta cuánto se leyó: el inspector no puede leerse el video entero.
class _Contado extends MemoryPickedVideo {
  _Contado(super.name, super.bytes);
  int leidos = 0;
  @override
  Future<Uint8List> readRange(int start, int end) {
    leidos += end - start;
    return super.readRange(start, end);
  }
}

/// Un archivo enorme que no existe en memoria: solo importa su tamaño.
class _Gigante extends PickedVideo {
  @override
  String get name => 'largo.mp4';
  @override
  int get sizeBytes => 812 * 1024 * 1024;
  @override
  String get mimeType => 'video/mp4';
  @override
  int? get lastModifiedMs => 1;
  @override
  String? get previewUrl => null;
  @override
  Future<Uint8List> readRange(int start, int end) =>
      throw StateError('no debería leer nada');
}

void main() {
  Future<Mp4Check> revisar(Uint8List bytes, {String nombre = 'clase.mp4'}) =>
      checkUploadableVideo(MemoryPickedVideo(nombre, bytes));

  group('lo que sirve', () {
    test('H.264 con AAC', () async {
      final r = await revisar(mp4(audio: entradaMp4a()));
      expect(r.ok, isTrue, reason: r.problem);
      expect(r.videoCodec, 'avc1');
      expect(r.audioCodec, 'mp4a');
    });

    test('H.264 sin sonido (una grabación de pantalla, por ejemplo)', () async {
      final r = await revisar(mp4());
      expect(r.ok, isTrue, reason: r.problem);
      expect(r.audioCodec, isNull);
    });

    test('con el índice al final, sin leer el video entero', () async {
      final video = _Contado('clase.mp4',
          mp4(audio: entradaMp4a(), indiceAlFinal: true, datos: 5 * 1024 * 1024));
      final r = await checkUploadableVideo(video);
      expect(r.ok, isTrue, reason: r.problem);
      // Cabeceras y el índice: unos cientos de bytes de 5 MB.
      expect(video.leidos, lessThan(4096));
    });

    test('una caja de datos con tamaño de 64 bits', () async {
      final indice = moov([trak('vide', entradaVideo('avc1'))]);
      final datos = List.filled(1000, 1);
      final grande = [
        ...u32(1), ...ascii.encode('mdat'),
        ...u32(0), ...u32(16 + datos.length), // largesize
        ...datos,
      ];
      final r = await revisar(Uint8List.fromList([...ftyp, ...grande, ...indice]));
      expect(r.ok, isTrue, reason: r.problem);
    });

    test('.m4v también es MP4', () async {
      final r = await revisar(mp4(audio: entradaMp4a()), nombre: 'clase.M4V');
      expect(r.ok, isTrue, reason: r.problem);
    });
  });

  group('lo que no, y diciendo por qué', () {
    test('H.265 del iPhone: dice cómo exportarlo en H.264', () async {
      final r = await revisar(mp4(video: 'hvc1', audio: entradaMp4a()));
      expect(r.ok, isFalse);
      expect(r.problem, contains('H.265 (HEVC)'));
      expect(r.problem, contains('iPhone'));
      expect(r.problem, contains('«Más compatible»'));
    });

    test('AV1, VP9 y ProRes, por su nombre', () async {
      expect((await revisar(mp4(video: 'av01'))).problem, contains('AV1'));
      expect((await revisar(mp4(video: 'vp09'))).problem, contains('VP9'));
      expect((await revisar(mp4(video: 'apch'))).problem, contains('ProRes'));
    });

    test('audio MP3 metido en un MP4', () async {
      final r = await revisar(mp4(audio: entradaMp4a(oti: 0x6B)));
      expect(r.problem, contains('audio de este MP4 está en MP3'));
    });

    test('audio Dolby', () async {
      final r = await revisar(mp4(audio: entradaAudio('ac-3')));
      expect(r.problem, contains('AC-3'));
    });

    test('un video protegido', () async {
      expect((await revisar(mp4(video: 'encv'))).problem, contains('DRM'));
    });

    test('un archivo que se llama .mp4 pero no lo es', () async {
      final r = await revisar(Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3, ...List.filled(64, 0)]));
      expect(r.problem, contains('no es un MP4'));
    });

    test('un MP4 cortado, sin índice', () async {
      final r = await revisar(Uint8List.fromList([...ftyp, ...mdat(2048)]));
      expect(r.problem, contains('le falta el índice'));
    });

    test('solo audio', () async {
      final solo = Uint8List.fromList(
          [...ftyp, ...moov([trak('soun', entradaMp4a())]), ...mdat(100)]);
      expect((await revisar(solo)).problem, contains('solo audio'));
    });

    test('otra extensión, nombrándola', () async {
      final r = await revisar(mp4(audio: entradaMp4a()), nombre: 'clase.mov');
      expect(r.problem, contains('.mov'));
    });

    test('más de 500 MB, sin leer nada del archivo', () async {
      final r = await checkUploadableVideo(_Gigante());
      expect(r.problem, contains('812 MB'));
      expect(r.problem, contains('500 MB'));
    });

    test('vacío', () async {
      expect((await revisar(Uint8List(0))).problem, contains('vacío'));
    });
  });

  test('formatMegabytes habla como una persona', () {
    expect(formatMegabytes(245 * 1024 * 1024), '245 MB');
    expect(formatMegabytes(3 * 1024 * 1024 + 300 * 1024), '3,3 MB');
    expect(formatMegabytes(1288 * 1024 * 1024), '1,3 GB');
  });
}
