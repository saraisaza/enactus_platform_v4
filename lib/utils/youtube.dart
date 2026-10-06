/// Enlaces de video: de lo que pega el LXD a lo que se guarda.
///
/// De un enlace de YouTube se guarda **solo el id** (11 caracteres). Todo lo
/// demás que trae el enlace —`&t=` de donde lo pausó quien lo compartió,
/// `?si=` de rastreo, la lista de la que salió— no le sirve al reproductor y
/// no tiene por qué quedar en la base. El servidor exige el mismo formato
/// (API y CHECK), así que esto es la primera de tres barreras, no la única.
library;

import '../l10n/textos.dart';

/// Los 11 caracteres de un id de YouTube. Misma expresión que el CHECK
/// `lessons_video_youtube_id_format` del backend.
final RegExp youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

const _youtubeHosts = {
  'youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
};

/// Prefijos de ruta que traen el id como segundo segmento.
const _idPathPrefixes = {'embed', 'shorts', 'live', 'v', 'e'};

/// El id del video de un enlace de YouTube, o `null` si no lo es.
///
/// Acepta las formas que la gente realmente pega: `watch?v=`, `youtu.be/`,
/// `shorts/`, `embed/`, `live/`, con o sin `https://`, con `www.` o `m.`, y
/// con parámetros de más. También el id solo.
///
/// Es estricta con el id: 11 caracteres exactos. Un id recortado o con algo
/// pegado no se "arregla" — se rechaza, porque guardaría un video equivocado
/// sin que nadie se entere hasta que una estudiante lo abra.
String? youtubeVideoIdFrom(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (youtubeIdPattern.hasMatch(text)) return text;

  final uri = _parseLink(text);
  if (uri == null) return null;

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? candidate;
  if (host == 'youtu.be') {
    candidate = segments.isEmpty ? null : segments.first;
  } else if (_youtubeHosts.contains(host)) {
    if (segments.isNotEmpty && segments.first == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        _idPathPrefixes.contains(segments.first)) {
      candidate = segments[1];
    }
  }

  return candidate != null && youtubeIdPattern.hasMatch(candidate)
      ? candidate
      : null;
}

/// ¿El enlace es de YouTube, aunque no sea de un video? Sirve para decir
/// «eso es un canal o una lista» en vez de un genérico «no es válido».
bool isYoutubeLink(String raw) {
  final uri = _parseLink(raw.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == 'youtu.be' || _youtubeHosts.contains(host);
}

/// El id numérico de un enlace de Vimeo, o `null`.
///
/// Es el último segmento numérico: cubre `vimeo.com/123`,
/// `vimeo.com/channels/staffpicks/123` y `player.vimeo.com/video/123`.
String? vimeoVideoIdFrom(String raw) {
  final uri = _parseLink(raw.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (host != 'vimeo.com' && host != 'player.vimeo.com') return null;
  for (final segment in uri.pathSegments.reversed) {
    if (RegExp(r'^\d+$').hasMatch(segment)) return segment;
  }
  return null;
}

/// Enlace canónico de un id, para mostrárselo al LXD al editar la lección:
/// es más reconocible que el id suelto y vuelve a dar el mismo id.
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

/// Miniatura de un video. `hqdefault` (480×360) existe para todo video
/// público; `maxresdefault` no, y cuando falta YouTube responde una imagen
/// gris de 120×90 con estado 404 que el navegador igual dibuja, estirada.
///
/// Se pide a `i.ytimg.com`, el único dominio de imágenes que tiene que
/// permitir la CSP (`img-src`).
String youtubeThumbnailUrl(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

/// `null` si no es http(s). Sin esquema se asume `https://`: es como la gente
/// copia de la barra de direcciones del teléfono (`youtube.com/watch?v=…`).
Uri? _parseLink(String text) {
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasAuthority) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

/// Qué es lo que pegó el LXD en el campo de video de una lección.
enum VideoLinkKind {
  /// Campo vacío: la lección todavía no tiene video, y está bien.
  empty,

  /// Un video de YouTube: se guarda solo [VideoLink.youtubeId].
  youtube,

  /// Un video de Vimeo: se guarda el enlace, como siempre.
  vimeo,

  /// Es de YouTube pero no de un video: un canal, una lista, la portada.
  youtubeNotVideo,

  /// Cualquier otra cosa.
  unsupported,
}

/// El resultado de leer el campo, con el mensaje que corresponde mostrar.
class VideoLink {
  final VideoLinkKind kind;

  /// Solo [VideoLinkKind.youtube].
  final String? youtubeId;

  /// Solo [VideoLinkKind.vimeo]: el enlace tal cual, sin espacios.
  final String? url;

  const VideoLink._(this.kind, {this.youtubeId, this.url});

  factory VideoLink.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const VideoLink._(VideoLinkKind.empty);

    final id = youtubeVideoIdFrom(text);
    if (id != null) return VideoLink._(VideoLinkKind.youtube, youtubeId: id);
    if (isYoutubeLink(text)) {
      return const VideoLink._(VideoLinkKind.youtubeNotVideo);
    }
    if (vimeoVideoIdFrom(text) != null) {
      return VideoLink._(VideoLinkKind.vimeo, url: text);
    }
    return const VideoLink._(VideoLinkKind.unsupported);
  }

  bool get isValid =>
      kind == VideoLinkKind.empty ||
      kind == VideoLinkKind.youtube ||
      kind == VideoLinkKind.vimeo;

  /// Qué está mal, en palabras de quien lo pegó. `null` si se puede guardar.
  String? get problem => switch (kind) {
        VideoLinkKind.youtubeNotVideo =>
          tr.youtubeNoEsVideo,
        VideoLinkKind.unsupported =>
          tr.youtubePegueEnlace,
        _ => null,
      };
}
