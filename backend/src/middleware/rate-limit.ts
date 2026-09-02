import { createMiddleware } from 'hono/factory';

import { tooManyRequests } from '../lib/errors';
import type { AppEnv } from './context';

/**
 * Límite de intentos por ventana deslizante, en memoria del proceso.
 *
 * LIMITACIÓN REAL, no un detalle: en Lambda cada instancia tiene su propia
 * memoria, así que con N instancias vivas el límite efectivo es N veces el
 * configurado. Esto frena un ataque de fuerza bruta ingenuo desde una sola
 * IP, no uno distribuido. El límite de verdad va en API Gateway (throttling)
 * o en WAF, y queda anotado para la Fase 6.
 *
 * Se implementa igual porque es la diferencia entre "cualquiera puede probar
 * mil contraseñas por segundo contra un correo conocido" y "no puede".
 */
interface Bucket {
  hits: number[];
}

const buckets = new Map<string, Bucket>();

/** Solo para las pruebas: limpia el estado entre casos. */
export function resetRateLimits(): void {
  buckets.clear();
}

export function rateLimit(options: {
  max: number;
  windowMs: number;
  /**
   * Si la clave necesita mirar el cuerpo. `false` en el límite general: es
   * middleware global y la mayoría de las peticiones son GET sin cuerpo —
   * intentar parsearlo en cada una sería trabajo puro por nada.
   */
  readsBody?: boolean;
  /** Cómo se agrupa: por IP, o por IP + correo del cuerpo. */
  keyOf: (c: { get: (k: 'requestIp') => string }, body: unknown) => string;
}) {
  return createMiddleware<AppEnv>(async (c, next) => {
    // El cuerpo se lee acá y se cachea: Hono permite volver a leerlo después.
    let body: unknown = undefined;
    if (options.readsBody !== false) {
      try {
        body = await c.req.json();
      } catch {
        // Sin cuerpo JSON: se limita solo por IP. No es un error todavía —
        // la validación con zod lo va a rechazar más adelante con su mensaje.
        body = undefined;
      }
    }

    const key = options.keyOf(c, body);
    const now = Date.now();
    const bucket = buckets.get(key) ?? { hits: [] };
    bucket.hits = bucket.hits.filter((t) => now - t < options.windowMs);

    if (bucket.hits.length >= options.max) {
      const oldest = bucket.hits[0] ?? now;
      const retryAfter = Math.ceil(
        (options.windowMs - (now - oldest)) / 1000,
      );
      buckets.set(key, bucket);
      throw tooManyRequests(
        'Demasiados intentos. Esperá un momento antes de reintentar.',
        { retryAfterSeconds: retryAfter },
      );
    }

    bucket.hits.push(now);
    buckets.set(key, bucket);
    await next();
  });
}
