/// Botón de red social: enlace externo con ícono.
///
/// La implementación difiere de verdad entre plataformas (ver
/// `social_button_web.dart` para el motivo), así que se elige en tiempo de
/// compilación.
library;

export 'social_button_io.dart' if (dart.library.js_interop) 'social_button_web.dart';
