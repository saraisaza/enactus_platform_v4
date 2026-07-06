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
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

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
    return user;
  }

  /// Intenta iniciar sesión; devuelve null si las credenciales son inválidas.
  AppUser? login(String email, String password) {
    final user = data.findByCredentials(email, password);
    if (user != null) {
      _currentUser = user;
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

  void logout() {
    _currentUser = null;
    data.db.delete('session', 'current');
    notifyListeners();
  }
}
