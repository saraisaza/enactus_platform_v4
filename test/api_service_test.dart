import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/services/token_store.dart';

/// Pruebas del cliente HTTP.
///
/// Se usa un [MockClient] en vez del backend real: acá interesa el
/// comportamiento del CLIENTE ante cada respuesta posible (renovar la sesión,
/// reintentar, traducir el error), no que el servidor conteste bien — eso ya
/// lo cubren los 189 tests del backend.

/// Respuesta JSON con el código indicado.
http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() {
    // `shared_preferences` necesita un almacén simulado en tests.
    SharedPreferences.setMockInitialValues({});
  });

  group('inyección del token', () {
    test('manda el Authorization cuando hay sesión', () async {
      final vistos = <String?>[];
      final store = TokenStore();
      await store.save(accessToken: 'token-abc', refreshToken: 'r1');

      final api = ApiService(
        tokenStore: store,
        client: MockClient((request) async {
          vistos.add(request.headers['Authorization']);
          return _json({'ok': true});
        }),
      );

      await api.get('/courses');
      expect(vistos.single, 'Bearer token-abc');
    });

    test('no lo manda en el login', () async {
      String? visto = 'sin tocar';
      final api = ApiService(
        tokenStore: TokenStore(),
        client: MockClient((request) async {
          visto = request.headers['Authorization'];
          return _json({
            'accessToken': 'a',
            'refreshToken': 'r',
            'user': {'id': '1', 'name': 'Ana'},
          });
        }),
      );

      await api.login('ana@test.co', 'x');
      expect(visto, isNull);
    });

    test('el login guarda los dos tokens', () async {
      final store = TokenStore();
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => _json({
              'accessToken': 'nuevo-access',
              'refreshToken': 'nuevo-refresh',
              'user': {'id': '1'},
            })),
      );

      final user = await api.login('ana@test.co', 'x');
      expect(user['id'], '1');
      expect(await store.readAccess(), 'nuevo-access');
      expect(await store.readRefresh(), 'nuevo-refresh');
    });
  });

  group('renovación automática de la sesión', () {
    test('un 401 dispara el refresh y REINTENTA la petición original',
        () async {
      final store = TokenStore();
      await store.save(accessToken: 'viejo', refreshToken: 'r1');
      final llamadas = <String>[];

      final api = ApiService(
        tokenStore: store,
        client: MockClient((request) async {
          llamadas.add('${request.method} ${request.url.path}');
          if (request.url.path == '/auth/refresh') {
            return _json({'accessToken': 'fresco', 'refreshToken': 'r2'});
          }
          // La primera vez con el token viejo: 401. Con el nuevo: 200.
          if (request.headers['Authorization'] == 'Bearer fresco') {
            return _json({'data': 'contenido real'});
          }
          return _json({
            'error': {'code': 'unauthorized', 'message': 'expiró'}
          }, 401);
        }),
      );

      final resultado = await api.get('/courses');

      expect(resultado, {'data': 'contenido real'});
      expect(llamadas, [
        'GET /courses', // falla con 401
        'POST /auth/refresh', // renueva
        'GET /courses', // reintento, ahora sí
      ]);
      // Y el token nuevo quedó guardado.
      expect(await store.readAccess(), 'fresco');
    });

    test('si el refresh también falla, lanza AuthError y avisa una sola vez',
        () async {
      final store = TokenStore();
      await store.save(accessToken: 'viejo', refreshToken: 'vencido');
      var avisos = 0;

      final api = ApiService(
        tokenStore: store,
        client: MockClient((request) async => _json({
              'error': {'code': 'unauthorized', 'message': 'no vale'}
            }, 401)),
      )..onSessionExpired = () => avisos++;

      await expectLater(api.get('/courses'), throwsA(isA<AuthError>()));
      expect(avisos, 1);
      // Los tokens se soltaron: no queda una sesión fantasma.
      expect(await store.readAccess(), isNull);
      expect(await store.readRefresh(), isNull);
    });

    test('no reintenta en bucle: un 401 en el reintento se propaga', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      var peticiones = 0;

      final api = ApiService(
        tokenStore: store,
        client: MockClient((request) async {
          peticiones++;
          if (request.url.path == '/auth/refresh') {
            return _json({'accessToken': 'a2', 'refreshToken': 'r2'});
          }
          return _json({
            'error': {'code': 'unauthorized', 'message': 'sigue mal'}
          }, 401);
        }),
      );

      await expectLater(api.get('/courses'), throwsA(isA<AuthError>()));
      // Original + refresh + UN reintento. Ni uno más.
      expect(peticiones, 3);
    });

    test('tres peticiones que fallan a la vez disparan UN solo refresh',
        () async {
      // Esto importa de verdad: el backend rota el refresh en cada uso e
      // interpreta el reuso de uno ya rotado como token robado, cerrando
      // TODAS las sesiones. Sin un refresh único en vuelo, tres peticiones
      // simultáneas con 401 dejarían a la persona afuera.
      final store = TokenStore();
      await store.save(accessToken: 'viejo', refreshToken: 'r1');
      var refrescos = 0;

      final api = ApiService(
        tokenStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refrescos++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return _json({'accessToken': 'fresco', 'refreshToken': 'r2'});
          }
          if (request.headers['Authorization'] == 'Bearer fresco') {
            return _json({'ok': request.url.path});
          }
          return _json({
            'error': {'code': 'unauthorized', 'message': 'expiró'}
          }, 401);
        }),
      );

      final resultados = await Future.wait([
        api.get('/courses'),
        api.get('/projects'),
        api.get('/notifications'),
      ]);

      expect(refrescos, 1);
      expect(resultados.length, 3);
    });
  });

  group('traducción de errores', () {
    Future<void> esperaError(int status, Object body, Matcher matcher) async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => _json(body, status)),
      );
      await expectLater(api.get('/x'), throwsA(matcher));
    }

    test('403 → ForbiddenError con el mensaje del servidor', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => _json({
              'error': {
                'code': 'forbidden',
                'message': 'Tu cuenta es de Open Learning.'
              }
            }, 403)),
      );

      try {
        await api.get('/laboratories');
        fail('debía lanzar');
      } on ForbiddenError catch (e) {
        expect(e.message, 'Tu cuenta es de Open Learning.');
        expect(e.code, 'forbidden');
      }
    });

    test('404 → NotFoundError', () async {
      await esperaError(404, {
        'error': {'code': 'not_found', 'message': 'No existe.'}
      }, isA<NotFoundError>());
    });

    test('409 → ConflictError conservando el detalle', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => _json({
              'error': {
                'code': 'conflict',
                'message': 'La Ruta no está completa.',
                'details': {'phasesDone': 2, 'phasesTotal': 3},
              }
            }, 409)),
      );

      try {
        await api.post('/certificates/ruta');
        fail('debía lanzar');
      } on ConflictError catch (e) {
        // El detalle es lo que la pantalla necesita para decir QUÉ falta.
        expect(e.details['phasesDone'], 2);
        expect(e.details['phasesTotal'], 3);
      }
    });

    test('400 → ValidationError con los campos', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => _json({
              'error': {
                'code': 'validation_error',
                'message': 'Datos inválidos.',
                'details': [
                  {'field': 'name', 'message': 'El nombre es obligatorio.'}
                ],
              }
            }, 400)),
      );

      try {
        await api.post('/courses', body: {});
        fail('debía lanzar');
      } on ValidationError catch (e) {
        expect(e.fields['name'], 'El nombre es obligatorio.');
      }
    });

    test('500 → ServerError, sin filtrar el detalle interno', () async {
      await esperaError(500, {
        'error': {'code': 'internal_error', 'message': 'Ocurrió un error.'}
      }, isA<ServerError>());
    });

    test('respuesta que no es JSON → ServerError, no una excepción de parseo',
        () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient(
          (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
        ),
      );
      await expectLater(api.get('/x'), throwsA(isA<ServerError>()));
    });

    test('sin red → NetworkError', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => throw http.ClientException('falló')),
      );
      await expectLater(api.get('/x'), throwsA(isA<NetworkError>()));
    });

    test('204 sin cuerpo devuelve null, no revienta', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => http.Response('', 204)),
      );
      expect(await api.delete('/courses/1'), isNull);
    });
  });

  group('restaurar y cerrar sesión', () {
    test('sin token guardado no llama a la API', () async {
      var llamadas = 0;
      final api = ApiService(
        tokenStore: TokenStore(),
        client: MockClient((_) async {
          llamadas++;
          return _json({});
        }),
      );

      expect(await api.restoreSession(), isNull);
      expect(llamadas, 0);
    });

    test('con token válido devuelve el usuario', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient(
          (_) async => _json({'id': '1', 'name': 'Ana', 'role': 'student'}),
        ),
      );

      final user = await api.restoreSession();
      expect(user?['name'], 'Ana');
    });

    test('logout suelta los tokens aunque el servidor falle', () async {
      final store = TokenStore();
      await store.save(accessToken: 'a', refreshToken: 'r');
      final api = ApiService(
        tokenStore: store,
        client: MockClient((_) async => throw http.ClientException('sin red')),
      );

      await api.logout();
      // Lo contrario dejaría a la persona "dentro" por un problema de red.
      expect(await store.readAccess(), isNull);
    });
  });

  group('subida directa a S3', () {
    test('manda los bytes con el content-type y reporta progreso', () async {
      String? tipoVisto;
      var bytesVistos = 0;
      final progreso = <double>[];

      final api = ApiService(
        tokenStore: TokenStore(),
        client: MockClient((request) async {
          tipoVisto = request.headers['Content-Type'];
          bytesVistos = request.bodyBytes.length;
          return http.Response('', 200);
        }),
      );

      await api.uploadToSignedUrl(
        uploadUrl: 'https://bucket.s3.amazonaws.com/k?X-Amz-Signature=abc',
        bytes: List<int>.filled(2048, 7),
        contentType: 'video/mp4',
        onProgress: progreso.add,
      );

      expect(tipoVisto, 'video/mp4');
      expect(bytesVistos, 2048);
      expect(progreso.last, 1);
    });

    test('un rechazo de S3 se convierte en ServerError', () async {
      final api = ApiService(
        tokenStore: TokenStore(),
        client: MockClient((_) async => http.Response('AccessDenied', 403)),
      );

      await expectLater(
        api.uploadToSignedUrl(
          uploadUrl: 'https://bucket.s3.amazonaws.com/k',
          bytes: const [1, 2, 3],
          contentType: 'video/mp4',
        ),
        throwsA(isA<ServerError>()),
      );
    });
  });
}
