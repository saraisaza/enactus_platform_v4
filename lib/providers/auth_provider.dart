import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_errors.dart';
import '../services/api_service.dart';
import 'data_provider.dart';

/// Sesión del usuario, contra la API.
///
/// La sesión ya no es una fila en Hive con una fecha de expiración: es un JWT
/// de 12 horas emitido por el servidor, con un refresh que se rota solo. El
/// cliente no decide cuándo expira — solo reacciona.
class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final DataProvider data;

  AuthProvider(this.api, this.data) {
    // Si el refresh también falla, `ApiService` avisa por acá y la sesión se
    // cierra sola. Es lo que hace que una pestaña abierta toda la noche vuelva
    // al ingreso en vez de quedarse mostrando errores.
    api.onSessionExpired = _onSessionExpired;
  }

  AppUser? _currentUser;
  bool _restoring = true;
  ApiException? _loginError;
  bool _loggingIn = false;

  /// Usuario de la sesión, o `null` si no hay.
  ///
  /// A diferencia del `AuthProvider` anterior —que dejaba el último usuario
  /// puesto tras cerrar sesión para no romper pantallas que hacían
  /// `currentUser!`— acá se limpia de verdad. Las pantallas ahora leen estado
  /// asíncrono y saben mostrar el caso "sin sesión".
  AppUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  /// Mientras se comprueba si hay una sesión guardada. La app muestra una
  /// pantalla de carga: sin esto, se vería el ingreso por un instante antes
  /// de saltar al portal.
  bool get isRestoring => _restoring;

  bool get isLoggingIn => _loggingIn;
  ApiException? get loginError => _loginError;

  /// Recupera la sesión guardada al arrancar.
  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      final json = await api.restoreSession();
      _setUser(json == null ? null : AppUser.fromJson(json));
    } on ApiException catch (e) {
      // Sin red al arrancar no es "sesión inválida": no se borran los tokens,
      // para que al volver la conexión la sesión siga estando.
      debugPrint('No se pudo restaurar la sesión: ${e.message}');
      _setUser(null);
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Devuelve el usuario si entró, o `null` — el motivo queda en [loginError].
  Future<AppUser?> login(String email, String password) async {
    _loggingIn = true;
    _loginError = null;
    notifyListeners();
    try {
      final user = AppUser.fromJson(await api.login(email, password));
      _setUser(user);
      return user;
    } on ApiException catch (e) {
      _loginError = e;
      return null;
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.logout();
    _setUser(null);
    notifyListeners();
  }

  /// Vuelve a leer el usuario del servidor.
  Future<void> refresh() async {
    if (_currentUser == null) return;
    try {
      final json = await api.get('/auth/me');
      _setUser(AppUser.fromJson(Map<String, dynamic>.from(json as Map)));
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint('No se pudo refrescar el perfil: ${e.message}');
    }
  }

  /// Guarda cambios en el PROPIO perfil.
  ///
  /// El servidor decide qué campos acepta: mandarle `role` o `canGradeEnactus`
  /// no hace nada. Devuelve el usuario ya actualizado —con equipo y
  /// patrocinador— así que no hace falta un `refresh()` después.
  ///
  /// No atrapa el error a propósito: quien llama necesita distinguir "sin
  /// conexión" de "ese teléfono no es válido" para poder decírselo a la
  /// persona.
  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final json = await api.patch('/auth/me', body: changes);
    _currentUser = AppUser.fromJson(Map<String, dynamic>.from(json as Map));
    notifyListeners();
  }

  /// Fija la sesión sin pasar por el ingreso. **Solo para pruebas.**
  ///
  /// Las pruebas de maquetación montan un portal directamente; sin sesión, el
  /// guardia de rol redirige al ingreso y la prueba verificaría esa pantalla
  /// creyendo que verifica el portal. No hay forma de llegar acá desde la app.
  @visibleForTesting
  void debugSetSession(Map<String, dynamic> user) {
    _restoring = false;
    _setUser(AppUser.fromJson(user));
    notifyListeners();
  }

  void _setUser(AppUser? user) {
    _currentUser = user;
    // El provider de datos necesita saber de quién son "mis" cursos, y tiene
    // que tirar todo su estado al cambiar de sesión.
    data.setCurrentUser(user?.id);
  }

  void _onSessionExpired() {
    _currentUser = null;
    data.setCurrentUser(null);
    notifyListeners();
  }
}
