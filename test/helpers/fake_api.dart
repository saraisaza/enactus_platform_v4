import 'dart:convert';

import 'package:enactus_platform/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una API falsa para los tests de widget.
///
/// **No sustituye a `ApiService`, lo alimenta**: se le inyecta un cliente HTTP
/// que responde payloads iguales a los de la API real, así que las pruebas
/// ejercitan el `ApiService` de verdad —su parseo, su manejo de errores, su
/// inyección del token— y no un doble que se comporta como uno quisiera.
///
/// Si la forma de una respuesta cambia en el backend, estas pruebas fallan por
/// la misma razón por la que fallaría la app.
class FakeApi {
  /// Respuestas por ruta, sin el prefijo de la URL base. La clave incluye la
  /// query cuando importa (`/courses?...` se normaliza al camino solo).
  final Map<String, Object?> routes;

  /// Rutas que deben responder 404, para probar los estados de error.
  final Set<String> notFound;

  /// Código HTTP por ruta, cuando no es 200. Sirve para reproducir un fallo
  /// REAL del servidor (p. ej. el 503 de `/files/download-url` cuando S3 no
  /// está configurado) en vez de fingir un éxito que la app no recibe nunca.
  final Map<String, int> statuses;

  /// Qué se pidió, en orden. Sirve para afirmar que una pantalla NO pide algo
  /// que no le corresponde.
  final List<String> requested = [];

  /// El cuerpo de cada petición, en el MISMO orden que [requested].
  ///
  /// Existe porque afirmar solo sobre método y ruta deja pasar la clase de
  /// error más cara: la petición correcta con el cuerpo equivocado. El
  /// calendario mandaba `courseId: ''` donde el servidor espera un uuid o
  /// `null`, y ninguna prueba podía verlo.
  final List<Map<String, dynamic>> cuerpos = [];

  /// Qué responder cuando la ruta no está en [routes].
  ///
  /// Por defecto es `null` y una ruta sin respuesta hace fallar la prueba
  /// ruidosamente: en una prueba de navegación, pedir algo que no se esperaba
  /// ES el hallazgo. Las pruebas de MAQUETACIÓN lo usan al revés —les importa
  /// que la pantalla se dibuje en cada ancho, no qué pidió— y ahí enumerar
  /// cincuenta rutas solo agrega ruido.
  final Object? Function(String path)? fallback;

  /// Retraso artificial de cada respuesta. En cero, `MockClient` resuelve tan
  /// rápido que el estado de carga se pierde entre dos `pump`; con un retraso
  /// se puede observar, que es justo lo que algunas pruebas necesitan.
  final Duration delay;

  FakeApi({
    Map<String, Object?>? routes,
    Set<String>? notFound,
    Map<String, int>? statuses,
    this.fallback,
    this.delay = Duration.zero,
  })  : routes = routes ?? {},
        notFound = notFound ?? {},
        statuses = statuses ?? {};

  ApiService build() {
    final client = MockClient((request) async {
      final path = request.url.path;
      requested.add('${request.method} $path');
      cuerpos.add(
        request.body.isEmpty
            ? const {}
            : jsonDecode(request.body) as Map<String, dynamic>,
      );
      if (delay > Duration.zero) await Future<void>.delayed(delay);

      if (notFound.contains(path)) {
        return _error(404, 'not_found', 'No encontramos lo que buscabas.');
      }

      final body = routes[path] ?? fallback?.call(path);
      if (body == null) {
        // Falta una ruta en el fake: se falla ruidosamente en vez de devolver
        // vacío, que haría pasar una prueba por la razón equivocada.
        fail('El fake no tiene respuesta para $path. Agregala en `routes`.');
      }
      return http.Response(jsonEncode(body), statuses[path] ?? 200,
          headers: {'content-type': 'application/json'});
    });

    return ApiService(client: client);
  }

  http.Response _error(int status, String code, String message) =>
      http.Response(jsonEncode({'error': {'code': code, 'message': message}}),
          status,
          headers: {'content-type': 'application/json'});
}

/// `TokenStore` usa `shared_preferences`, que en un test necesita valores
/// simulados o lanza al primer acceso.
void useFakeTokenStorage() {
  SharedPreferences.setMockInitialValues({});
}
