import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

/// Reproducción de video en **navegador**.
///
/// Antes este archivo servía `course_resources/<archivo>`: una carpeta local
/// que existía cuando los datos vivían en Hive. Con la API esa carpeta ya no
/// significa nada — el archivo está en S3 y solo se puede ver por CloudFront —
/// así que la función cambió de entrada: recibe la URL firmada que devuelve
/// `GET /lessons/:id/video-url` en vez de una ruta de disco.
///
/// El par `video_source_io` / `video_source_web` se conserva porque las dos
/// mitades siguen siendo genuinamente distintas: solo el navegador tiene
/// iframes.

/// `<video>` HTML5 apuntando a la URL firmada.
///
/// `video_player` en web renderiza un `<video>` real, así que no hace falta
/// construirlo a mano: se aprovechan sus controles, su buffering y su manejo
/// de errores de red.
Future<VideoPlayerController> createSignedVideoController(String url) async {
  final controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await controller.initialize();
  return controller;
}

/// `true` si esta plataforma puede embeber un iframe. Solo el navegador.
const bool puedeEmbeber = true;

/// Cada URL distinta necesita su propio identificador de vista registrado.
final Set<String> _registradas = {};

/// Un `<iframe>` con el reproductor de YouTube/Vimeo.
///
/// Se usa el dominio de *embed* (`youtube-nocookie.com`, `player.vimeo.com`),
/// no el enlace que la gente pega: la página de mirar no se deja embeber
/// —responde `X-Frame-Options`— y el resultado sería un recuadro en blanco sin
/// ningún error visible.
Widget buildEmbeddedVideo(String embedUrl) {
  final viewType = 'video-embed-${embedUrl.hashCode}';
  if (_registradas.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..src = embedUrl
        ..allow = 'accelerometer; encrypted-media; picture-in-picture; fullscreen'
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
