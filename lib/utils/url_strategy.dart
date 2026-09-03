/// Cómo se leen y escriben las rutas en la barra de direcciones.
///
/// Se elige en tiempo de compilación: en web configura rutas de path, en el
/// resto de plataformas no hace nada.
library;

export 'url_strategy_io.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
