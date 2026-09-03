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

  // Un id mal formado en la URL (`/lessons/no-es-un-uuid`) llegaba hasta
  // PostgreSQL y volvía como 500 «error inesperado»: código equivocado —no
  // pasó nada inesperado, el id no vale— y ruido en el log de errores, que es
  // donde se miran los problemas de verdad.
  //
  // Se responde 404 y no 400 por coherencia con el resto de la API: un id
  // fuera de alcance también da 404, así que un 400 acá permitiría distinguir
  // "ese id no existe" de "ese id existe pero no es suyo" solo por la forma.
  if (isInvalidTextRepresentation(error)) {
    return c.json(
      {
        error: {
          code: 'not_found',
          message: 'No encontramos lo que busca: el identificador no es válido.',
        },
      },
      404,
    );
  }

  // Cuerpo que no es JSON válido. Es un error de QUIEN LLAMA, no una caída:
  // devolvía 500 «error inesperado», y eso tiene dos costos concretos —
  // ensucia la tasa de 5xx, que es la señal sobre la que se van a montar las
  // alarmas, y una alarma que suena por el JSON mal armado de un cliente
  // enseña a ignorarla. Se responde 400, como cualquier otro dato inválido.
  if (esJsonMalFormado(error)) {
    return c.json(
      {
        error: {
          code: 'invalid_json',
          message: 'El cuerpo de la petición no es JSON válido.',
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

/**
 * ¿El cuerpo venía mal armado?
 *
 * `c.req.json()` levanta un `SyntaxError` cuando el JSON no parsea. Se exige
 * además que el mensaje hable de JSON: `SyntaxError` a secas también lo lanza
 * un bug nuestro, y ese sí tiene que seguir siendo un 500 ruidoso — degradarlo
 * a 400 escondería un error real detrás de un código que nadie mira.
 */
function esJsonMalFormado(error: unknown): boolean {
  return (
    error instanceof SyntaxError &&
    /JSON|Unexpected (token|end of)/i.test(error.message)
  );
}

/**
 * ¿Es el `22P02` de PostgreSQL (*invalid_text_representation*)?
 *
 * Se comprueba SOLO ese SQLSTATE, no cualquier error de base: mapear más
 * ampliamente convertiría fallos reales en 404 silenciosos, que es peor que un
 * 500 honesto. Drizzle envuelve el error de `postgres`, así que hay que
 * recorrer la cadena de `cause`.
 */
function isInvalidTextRepresentation(error: unknown): boolean {
  for (let actual: unknown = error, saltos = 0; actual && saltos < 5; saltos++) {
    if (
      typeof actual === 'object' &&
      'code' in actual &&
      (actual as { code?: unknown }).code === '22P02'
    ) {
      return true;
    }
    actual = (actual as { cause?: unknown }).cause;
  }
  return false;
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
