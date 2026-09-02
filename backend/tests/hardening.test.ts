import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Endurecimiento de la API (Fase 6, sección 4).
 *
 * Estas comprobaciones existen porque **el default no alcanza**: Hono trae
 * `secureHeaders()` con valores razonables, pero sin CSP y con
 * `X-Frame-Options: SAMEORIGIN`. Verificar la configuración leyendo el código
 * no sirve — lo que importa es lo que sale por el cable.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const cabeceras = async (path = '/health') =>
  (await app.request(path)).headers;

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
});

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('cabeceras de seguridad', () => {
  it('X-Frame-Options es DENY, no el SAMEORIGIN por defecto', async () => {
    const h = await cabeceras();
    expect(h.get('x-frame-options')).toBe('DENY');
  });

  it('hay Content-Security-Policy y prohíbe todo', async () => {
    // `secureHeaders()` no pone ninguna por defecto. Esta API devuelve JSON:
    // la política correcta es la más cerrada que existe.
    const csp = (await cabeceras()).get('content-security-policy');
    expect(csp).toBeTruthy();
    expect(csp).toContain("default-src 'none'");
    expect(csp).toContain("frame-ancestors 'none'");
  });

  it('HSTS es de al menos un año', async () => {
    // Un año es el mínimo que exige la lista de precarga de los navegadores;
    // el default de Hono son 180 días.
    const hsts = (await cabeceras()).get('strict-transport-security') ?? '';
    const maxAge = Number(/max-age=(\d+)/.exec(hsts)?.[1] ?? 0);
    expect(maxAge).toBeGreaterThanOrEqual(31536000);
    expect(hsts).toContain('includeSubDomains');
  });

  it('nosniff y referrer-policy', async () => {
    const h = await cabeceras();
    expect(h.get('x-content-type-options')).toBe('nosniff');
    expect(h.get('referrer-policy')).toBeTruthy();
  });

  it('las cabeceras también salen en una respuesta de ERROR', async () => {
    // Un 404 lo arma `onNotFound`, por otro camino que una respuesta normal.
    // Si las cabeceras se perdieran ahí, se perderían justo en las respuestas
    // que un atacante provoca a propósito.
    const res = await app.request('/no-existe');
    expect(res.status).toBe(404);
    expect(res.headers.get('x-frame-options')).toBe('DENY');
    expect(res.headers.get('content-security-policy')).toBeTruthy();
  });
});

describe('CORS', () => {
  it('no responde con comodín', async () => {
    const res = await app.request('/health', {
      headers: { Origin: 'https://sitio-cualquiera.com' },
    });
    expect(res.headers.get('access-control-allow-origin')).not.toBe('*');
  });

  it('un origen desconocido no queda autorizado', async () => {
    const res = await app.request('/health', {
      headers: { Origin: 'https://sitio-cualquiera.com' },
    });
    expect(res.headers.get('access-control-allow-origin')).not.toBe(
      'https://sitio-cualquiera.com',
    );
  });
});

describe('límite moderado en toda la API', () => {
  it('cada IP tiene su propio cupo', async () => {
    // Esto atrapa un error real que cometí: el middleware quedó registrado
    // ANTES del que fija `requestIp`, así que la clave era `api:undefined`
    // para todo el mundo — un solo cupo compartido por todos los clientes en
    // vez de uno por IP. Con el orden mal, agotar el de una IP agota el de
    // todas y esta prueba falla.
    const pedir = (ip: string) =>
      app.request('/health', { headers: { 'x-forwarded-for': ip } });

    for (let i = 0; i < 300; i++) {
      await pedir('203.0.113.7');
    }
    expect((await pedir('203.0.113.7')).status).toBe(429);

    // Otra IP no debería estar afectada.
    expect((await pedir('198.51.100.9')).status).toBe(200);
  });

  it('el 429 dice cuánto esperar', async () => {
    const pedir = () =>
      app.request('/health', { headers: { 'x-forwarded-for': '203.0.113.8' } });
    for (let i = 0; i < 300; i++) await pedir();

    const res = await pedir();
    expect(res.status).toBe(429);
    const body = (await res.json()) as {
      error: { code: string; details?: { retryAfterSeconds?: number } };
    };
    expect(body.error.code).toBe('too_many_requests');
    expect(body.error.details?.retryAfterSeconds).toBeGreaterThan(0);
  });

  it('el de login sigue siendo MUCHO más estricto', async () => {
    // 10 por correo cada 5 minutos: el límite general de 300/min no lo
    // reemplaza, porque contra una cuenta conocida 300 intentos por minuto
    // sería exactamente el ataque que hay que frenar.
    const intentar = () =>
      app.request('/auth/login', {
        ...json({ email: 'estudiante1@uniandes.edu.co', password: 'mala' }),
        headers: {
          'content-type': 'application/json',
          'x-forwarded-for': '203.0.113.10',
        },
      });

    let cortado = 0;
    for (let i = 0; i < 15; i++) {
      if ((await intentar()).status === 429) cortado = i;
      if (cortado) break;
    }
    expect(cortado).toBeGreaterThan(0);
    expect(cortado).toBeLessThan(15);
  });
});

describe('los errores no filtran nada de adentro', () => {
  it('un id mal formado no devuelve SQL ni nombres de tabla', async () => {
    const token = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
    const res = await app.request('/courses/no-es-un-uuid', {
      headers: auth(token),
    });
    const texto = await res.text();

    expect(res.status).toBe(404);
    for (const filtracion of ['select ', 'from "', 'pg_', 'node_modules', '/var/task']) {
      expect(texto.toLowerCase()).not.toContain(filtracion);
    }
  });

  it('un 401 no dice si la cuenta existe', async () => {
    const inexistente = await app.request(
      '/auth/login',
      json({ email: 'nadie@enactus.co', password: 'x' }),
    );
    const existente = await app.request(
      '/auth/login',
      json({ email: 'admin@enactus.co', password: 'incorrecta' }),
    );
    expect(inexistente.status).toBe(existente.status);
    expect(await inexistente.text()).toBe(await existente.text());
  });
});
