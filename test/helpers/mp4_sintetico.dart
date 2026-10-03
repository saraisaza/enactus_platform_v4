import 'dart:convert';
import 'dart:typed_data';

/// MP4 sintéticos, armados caja por caja como los escribe un exportador.
///
/// No hace falta un video de verdad: el inspector solo mira la estructura
/// (`ftyp`, `moov` › `trak` › `mdia` › `hdlr` / `stsd`), y armarla a mano
/// deja probar cada caso raro sin guardar binarios en el repositorio.
List<int> u32(int v) => [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];

List<int> box(String type, List<int> payload) =>
    [...u32(8 + payload.length), ...ascii.encode(type), ...payload];

List<int> hdlr(String handler) => box('hdlr', [
      0, 0, 0, 0, // versión y banderas
      0, 0, 0, 0, // pre_defined
      ...ascii.encode(handler),
      ...List.filled(12, 0),
      0,
    ]);

List<int> stsd(List<int> entrada) => box('stsd', [0, 0, 0, 0, ...u32(1), ...entrada]);

/// Entrada de video: cabecera de 16 bytes y 70 de campos visuales.
List<int> entradaVideo(String formato) =>
    box(formato, [...List.filled(6, 0), 0, 1, ...List.filled(70, 0)]);

/// Entrada `mp4a` con su `esds`, que dice qué audio es (0x40 = AAC).
List<int> entradaMp4a({int oti = 0x40}) {
  final decoderConfig = [0x04, 13, oti, 0x15, ...List.filled(11, 0)];
  final esDescriptor = [0x03, 3 + decoderConfig.length, 0, 1, 0, ...decoderConfig];
  final esds = box('esds', [0, 0, 0, 0, ...esDescriptor]);
  return box('mp4a', [
    ...List.filled(6, 0), 0, 1, // reservado + data_reference_index
    ...List.filled(20, 0), // descripción de sonido, versión 0
    ...esds,
  ]);
}

List<int> entradaAudio(String formato) =>
    box(formato, [...List.filled(6, 0), 0, 1, ...List.filled(20, 0)]);

List<int> trak(String handler, List<int> entrada) => box('trak', [
      ...box('tkhd', List.filled(84, 0)),
      ...box('mdia', [
        ...box('mdhd', List.filled(24, 0)),
        ...hdlr(handler),
        ...box('minf', box('stbl', stsd(entrada))),
      ]),
    ]);

List<int> moov(List<List<int>> traks) =>
    box('moov', [...box('mvhd', List.filled(100, 0)), for (final t in traks) ...t]);

final ftyp = box('ftyp', ascii.encode('isom\x00\x00\x02\x00isomiso2avc1mp41'));

List<int> mdat(int bytes) => box('mdat', List.filled(bytes, 7));

Uint8List mp4({
  String video = 'avc1',
  List<int>? audio,
  bool indiceAlFinal = false,
  int datos = 4096,
}) {
  final pistas = [
    trak('vide', entradaVideo(video)),
    if (audio != null) trak('soun', audio),
  ];
  final indice = moov(pistas);
  return Uint8List.fromList(indiceAlFinal
      ? [...ftyp, ...mdat(datos), ...indice]
      : [...ftyp, ...indice, ...mdat(datos)]);
}

