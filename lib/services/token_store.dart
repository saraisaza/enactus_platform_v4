import 'package:flutter/foundation.dart';

import 'session_storage_io.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';

/// Guarda el par de tokens entre recargas de la página y entre aperturas de
/// la app.
///
/// Dónde, depende de la plataforma (se elige al compilar, ver
/// `session_storage_*.dart`):
///
/// - **En el teléfono**, el Llavero de iOS y el Keystore de Android, cifrados
///   por el sistema y fuera de los respaldos.
/// - **En el navegador**, `localStorage` vía `shared_preferences`, en vez de la
///   caja `session` de Hive que había antes: es lo único que necesitaba
///   persistir del lado del cliente, y arrastrar Hive entero por dos strings
///   no tiene sentido.
///
/// Ojo con lo que `localStorage` NO es: es legible por cualquier script que
/// corra en la página, así que no protege contra XSS. La defensa real es que
/// el access token dura 12 h y el refresh se rota en cada uso — un token
/// robado tiene ventana, no vida eterna.
///
/// **Por qué no una cookie `HttpOnly`, hoy.** La razón que decía este
/// comentario —«la API y el frontend no comparten dominio (GitHub Pages +
/// API Gateway)»— **caducó** con la migración a AWS: hoy son
/// `eduxaction.com` y `api.eduxaction.com`, que comparten dominio padre, así
/// que una cookie sobre `.eduxaction.com` sería perfectamente viable.
///
/// Se mantiene en `localStorage` por otro motivo: cambiar el mecanismo de
/// autenticación entrando al lanzamiento es riesgo innecesario. El control
/// compensatorio es una CSP estricta —`script-src 'self' 'wasm-unsafe-eval'
/// blob:`, **sin `unsafe-inline`**, comprobado sobre lo que sirve CloudFront—
/// que es justo lo que impide el script inyectado que leería el token.
///
/// **Revisar después del lanzamiento.** Si se hace el cambio, ese endpoint
/// necesita además `SameSite=Strict` y token anti-CSRF: hoy CSRF no aplica
/// —el refresh viaja en el cuerpo JSON y CORS va con `credentials: false`—
/// pero con cookie sí aplicaría.
/// Guardar la sesión NUNCA puede tumbar la app.
///
/// El almacenamiento no siempre está: una ventana privada, un navegador con
/// los datos de sitio bloqueados, un Llavero que el sistema no deja leer o
/// —como pasó de verdad en el recorrido de prueba— un registrante de plugins
/// desactualizado. En todos esos casos leer o escribir lanza, y si eso se
/// propaga, la PORTADA PÚBLICA se cae: no necesita sesión, pero igual pasaba
/// por acá.
///
/// Así que se degrada en silencio a "no hay sesión guardada". La consecuencia
/// para quien usa la app es que tiene que volver a entrar al recargar, que es
/// molesto pero honesto; la alternativa era una pantalla de error sin salida.
class TokenStore {
  static const _accessKey = 'enactus.accessToken';
  static const _refreshKey = 'enactus.refreshToken';

  final SessionStorage _storage;

  TokenStore({SessionStorage? storage})
      : _storage = storage ?? SessionStorage();

  /// Se recuerda que el almacenamiento falló para no reintentar —y volver a
  /// registrar el mismo error— en cada petición.
  bool _unavailable = false;

  /// Copia en memoria. Cubre el caso de una sesión que empieza con el
  /// almacenamiento roto: mientras la app siga abierta, la sesión sirve.
  String? _access;
  String? _refresh;

  Future<String?> _read(String key) async {
    if (_unavailable) return null;
    try {
      return await _storage.read(key);
    } catch (e) {
      debugPrint('TokenStore: no se puede leer la sesión guardada ($e). '
          'La sesión durará solo mientras la app siga abierta.');
      _unavailable = true;
      return null;
    }
  }

  Future<String?> readAccess() async => await _read(_accessKey) ?? _access;

  Future<String?> readRefresh() async => await _read(_refreshKey) ?? _refresh;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    if (_unavailable) return;
    try {
      await _storage.write(_accessKey, accessToken);
      await _storage.write(_refreshKey, refreshToken);
    } catch (e) {
      debugPrint('TokenStore: no se pudo guardar la sesión ($e).');
      _unavailable = true;
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    if (_unavailable) return;
    try {
      await _storage.delete(_accessKey);
      await _storage.delete(_refreshKey);
    } catch (e) {
      debugPrint('TokenStore: no se pudo limpiar la sesión ($e).');
    }
  }
}
