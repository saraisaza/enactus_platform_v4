import type { ContentfulStatusCode } from 'hono/utils/http-status';

/**
 * Error de aplicación con código HTTP y un código simbólico estable.
 *
 * El código simbólico (`not_found`, `forbidden`, …) es lo que el cliente
 * Flutter va a mirar para decidir qué hacer; el mensaje es para la persona.
 * Nunca se filtra un detalle interno de la base en `message`.
 */
export class AppError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const badRequest = (message: string, details?: unknown) =>
  new AppError(400, 'bad_request', message, details);

export const unauthorized = (message = 'Necesitás iniciar sesión.') =>
  new AppError(401, 'unauthorized', message);

export const forbidden = (message = 'No tiene permiso para esto.') =>
  new AppError(403, 'forbidden', message);

export const notFound = (message = 'No se encontró el recurso.') =>
  new AppError(404, 'not_found', message);

export const conflict = (message: string, details?: unknown) =>
  new AppError(409, 'conflict', message, details);

export const payloadTooLarge = (message: string, details?: unknown) =>
  new AppError(413, 'payload_too_large', message, details);

export const tooManyRequests = (message: string, details?: unknown) =>
  new AppError(429, 'too_many_requests', message, details);
