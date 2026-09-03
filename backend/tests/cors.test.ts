import { afterAll, describe, expect, it } from 'vitest';

import { makeTestApp } from './helpers/app';

/**
 * CORS: que la lista de métodos permitidos no se quede atrás de la API.
 *
 * Esta prueba existe por un fallo que estuvo en producción sin que ninguna de
 * las 550 pruebas del backend lo tocara: `allowMethods` no incluía `PUT`.
 *
 * Por qué se escapó, que es lo que importa para no repetirlo: las pruebas de
 * servidor usan `app.request()`, que invoca el handler directamente y **no
 * hace preflight**. Un `PUT` respondía 200 perfecto en la suite y el navegador
 * lo bloqueaba antes de enviarlo. El síntoma era "Failed to fetch" en el
 * cliente y NADA en los logs del servidor — la petición nunca llegó — que es
 * la peor combinación posible para diagnosticar.
 *
 * Se comprueban dos cosas distintas a propósito: la lista declarada frente a
 * los métodos que la aplicación registra de verdad (el desfase de fondo), y
 * un preflight real por cada método (que la cabecera salga como se espera).
 */

const { app, sql } = makeTestApp();

afterAll(async () => {
  await sql.end();
});

const ORIGEN = 'http://localhost:8080';

/** Los métodos que la aplicación realmente expone, leídos del router. */
function metodosRegistrados(): Set<string> {
  const metodos = new Set<string>();
  for (const route of app.routes) {
    // Los middlewares se registran como ALL sobre comodines: no son endpoints.
    if (route.method === 'ALL') continue;
    metodos.add(route.method.toUpperCase());
  }
  return metodos;
}

/** Preflight real: lo que un navegador manda antes de un método no simple. */
async function preflight(path: string, metodo: string): Promise<Response> {
  return await app.request(path, {
    method: 'OPTIONS',
    headers: {
      origin: ORIGEN,
      'access-control-request-method': metodo,
      'access-control-request-headers': 'authorization,content-type',
    },
  });
}

describe('CORS', () => {
  it('permite TODOS los métodos que la API expone', async () => {
    const res = await preflight('/users', 'GET');
    const permitidos = new Set(
      (res.headers.get('access-control-allow-methods') ?? '')
        .split(',')
        .map((m) => m.trim().toUpperCase())
        .filter(Boolean),
    );

    const faltantes = [...metodosRegistrados()].filter(
      (m) => !permitidos.has(m),
    );

    expect(
      faltantes,
      'métodos que la API expone pero CORS bloquea en el navegador',
    ).toEqual([]);
  });

  it('el preflight de cada método responde permitiéndolo', async () => {
    for (const metodo of [...metodosRegistrados()].sort()) {
      const res = await preflight('/users', metodo);
      expect(res.status, `preflight ${metodo}`).toBeLessThan(300);
      expect(
        res.headers.get('access-control-allow-methods') ?? '',
        `preflight ${metodo}`,
      ).toContain(metodo);
      expect(
        res.headers.get('access-control-allow-origin'),
        `preflight ${metodo}`,
      ).toBe(ORIGEN);
    }
  });

  it('un origen ajeno no recibe permiso', async () => {
    // El comodín acá permitiría que cualquier sitio llamara la API con el
    // token de la persona que lo visita.
    const res = await app.request('/users', {
      method: 'OPTIONS',
      headers: {
        origin: 'https://sitio-ajeno.example',
        'access-control-request-method': 'PUT',
      },
    });
    const permitido = res.headers.get('access-control-allow-origin');
    expect(permitido).not.toBe('*');
    expect(permitido).not.toBe('https://sitio-ajeno.example');
  });

  it('PUT está permitido — el fallo concreto que originó esta prueba', async () => {
    const res = await preflight('/users/x/courses', 'PUT');
    expect(res.headers.get('access-control-allow-methods')).toContain('PUT');
  });
});
