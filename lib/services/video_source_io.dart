import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Reproducción de video fuera del navegador (escritorio y móvil).
///
/// Antes este archivo abría el archivo local de `course_resources/`: una
/// carpeta que tenía sentido cuando los datos vivían en Hive. Con la API el
/// archivo está en S3 y solo se sirve por CloudFront, así que la función
/// recibe la URL firmada que devuelve `GET /lessons/:id/video-url`.
///
/// La mitad que de verdad cambia entre plataformas es la de los enlaces
/// externos: acá no hay iframe, así que el reproductor abre YouTube o Vimeo en
/// la aplicación del sistema. Por eso el par de archivos sigue existiendo.

/// `<video>` nativo apuntando a la URL firmada. La misma llamada que en web:
/// `video_player` ya resuelve el reproductor de cada plataforma.
Future<VideoPlayerController> createSignedVideoController(String url) async {
  final controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await controller.initialize();
  return controller;
}

/// Fuera del navegador no hay iframe. Quien llame tiene que ofrecer abrir el
/// enlace afuera, que es lo que hace [VideoPlayerDialog].
const bool puedeEmbeber = false;

/// Nunca se llama con [puedeEmbeber] en `false`. Existe para que las dos
/// mitades expongan la misma superficie y el consumidor no tenga que saber en
/// qué plataforma está.
Widget buildEmbeddedVideo(String embedUrl) =>
    throw UnsupportedError('Solo el navegador puede embeber un iframe.');
