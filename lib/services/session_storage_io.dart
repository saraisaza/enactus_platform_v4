import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dónde vive la sesión fuera del navegador: el Llavero de iOS y el Keystore
/// de Android, cifrados por el sistema.
///
/// `shared_preferences` guardaba los tokens en texto plano dentro del
/// teléfono —y en Android entraban al respaldo automático de Google—. Un token
/// que se puede copiar de un respaldo es una sesión que se puede copiar.
class SessionStorage {
  /// Solo legible en ESTE dispositivo y después del primer desbloqueo: no
  /// viaja en respaldos a otro teléfono y la app puede leerlo al volver de
  /// segundo plano aunque la pantalla se haya bloqueado.
  static const _seguro = FlutterSecureStorage(
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Marca que SÍ se borra al desinstalar (preferencias normales).
  static const _instalada = 'enactus.instalada';

  bool _revisado = false;

  /// El Llavero de iOS sobrevive a la desinstalación de la app. Sin esto,
  /// quien borra la app y la vuelve a instalar —o se la pasa a otra persona—
  /// entraría directo con la sesión anterior.
  Future<void> _limpiarSiEsInstalacionNueva() async {
    if (_revisado) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_instalada) != true) {
      await _seguro.deleteAll();
      await prefs.setBool(_instalada, true);
    }
    _revisado = true;
  }

  Future<String?> read(String key) async {
    await _limpiarSiEsInstalacionNueva();
    return _seguro.read(key: key);
  }

  Future<void> write(String key, String value) async {
    await _limpiarSiEsInstalacionNueva();
    await _seguro.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    await _limpiarSiEsInstalacionNueva();
    await _seguro.delete(key: key);
  }
}
