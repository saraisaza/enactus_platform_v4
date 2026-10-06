import 'package:web/web.dart' as web;

/// `<html lang="es">` o `<html lang="en">`: así el lector de pantalla lee con
/// la pronunciación correcta y el navegador no ofrece "traducir" una página
/// que ya está en el idioma de la persona.
void marcarIdiomaDelDocumento(String codigo) {
  web.document.documentElement?.setAttribute('lang', codigo);
}
