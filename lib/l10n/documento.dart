/// El atributo `lang` del documento HTML (lectores de pantalla, traductor
/// del navegador). Solo existe en la web; en el teléfono no hace nada.
library;

export 'documento_io.dart' if (dart.library.js_interop) 'documento_web.dart';
