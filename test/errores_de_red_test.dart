// Sin conexión, la persona ve un mensaje en español y un "Reintentar".
//
// En el teléfono los cortes de red son lo normal, no la excepción. Antes se
// mostraba el detalle técnico de `package:http` ("Failed host lookup:
// 'api.eduxaction.com'"), y un certificado que no valida —el wifi de un
// campus que intercepta la conexión para pedir inicio de sesión— ni siquiera
// se traducía: se escapaba sin mensaje.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/services/token_store.dart';

import 'helpers/fake_api.dart';

Future<ApiException> _errorDe(Object falla) async {
  final api = ApiService(
    tokenStore: TokenStore(),
    client: MockClient((_) async => throw falla),
  );
  try {
    await api.get('/courses');
  } on ApiException catch (e) {
    return e;
  }
  fail('La petición no falló.');
}

void main() {
  setUp(useFakeTokenStorage);

  test('sin red: error de red en español, sin el detalle técnico', () async {
    final e = await _errorDe(http.ClientException(
        "Failed host lookup: 'api.eduxaction.com'"));
    expect(e, isA<NetworkError>());
    expect(e.message, isNot(contains('Failed host lookup')));
    expect(e.message, contains('No pudimos conectar con el servidor'));
  });

  test('certificado que no valida (wifi con portal): también es error de red',
      () async {
    final e = await _errorDe(const HandshakeException(
        'CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate'));
    expect(e, isA<NetworkError>(),
        reason: 'Un fallo de certificado se escapó sin traducir.');
    expect(e.message, isNot(contains('CERTIFICATE')));
  });
}
