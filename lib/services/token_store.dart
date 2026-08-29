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
class TokenStore {
  static const _accessKey = 'enactus.accessToken';
  static const _refreshKey = 'enactus.refreshToken';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> readAccess() async => (await _store).getString(_accessKey);

  Future<String?> readRefresh() async => (await _store).getString(_refreshKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    final store = await _store;
    await store.setString(_accessKey, accessToken);
    await store.setString(_refreshKey, refreshToken);
  }

  Future<void> clear() async {
    final store = await _store;
    await store.remove(_accessKey);
    await store.remove(_refreshKey);
  }
}
