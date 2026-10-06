/// Acceso a los textos de la interfaz en el idioma activo.
///
/// `tr.guardar` en vez de `'Guardar'`. Es un acceso global —y no
/// `AppLocalizations.of(context)`— porque muchos textos se arman lejos de un
/// `BuildContext`: etiquetas de los modelos, mensajes de error de la capa de
/// datos, el PDF del certificado. Al cambiar de idioma, [Idioma.cambiar]
/// redibuja toda la app, así que nadie se queda con el texto viejo.
library;

import 'app_localizations.dart';
import 'idioma.dart';

export 'app_localizations.dart' show AppLocalizations;
export 'idioma.dart' show Idioma;

/// Los textos de la interfaz en el idioma que eligió la persona.
AppLocalizations get tr => Idioma.instancia.textos;
