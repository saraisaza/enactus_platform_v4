// La sesión en el teléfono: Llavero / Keystore, y nunca a costa de la app.
//
// Dos comportamientos que no se ven en ninguna pantalla y que importan:
//
// 1. El Llavero de iOS sobrevive a la desinstalación. Quien borra la app y la
//    vuelve a instalar —o le pasa el teléfono a otra persona— no puede entrar
//    directo con la sesión anterior.
// 2. Si el almacenamiento seguro falla, la app sigue: la sesión dura mientras
//    la app esté abierta, pero nada se cae.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/services/session_storage_io.dart';
import 'package:enactus_platform/services/token_store.dart';

import 'helpers/fake_api.dart';

/// Un almacenamiento que falla en todo, como un Llavero que el sistema no
/// deja leer.
class _AlmacenRoto implements SessionStorage {
  @override
  Future<String?> read(String key) => throw Exception('Llavero no disponible');
  @override
  Future<void> write(String key, String value) =>
      throw Exception('Llavero no disponible');
  @override
  Future<void> delete(String key) => throw Exception('Llavero no disponible');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una app ya usada recupera la sesión guardada', () async {
    sembrarAlmacenamiento(access: 'a1', refresh: 'r1');
    final store = TokenStore();
    expect(await store.readAccess(), 'a1');
    expect(await store.readRefresh(), 'r1');
  });

  test('una instalación nueva NO hereda la sesión que quedó en el Llavero',
      () async {
    // Sin la marca de "ya instalada" —que sí se borra al desinstalar— pero con
    // tokens en el almacenamiento seguro: lo que deja una reinstalación.
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'enactus.accessToken': 'de-la-instalacion-anterior',
      'enactus.refreshToken': 'r-anterior',
    });

    final store = TokenStore();
    expect(await store.readAccess(), isNull,
        reason: 'La app reinstalada entró con la sesión de antes.');
    expect(await store.readRefresh(), isNull);

    // Y desde ahí ya funciona normal.
    await store.save(accessToken: 'nuevo', refreshToken: 'r-nuevo');
    expect(await TokenStore().readAccess(), 'nuevo');
  });

  test('guardar la sesión en el almacenamiento seguro y borrarla', () async {
    useFakeTokenStorage();
    final store = TokenStore();
    await store.save(accessToken: 'a2', refreshToken: 'r2');
    expect(await TokenStore().readAccess(), 'a2',
        reason: 'Otra instancia —la app reabierta— no encontró la sesión.');

    await store.clear();
    expect(await TokenStore().readAccess(), isNull);
    expect(await SessionStorage().read('enactus.refreshToken'), isNull);
  });

  test('si el almacenamiento falla, la sesión vive en memoria y nada se cae',
      () async {
    final store = TokenStore(storage: _AlmacenRoto());
    await store.save(accessToken: 'en-memoria', refreshToken: 'r');
    expect(await store.readAccess(), 'en-memoria');
    await store.clear();
    expect(await store.readAccess(), isNull);
  });
}
