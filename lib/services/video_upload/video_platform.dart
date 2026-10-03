/// Lo que cambia entre el navegador y las apps: elegir el archivo, leer su
/// primer fotograma, subir cada parte y recibir lo que se suelta encima.
library;

export 'video_platform_io.dart'
    if (dart.library.js_interop) 'video_platform_web.dart';
