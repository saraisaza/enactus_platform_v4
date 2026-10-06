import 'dart:math' as math;
import 'dart:typed_data';

import '../../l10n/textos.dart';
import 'picked_video.dart';

/// Tope de lo que se sube: el mismo que exige la API.
const int maxUploadedVideoBytes = 500 * 1024 * 1024;

/// Qué tiene adentro un MP4, y si sirve para la plataforma.
class Mp4Check {
  const Mp4Check._({this.problem, this.videoCodec, this.audioCodec});

  const Mp4Check.ok({String? videoCodec, String? audioCodec})
      : this._(videoCodec: videoCodec, audioCodec: audioCodec);

  const Mp4Check.problem(String problem,
      {String? videoCodec, String? audioCodec})
      : this._(
            problem: problem, videoCodec: videoCodec, audioCodec: audioCodec);

  /// Qué decirle a quien lo subió, en sus palabras. `null` si sirve.
  final String? problem;

  /// El código del formato de cada pista (`avc1`, `mp4a`…), o `null`.
  final String? videoCodec;
  final String? audioCodec;

  bool get ok => problem == null;
}

/// Revisa nombre, tamaño y formato ANTES de subir un solo byte.
///
/// La extensión no alcanza: un `.mp4` grabado con un iPhone moderno viene en
/// H.265 (HEVC), que Chrome en Windows y Firefox no reproducen, y el video
/// quedaría subido e invisible para buena parte de los estudiantes. Así que
/// se lee la descripción de cada pista dentro del archivo (la caja `stsd` del
/// índice `moov`) y se exige lo que reproduce cualquier navegador: video
/// H.264 y, si tiene sonido, audio AAC.
///
/// Lee solo la cabecera de cada caja y el índice: unos KB, aunque el video
/// pese 500 MB, y aunque el índice esté al final del archivo (pasa con lo que
/// exportan muchas cámaras).
Future<Mp4Check> checkUploadableVideo(PickedVideo video) async {
  final ext = video.extension;
  if (ext != 'mp4' && ext != 'm4v') {
    return Mp4Check.problem(
      ext.isEmpty
          ? tr.mp4SoloMp4
          : tr.mp4SoloMp4Ext(ext),
    );
  }
  if (video.sizeBytes <= 0) {
    return Mp4Check.problem(tr.mp4Vacio);
  }
  if (video.sizeBytes > maxUploadedVideoBytes) {
    return Mp4Check.problem(
      tr.mp4Pesado(formatMegabytes(video.sizeBytes)),
    );
  }
  try {
    return await inspectMp4(video);
  } catch (_) {
    return Mp4Check.problem(_danado);
  }
}

String get _danado => tr.mp4Danado;

String get _noEsMp4 => tr.mp4NoEsMp4;

/// El índice de un video de horas pesa unos pocos MB; más que esto no es un
/// índice razonable y no se carga en memoria.
const _maxMoovBytes = 64 * 1024 * 1024;

/// Lee el formato de las pistas. Ver [checkUploadableVideo].
Future<Mp4Check> inspectMp4(PickedVideo video) async {
  final size = video.sizeBytes;
  var offset = 0;
  var vueltas = 0;
  int? moovStart;
  int? moovEnd;

  while (offset + 8 <= size && vueltas++ < 10000) {
    final h = await video.readRange(offset, math.min(offset + 16, size));
    if (h.length < 8) break;
    var boxSize = _u32(h, 0);
    final type = _fourcc(h, 4);
    var header = 8;
    if (boxSize == 1) {
      if (h.length < 16) return Mp4Check.problem(_danado);
      boxSize = _u64(h, 8);
      header = 16;
    } else if (boxSize == 0) {
      boxSize = size - offset;
    }
    if (offset == 0 && type != 'ftyp') {
      return Mp4Check.problem(_noEsMp4);
    }
    if (boxSize < header) return Mp4Check.problem(_danado);
    if (type == 'moov') {
      moovStart = offset;
      moovEnd = offset + boxSize;
      break;
    }
    offset += boxSize;
  }

  if (moovStart == null || moovEnd == null || moovEnd > size) {
    return Mp4Check.problem(
        tr.mp4SinIndice);
  }
  if (moovEnd - moovStart > _maxMoovBytes) {
    return Mp4Check.problem(_danado);
  }

  final moov = await video.readRange(moovStart, moovEnd);
  final pistas = <(String, String, int?)>[]; // (manejador, formato, oti)
  for (final trak in _children(moov, _headerSize(moov, 0), moov.length)) {
    if (trak.type != 'trak') continue;
    final pista = _describirPista(moov, trak);
    if (pista != null) pistas.add(pista);
  }

  final video0 = pistas.where((p) => p.$1 == 'vide').map((p) => p.$2);
  final audio0 = pistas.where((p) => p.$1 == 'soun');
  final videoCodec = video0.isEmpty ? null : video0.first;
  final audio = audio0.isEmpty ? null : audio0.first;
  final audioCodec = audio?.$2;

  if (videoCodec == null) {
    return Mp4Check.problem(
        tr.mp4SoloAudio);
  }
  if (videoCodec == 'encv' || audioCodec == 'enca') {
    return Mp4Check.problem(
        tr.mp4Drm,
        videoCodec: videoCodec,
        audioCodec: audioCodec);
  }
  if (videoCodec != 'avc1' && videoCodec != 'avc3') {
    return Mp4Check.problem(_mensajeVideo(videoCodec),
        videoCodec: videoCodec, audioCodec: audioCodec);
  }
  if (audio != null) {
    final problema = _mensajeAudio(audio.$2, audio.$3);
    if (problema != null) {
      return Mp4Check.problem(problema,
          videoCodec: videoCodec, audioCodec: audioCodec);
    }
  }
  return Mp4Check.ok(videoCodec: videoCodec, audioCodec: audioCodec);
}

String _mensajeVideo(String codec) {
  if (codec == 'hvc1' || codec == 'hev1') {
    return tr.mp4Hevc;
  }
  final nombre = switch (codec) {
    'av01' => 'AV1',
    'vp09' || 'vp08' => 'VP9',
    'mp4v' => tr.mp4Mpeg4Parte2,
    'apch' || 'apcn' || 'apcs' || 'apco' || 'ap4h' || 'ap4x' => 'ProRes',
    _ => codec,
  };
  return tr.mp4FormatoVideo(nombre);
}

String? _mensajeAudio(String codec, int? oti) {
  if (codec == 'mp4a') {
    // 0x69 y 0x6B son MP3 metido en MP4. Sin OTI legible se acepta: la vista
    // previa del navegador es la segunda red.
    if (oti == 0x69 || oti == 0x6B) return _audio('MP3');
    return null;
  }
  final nombre = switch (codec) {
    'ac-3' => 'AC-3 (Dolby)',
    'ec-3' => 'E-AC-3 (Dolby)',
    'Opus' => 'Opus',
    '.mp3' => 'MP3',
    'lpcm' || 'sowt' || 'twos' || 'ipcm' => tr.mp4PcmSinComprimir,
    _ => codec,
  };
  return _audio(nombre);
}

String _audio(String nombre) =>
    tr.mp4FormatoAudio(nombre);

class _Box {
  _Box(this.type, this.start, this.payload, this.end);
  final String type;
  final int start;
  final int payload;
  final int end;
}

int _headerSize(Uint8List d, int at) => _u32(d, at) == 1 ? 16 : 8;

Iterable<_Box> _children(Uint8List d, int from, int to) sync* {
  var at = from;
  while (at + 8 <= to) {
    var size = _u32(d, at);
    final type = _fourcc(d, at + 4);
    var header = 8;
    if (size == 1) {
      if (at + 16 > to) return;
      size = _u64(d, at + 8);
      header = 16;
    } else if (size == 0) {
      size = to - at;
    }
    if (size < header || at + size > to) return;
    yield _Box(type, at, at + header, at + size);
    at += size;
  }
}

_Box? _child(Uint8List d, _Box parent, String type) {
  for (final b in _children(d, parent.payload, parent.end)) {
    if (b.type == type) return b;
  }
  return null;
}

/// (manejador `vide`/`soun`, formato de la primera muestra, OTI del audio).
(String, String, int?)? _describirPista(Uint8List d, _Box trak) {
  final mdia = _child(d, trak, 'mdia');
  if (mdia == null) return null;
  final hdlr = _child(d, mdia, 'hdlr');
  if (hdlr == null || hdlr.payload + 12 > hdlr.end) return null;
  final manejador = _fourcc(d, hdlr.payload + 8);
  final minf = _child(d, mdia, 'minf');
  final stbl = minf == null ? null : _child(d, minf, 'stbl');
  final stsd = stbl == null ? null : _child(d, stbl, 'stsd');
  if (stsd == null || stsd.payload + 16 > stsd.end) return null;
  final entrada = stsd.payload + 8;
  final formato = _fourcc(d, entrada + 4);
  int? oti;
  if (formato == 'mp4a') oti = _otiDeMp4a(d, entrada, entrada + _u32(d, entrada));
  return (manejador, formato, oti);
}

/// El `objectTypeIndication` del `esds` de una entrada `mp4a`, o `null`.
int? _otiDeMp4a(Uint8List d, int entrada, int fin) {
  if (fin > d.length || entrada + 36 > fin) return null;
  // Entrada de muestra (16) + descripción de sonido (20) en la versión 0; la
  // versión 1 de QuickTime suma 16 bytes y la 2, 36.
  final version = _u16(d, entrada + 16);
  final hijos = entrada + 36 + (version == 1 ? 16 : version == 2 ? 36 : 0);
  for (final b in _children(d, hijos, fin)) {
    if (b.type != 'esds') continue;
    var at = b.payload + 4; // versión y banderas
    int? leerTag(int esperado) {
      if (at >= b.end || d[at] != esperado) return null;
      at++;
      var largo = 0;
      for (var i = 0; i < 4 && at < b.end; i++) {
        final byte = d[at++];
        largo = (largo << 7) | (byte & 0x7f);
        if (byte & 0x80 == 0) break;
      }
      return largo;
    }

    if (leerTag(0x03) == null) return null;
    if (at + 3 > b.end) return null;
    final banderas = d[at + 2];
    at += 3;
    if (banderas & 0x80 != 0) at += 2;
    if (banderas & 0x40 != 0 && at < b.end) at += 1 + d[at];
    if (banderas & 0x20 != 0) at += 2;
    if (leerTag(0x04) == null || at >= b.end) return null;
    return d[at];
  }
  return null;
}

int _u16(Uint8List d, int at) => (d[at] << 8) | d[at + 1];

int _u32(Uint8List d, int at) =>
    (d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8) | d[at + 3];

int _u64(Uint8List d, int at) => _u32(d, at) * 0x100000000 + _u32(d, at + 4);

String _fourcc(Uint8List d, int at) =>
    String.fromCharCodes(d.sublist(at, at + 4));

/// `245 MB`, `1,2 GB`: como lo diría una persona.
String formatMegabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) {
    return '${(mb / 1024).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  return mb >= 10
      ? '${mb.round()} MB'
      : '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}
