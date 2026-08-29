import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el par de tokens entre recargas de la página.
///
/// Usa `shared_preferences` (en web, `localStorage`) en vez de la caja
/// `session` de Hive que había antes: es lo único que necesitaba persistir del
/// lado del cliente, y arrastrar Hive entero por dos strings no tiene sentido.
///
/// Ojo con lo que esto NO es: `localStorage` es legible por cualquier script
/// que corra en la página, así que no protege contra XSS. La defensa real es
/// que el access token dura 12 h y el refresh se rota en cada uso — un token
/// robado tiene ventana, no vida eterna. Guardar el refresh en una cookie
/// `HttpOnly` sería mejor, pero exige que la API y el frontend compartan
/// dominio, cosa que hoy no pasa (GitHub Pages + API Gateway).
/// Guardar la sesión NUNCA puede tumbar la app.
///
/// El almacenamiento del navegador no siempre está: una ventana privada, un
/// navegador con los datos de sitio bloqueados, o —como pasó de verdad en el
/// recorrido de prueba— un registrante de plugins desactualizado. En todos
/// esos casos leer o escribir lanza, y si eso se propaga, la PORTADA PÚBLICA
/// se cae: no necesita sesión, pero igual pasaba por acá.
///
/// Así que se degrada en silencio a "no hay sesión guardada". La consecuencia
/// para quien usa la app es que tiene que volver a entrar al recargar, que es
/// molesto pero honesto; la alternativa era una pantalla de error sin salida.
class TokenStore {
  static const _accessKey = 'enactus.accessToken';
  static const _refreshKey = 'enactus.refreshToken';

  SharedPreferences? _prefs;

  /// Se recuerda que el almacenamiento falló para no reintentar —y volver a
  /// registrar el mismo error— en cada petición.
  bool _unavailable = false;

  /// Copia en memoria. Cubre el caso de una sesión que empieza con el
  /// almacenamiento roto: mientras la pestaña siga abierta, la sesión sirve.
  String? _access;
  String? _refresh;

  Future<SharedPreferences?> get _store async {
    if (_unavailable) return null;
    try {
      return _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint(
          'TokenStore: el navegador no permite guardar la sesión ($e). '
          'La sesión durará solo mientras esta pestaña esté abierta.');
      _unavailable = true;
      return null;
    }
  }

  Future<String?> readAccess() async =>
      (await _store)?.getString(_accessKey) ?? _access;

  Future<String?> readRefresh() async =>
      (await _store)?.getString(_refreshKey) ?? _refresh;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    final store = await _store;
    if (store == null) return;
    try {
      await store.setString(_accessKey, accessToken);
      await store.setString(_refreshKey, refreshToken);
    } catch (e) {
      debugPrint('TokenStore: no se pudo guardar la sesión ($e).');
      _unavailable = true;
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    final store = await _store;
    if (store == null) return;
    try {
      await store.remove(_accessKey);
      await store.remove(_refreshKey);
    } catch (e) {
      debugPrint('TokenStore: no se pudo limpiar la sesión ($e).');
    }
  }
}
