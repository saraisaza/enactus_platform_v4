import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'data_provider.dart';

/// Sesión del usuario autenticado.
///
/// La sesión se persiste en la BD local con una expiración de
/// [sessionDuration]: al recargar la página el usuario sigue dentro hasta
/// que el tiempo venza o cierre sesión.
class AuthProvider extends ChangeNotifier {
  static const sessionDuration = Duration(hours: 12);

  final DataProvider data;
  AuthProvider(this.data);

  AppUser? _currentUser;
  bool _loggedIn = false;

  /// El usuario de la sesión actual. Sigue devolviendo el último usuario
  /// autenticado incluso justo después de [logout] (ver por qué en
  /// [logout]) — para saber si la sesión sigue activa hay que consultar
  /// [isLoggedIn], no la nulidad de esto.
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _loggedIn && _currentUser != null;

  /// Restaura la sesión guardada si aún no ha expirado.
  /// Devuelve el usuario restaurado o null.
  AppUser? tryRestoreSession() {
    final saved = data.db.get('session', 'current');
    if (saved == null) return null;
    final expiresAt = DateTime.tryParse((saved['expiresAt'] as String?) ?? '');
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      data.db.delete('session', 'current');
      return null;
    }
    final user = data.userById((saved['userId'] as String?) ?? '');
    _currentUser = user;
    _loggedIn = user != null;
    return user;
  }

  /// Intenta iniciar sesión; devuelve null si las credenciales son inválidas.
  AppUser? login(String email, String password) {
    final user = data.findByCredentials(email, password);
    if (user != null) {
      _currentUser = user;
      _loggedIn = true;
      data.db.put('session', 'current', {
        'userId': user.id,
        'expiresAt': DateTime.now().add(sessionDuration).toIso8601String(),
      });
      notifyListeners();
    }
    return user;
  }

  /// Refresca el usuario en sesión desde la BD (tras editar el perfil).
  void refresh() {
    if (_currentUser != null) {
      _currentUser = data.userById(_currentUser!.id);
      notifyListeners();
    }
  }

  /// Cierra la sesión: [isLoggedIn] pasa a false de inmediato (nadie puede
  /// volver a entrar a una ruta protegida) y la sesión guardada se borra,
  /// pero [currentUser] deliberadamente NO se limpia a null.
  ///
  /// Motivo: muchas pantallas leen `context.watch<AuthProvider>().currentUser!`
  /// directamente. Si currentUser se vuelve null en el mismo instante en
  /// que se navega a la pantalla de login, la pantalla que se está
  /// cerrando (todavía montada mientras Flutter anima/reconcilia la
  /// navegación) se reconstruye con currentUser nulo y lanza una excepción
  /// de null-check — se probó incluso esperando varios cientos de
  /// milisegundos y la pantalla anterior seguía montada. Como después de
  /// [logout] ninguna ruta protegida sigue siendo alcanzable (todas exigen
  /// [isLoggedIn]), dejar currentUser con el último usuario (obsoleto) es
  /// inofensivo — no se vuelve a mostrar en ningún lado — y evita tener
  /// que tocar cada pantalla para blindarla contra un currentUser nulo.
  void logout() {
    data.db.delete('session', 'current');
    _loggedIn = false;
    notifyListeners();
  }
}
