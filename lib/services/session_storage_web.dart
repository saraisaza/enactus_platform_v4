import 'package:shared_preferences/shared_preferences.dart';

/// Dónde vive la sesión en el navegador: `localStorage`, vía
/// `shared_preferences`. Ver en `token_store.dart` por qué se mantiene así en
/// la web y cuál es el control compensatorio (la CSP).
class SessionStorage {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> read(String key) async => (await _store).getString(key);

  Future<void> write(String key, String value) async =>
      (await _store).setString(key, value);

  Future<void> delete(String key) async => (await _store).remove(key);
}
