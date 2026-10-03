import 'dart:async';

import 'package:flutter/services.dart';

/// En las apps, pantalla completa es esconder las barras del sistema.
Future<void> enterSystemFullscreen() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

Future<void> exitSystemFullscreen() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// Fuera del navegador no hay un Esc del sistema que avise.
StreamSubscription<void> onSystemFullscreenExit(void Function() callback) =>
    const Stream<void>.empty().listen((_) {});
