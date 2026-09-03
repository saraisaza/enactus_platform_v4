import 'package:flutter_web_plugins/url_strategy.dart';

/// Rutas de verdad en la barra de direcciones: `/login`, no `/#/login`.
///
/// Sin esto Flutter Web usa enrutamiento por **hash**, y eso rompe algo
/// concreto: entrar directo a `eduxaction.com/proyectos/123` sirve el
/// `index.html` correcto —CloudFront responde 200— pero la aplicación
/// arranca viendo la ruta `/` porque el hash está vacío, y muestra la
/// portada. La dirección parece funcionar y lleva a otro lado.
///
/// Con esta estrategia, la ruta de la URL es la ruta de la aplicación. Es lo
/// que hace útil la regla de CloudFront que manda 403 y 404 a `/index.html`:
/// esas rutas no existen como objetos en S3 y las resuelve Flutter.
void configurarRutas() => usePathUrlStrategy();
