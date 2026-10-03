import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Pantalla completa del NAVEGADOR (la de verdad, sin barras), además de la
/// ruta de Flutter que tapa la app.
Future<void> enterSystemFullscreen() async {
  try {
    await web.document.documentElement?.requestFullscreen().toDart;
  } catch (_) {
    // Safari en iPhone no la permite fuera de `<video>`: queda la de Flutter,
    // que igual ocupa toda la ventana.
  }
}

Future<void> exitSystemFullscreen() async {
  if (web.document.fullscreenElement == null) return;
  try {
    await web.document.exitFullscreen().toDart;
  } catch (_) {}
}

/// Avisa cuando el navegador sale de pantalla completa por su cuenta (Esc).
StreamSubscription<void> onSystemFullscreenExit(void Function() callback) {
  final controller = StreamController<void>();
  final listener = ((web.Event _) {
    if (web.document.fullscreenElement == null) controller.add(null);
  }).toJS;
  web.document.addEventListener('fullscreenchange', listener);
  controller.onCancel = () {
    web.document.removeEventListener('fullscreenchange', listener);
  };
  return controller.stream.listen((_) => callback());
}
