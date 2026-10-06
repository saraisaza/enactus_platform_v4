/// Errores tipados de la API.
///
/// Contra Hive una lectura no podía fallar: era un mapa en memoria. Contra una
/// API sí, y de varias formas distintas que la interfaz tiene que poder
/// distinguir — no es lo mismo "no hay internet" (reintentar sirve) que "no
/// tiene permiso" (reintentar no sirve nunca).
library;

import '../l10n/textos.dart';

/// Base de todos los errores de la capa de datos.
sealed class ApiException implements Exception {
  /// Mensaje listo para mostrarle a una persona, en el idioma de la
  /// interfaz (el servidor responde en el que le pide `Accept-Language`).
  final String message;

  /// Código simbólico del backend (`forbidden`, `not_found`, …). Vacío si el
  /// error no llegó a tener respuesta (p. ej. sin red).
  final String code;

  const ApiException(this.message, {this.code = ''});

  @override
  String toString() => '$runtimeType($code): $message';
}

/// No se pudo hablar con el servidor: sin red, DNS caído, timeout.
/// Es el único caso donde reintentar la misma petición tiene sentido por sí solo.
class NetworkError extends ApiException {
  NetworkError([String? message]) : super(message ?? tr.errorSinConexion);
}

/// La sesión no vale: no hay token, expiró y el refresh también falló.
/// La interfaz debe mandar a la pantalla de ingreso.
class AuthError extends ApiException {
  AuthError([String? message])
      : super(message ?? tr.errorSesionExpirada, code: 'unauthorized');
}

/// Hay sesión, pero el rol no puede hacer eso. Reintentar nunca ayuda.
class ForbiddenError extends ApiException {
  ForbiddenError([String? message])
      : super(message ?? tr.errorSinPermiso, code: 'forbidden');
}

/// El recurso no existe — o está fuera del alcance de este rol, que el
/// servidor deliberadamente no distingue del caso anterior.
class NotFoundError extends ApiException {
  NotFoundError([String? message])
      : super(message ?? tr.errorNoEncontrado, code: 'not_found');
}

/// Los datos enviados no pasaron la validación del servidor.
class ValidationError extends ApiException {
  /// Campo → motivo, tal como los devuelve zod.
  final Map<String, String> fields;

  const ValidationError(
    super.message, {
    this.fields = const {},
    super.code = 'validation_error',
  });
}

/// El estado actual no permite la operación (409): una Ruta incompleta, un
/// curso en uso que no se puede borrar, un certificado ya emitido.
class ConflictError extends ApiException {
  /// Detalle estructurado del conflicto (qué falta, qué lo bloquea).
  final Map<String, dynamic> details;

  const ConflictError(super.message, {this.details = const {}})
      : super(code: 'conflict');
}

/// Algo falló del lado del servidor (5xx). No es culpa de quien lo usa.
///
/// **Conserva el `code` del servidor.** Antes lo fijaba en `internal_error`, y
/// eso aplastaba los 503 que el backend distingue a propósito —
/// `storage_not_configured`, `cdn_not_configured`, `storage_unavailable`, que
/// además dicen QUÉ falta— en un genérico "el servidor tuvo un problema". La
/// pantalla no podía diferenciar "esto no está configurado en este entorno"
/// (reintentar no sirve) de "se cayó un momento" (reintentar sí sirve), que es
/// justo para lo que existen los errores tipados.
class ServerError extends ApiException {
  final int status;

  ServerError(
    this.status, [
    String? message,
    String code = 'internal_error',
  ]) : super(message ?? tr.errorServidorMomento, code: code);
}
