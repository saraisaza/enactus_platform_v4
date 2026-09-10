import 'dart:convert';
import 'dart:io';

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
      final cuerpo = request.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      cuerpos.add(cuerpo);
      _anotarEnElContrato(request.method, path, cuerpo);
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


// ---------------------------------------------------------------------------
// Contrato cliente -> servidor
// ---------------------------------------------------------------------------
//
// Con `GENERAR_CONTRATO=1`, cada petición con cuerpo que el cliente emite
// durante la suite queda anotada en `test/fixtures/cuerpos_del_cliente.json`.
// Ese archivo lo consume `backend/tests/contrato-cliente.test.ts`, que reenvía
// cada cuerpo al endpoint REAL y comprueba que el servidor no lo rechace por
// inválido.
//
// Existe por el fallo del calendario: las pruebas del servidor escribían el
// cuerpo por su cuenta —solo el campo que ese tipo de evento usa— mientras el
// cliente mandaba los dos, con `''` en el que no aplicaba. El servidor
// respondía 400 y ninguna de las dos suites podía verlo, porque **cada una
// medía lo que ella misma enviaba**. Con esto, el cuerpo lo pone el cliente y
// la validación la pone el servidor: se acabó el circuito cerrado.
//
// Regenerar:  GENERAR_CONTRATO=1 flutter test

final Map<String, Map<String, dynamic>> _contrato = {};
bool _contratoRegistrado = false;

void _anotarEnElContrato(String metodo, String path, Map<String, dynamic> cuerpo) {
  if (Platform.environment['GENERAR_CONTRATO'] != '1') return;
  if (cuerpo.isEmpty) return;

  // Los ids concretos se normalizan: lo que se contrasta es la FORMA del
  // cuerpo, no a qué fila apuntaba esa corrida.
  final clave = '$metodo ${path.replaceAll(
    RegExp(r'/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'),
    '/:id',
  )}';
  // Se queda el cuerpo MÁS COMPLETO de cada endpoint: el que más campos trae
  // es el que más superficie de validación ejercita.
  final previo = _contrato[clave];
  if (previo == null || cuerpo.length > previo.length) _contrato[clave] = cuerpo;

  if (!_contratoRegistrado) {
    _contratoRegistrado = true;
    addTearDown(_volcarContrato);
  }
}

void _volcarContrato() {
  if (_contrato.isEmpty) return;
  final archivo = File('test/fixtures/cuerpos_del_cliente.json');
  final previo = archivo.existsSync()
      ? (jsonDecode(archivo.readAsStringSync()) as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  final union = <String, dynamic>{...previo};
  _contrato.forEach((k, v) {
    final anterior = union[k];
    if (anterior is! Map || v.length > anterior.length) union[k] = v;
  });
  final ordenado = Map.fromEntries(
    union.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  archivo.writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert(ordenado)}\n',
  );
}
