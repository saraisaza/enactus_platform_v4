import type { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { ZodError } from 'zod';

import { env } from '../env';
import { AppError } from '../lib/errors';

/**
 * Formato de error único para toda la API:
 *
 *   { "error": { "code": "forbidden", "message": "…", "details": … } }
 *
 * `code` es el identificador estable que el cliente Flutter mira para decidir
 * qué hacer; `message` es para la persona. Nunca sale un detalle interno de
 * PostgreSQL: un error inesperado se registra completo en el log del servidor
 * y al cliente le llega un mensaje genérico.
 */
export function onError(error: Error, c: Context): Response {
  if (error instanceof AppError) {
    return c.json(
      {
        error: {
          code: error.code,
          message: error.message,
          ...(error.details === undefined ? {} : { details: error.details }),
        },
      },
      error.status,
    );
  }

  if (error instanceof ZodError) {
    return c.json(
      {
        error: {
          code: 'validation_error',
          message: 'Los datos enviados no son válidos.',
          details: error.issues.map((i) => ({
            field: i.path.join('.'),
            message: i.message,
          })),
        },
      },
      400,
    );
  }

  if (error instanceof HTTPException) {
    return c.json(
      { error: { code: 'http_error', message: error.message } },
      error.status,
    );
  }

  // Inesperado: se registra entero acá y se responde sin detalles.
  console.error('[error no manejado]', error);
  return c.json(
    {
      error: {
        code: 'internal_error',
        message: 'Ocurrió un error inesperado.',
        ...(env.NODE_ENV === 'production'
          ? {}
          : { details: { name: error.name, message: error.message } }),
      },
    },
    500,
  );
}

export function onNotFound(c: Context): Response {
  return c.json(
    {
      error: {
        code: 'not_found',
        message: `No existe la ruta ${c.req.method} ${c.req.path}.`,
      },
    },
    404,
  );
}
