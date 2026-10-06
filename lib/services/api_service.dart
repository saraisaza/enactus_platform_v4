import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/textos.dart';
import 'api_errors.dart';
import 'token_store.dart';
import 'upload_io.dart' if (dart.library.js_interop) 'upload_web.dart';

/// Cliente HTTP contra la API de Enactus.
///
/// Reemplaza a `DbService`: donde antes había un mapa en memoria (Hive) ahora
/// hay red, con latencia y con errores posibles. Se ocupa de tres cosas que
/// ninguna pantalla debería tener que repetir:
///
/// 1. **Inyectar el JWT** en cada petición.
/// 2. **Renovar la sesión sola** al recibir un 401, y reintentar la petición
///    original una vez. Si el refresh también falla, lanza [AuthError] y avisa
///    por [onSessionExpired] para que la app mande al ingreso.
/// 3. **Traducir la respuesta a errores tipados** (ver `api_errors.dart`), en
///    vez de dejar que cada pantalla interprete códigos HTTP.
///
/// La URL base NUNCA va escrita en el código: entra por `--dart-define`.
///
/// ```
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
/// ```
class ApiService {
  /// Origen de la API. Sin valor por defecto de producción a propósito: si
  /// falta el `--dart-define`, se apunta al backend local y se nota enseguida,
  /// en vez de pegarle sin querer a producción desde una compilación de prueba.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const _timeout = Duration(seconds: 20);

  /// El de subir archivos es más largo: son megabytes, no un JSON.
  static const _uploadTimeout = Duration(minutes: 10);

  final http.Client _client;
  final TokenStore tokens;

  /// Se dispara cuando la sesión se cayó del todo (el refresh también falló).
  /// `AuthProvider` lo usa para limpiar el estado y volver al ingreso.
  void Function()? onSessionExpired;

  ApiService({http.Client? client, TokenStore? tokenStore})
      : _client = client ?? http.Client(),
        tokens = tokenStore ?? TokenStore();

  /// Refresh en vuelo, si hay uno. Es lo que evita que tres peticiones que
  /// reciben 401 al mismo tiempo disparen tres refresh y se pisen entre sí:
  /// el primero rota el token y los otros dos, con el token viejo, harían que
  /// el servidor interprete reuso de token robado y cierre TODAS las sesiones.
  Future<bool>? _refreshInFlight;

  // -------------------------------------------------------------------------
  // Verbos
  // -------------------------------------------------------------------------

  /// [authenticated] en falso para los dos endpoints públicos (`/health` y
  /// `/site-content`): la portada se ve sin sesión, así que no tiene sentido
  /// —ni debe hacer falta— tocar el almacenamiento de tokens para pedirla.
  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, bool authenticated = true}) =>
      _send('GET', path, query: query, authenticated: authenticated);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send('DELETE', path, query: query);

  // -------------------------------------------------------------------------
  // Sesión
  // -------------------------------------------------------------------------

  /// Inicia sesión y guarda el par de tokens. Devuelve el usuario.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    final json = Map<String, dynamic>.from(data as Map);
    await tokens.save(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
    return Map<String, dynamic>.from(json['user'] as Map);
  }

  /// Usuario de la sesión guardada, o `null` si no hay o ya no vale.
  Future<Map<String, dynamic>?> restoreSession() async {
    if (await tokens.readAccess() == null) return null;
    try {
      final data = await get('/auth/me');
      return Map<String, dynamic>.from(data as Map);
    } on AuthError {
      // Ni el token ni el refresh valen: no es un error que mostrar, es
      // simplemente que no hay sesión.
      await tokens.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final refresh = await tokens.readRefresh();
    if (refresh != null) {
      try {
        await _send('POST', '/auth/logout',
            body: {'refreshToken': refresh}, authenticated: false);
      } on ApiException {
        // Cerrar sesión del lado del servidor es lo deseable, pero si falla
        // igual hay que soltar los tokens locales: lo contrario sería dejar a
        // la persona "dentro" por un problema de red.
      }
    }
    await tokens.clear();
  }

  // -------------------------------------------------------------------------
  // Subida de archivos: presigned URL → S3 directo → confirmación
  // -------------------------------------------------------------------------

  /// Sube los bytes DIRECTO a S3 con la URL firmada que dio la API.
  ///
  /// El archivo nunca pasa por la API: API Gateway corta el payload en 10 MB.
  ///
  /// [onProgress] recibe 0..1 **por bytes enviados**, no en dos saltos. No se
  /// usa `package:http` acá: en el navegador su cliente va por `fetch`, que no
  /// informa avance de envío en ningún navegador, así que la barra saltaría de
  /// 0 a 1 — inútil justo para lo que dura minutos, que es un video de 500 MB.
  /// La mitad web baja a `XMLHttpRequest` (`upload.onprogress`) y la de
  /// escritorio emite el cuerpo por trozos; ver `upload_web.dart` /
  /// `upload_io.dart`.
  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final status = await putWithProgress(
        url: Uri.parse(uploadUrl),
        bytes: bytes,
        contentType: contentType,
        timeout: _uploadTimeout,
        onProgress: onProgress,
      );

      if (status < 200 || status >= 300) {
        throw ServerError(
          status,
          tr.errorSubidaFallo(status),
        );
      }
    } on UploadTimeoutException {
      throw NetworkError(
        tr.errorSubidaLenta,
      );
    } on UploadTransportException catch (e) {
      throw NetworkError(e.message);
    }
  }

  // -------------------------------------------------------------------------
  // Interno
  // -------------------------------------------------------------------------

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool authenticated = true,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      // El servidor escribe sus mensajes (errores, validaciones) en el idioma
      // de la interfaz. Ver `backend/src/i18n`.
      'Accept-Language': Idioma.instancia.codigo,
    };
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = await tokens.readAccess();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw NetworkError(tr.errorServidorLento);
    } on http.ClientException catch (e) {
      // El detalle ("Failed host lookup…", "Connection refused") sirve para
      // depurar, no para quien usa la app: antes se le mostraba tal cual, en
      // inglés técnico.
      debugPrint('ApiService: $method $path sin conexión (${e.message}).');
      throw NetworkError();
    } on Exception catch (e) {
      // Fuera del navegador hay fallos de conexión que `package:http` no
      // envuelve en `ClientException`. El típico es `HandshakeException`: un
      // certificado que no valida porque el wifi de un campus u hotel
      // intercepta la conexión para pedir inicio de sesión. Antes se escapaba
      // y la pantalla decía "respuesta inesperada", o nada.
      debugPrint('ApiService: $method $path falló la conexión ($e).');
      throw NetworkError();
    }

    // 401: se intenta renovar UNA vez y se repite la petición original.
    if (response.statusCode == 401 && authenticated && !isRetry) {
      if (await _refreshSession()) {
        return _send(method, path,
            query: query, body: body, authenticated: true, isRetry: true);
      }
      await tokens.clear();
      onSessionExpired?.call();
      throw AuthError();
    }

    return _decode(response);
  }

  /// Renueva la sesión. Un solo refresh a la vez (ver [_refreshInFlight]).
  Future<bool> _refreshSession() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) return false;
    try {
      final data = await _send(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': refresh},
        authenticated: false,
      );
      final json = Map<String, dynamic>.from(data as Map);
      await tokens.save(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) _throwFor(response, null);
      return null;
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 400) return decoded;
    } on FormatException {
      // Respuesta que no es JSON: casi siempre una página de error de un
      // proxy o del propio API Gateway.
      if (response.statusCode < 400) {
        throw ServerError(
          response.statusCode,
          tr.errorRespuestaInesperadaServidor,
        );
      }
    }

    _throwFor(response, json);
  }

  Never _throwFor(http.Response response, Map<String, dynamic>? json) {
    final error = json?['error'] as Map?;
    final message = error?['message'] as String?;
    final code = (error?['code'] as String?) ?? '';
    final details = error?['details'];

    switch (response.statusCode) {
      case 400:
        final fields = <String, String>{};
        if (details is List) {
          for (final item in details) {
            if (item is Map) {
              fields['${item['field']}'] = '${item['message']}';
            }
          }
        }
        throw ValidationError(
          message ?? tr.errorDatosNoValidos,
          fields: fields,
          code: code.isEmpty ? 'bad_request' : code,
        );
      case 401:
        throw AuthError(message ?? tr.errorSesionExpirada);
      case 403:
        throw ForbiddenError(message ?? tr.errorSinPermiso);
      case 404:
        throw NotFoundError(message ?? tr.errorNoEncontrado);
      case 409:
        throw ConflictError(
          message ?? tr.errorOperacionNoPosible,
          details: details is Map ? Map<String, dynamic>.from(details) : const {},
        );
      case 413:
        throw ValidationError(message ?? tr.errorArchivoGrande,
            code: 'payload_too_large');
      case 429:
        throw ValidationError(
          message ?? tr.errorDemasiadosIntentos,
          code: 'too_many_requests',
        );
      default:
        // El `code` viaja hasta la pantalla: un 503 `cdn_not_configured` no se
        // arregla reintentando y un `storage_unavailable` sí, y la única forma
        // de distinguirlos es este identificador.
        if (response.statusCode >= 500) {
          throw ServerError(
            response.statusCode,
            message ?? tr.errorServidorIntente,
            code.isEmpty ? 'internal_error' : code,
          );
        }
        throw ServerError(
          response.statusCode,
          message ?? tr.errorRespuestaInesperada,
          code.isEmpty ? 'unexpected_response' : code,
        );
    }
  }

  void close() => _client.close();
}
