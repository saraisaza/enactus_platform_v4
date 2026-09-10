import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * ¿El servidor acepta lo que el cliente MANDA?
 *
 * Esta prueba existe porque las dos suites medían lo que ellas mismas
 * enviaban, que es un circuito cerrado. El calendario no dejaba guardar ningún
 * evento y ninguna de las dos podía verlo: las pruebas del servidor armaban el
 * cuerpo con **solo el campo que ese tipo de evento usa**, mientras la
 * aplicación mandaba **los dos siempre**, con `''` en el que no aplicaba. El
 * servidor respondía 400 «Invalid UUID» y la suite del servidor seguía verde,
 * porque nunca había mandado esa forma.
 *
 * Acá el cuerpo lo pone el cliente y la validación la pone el servidor:
 *
 *   1. `GENERAR_CONTRATO=1 flutter test` graba en
 *      `test/fixtures/cuerpos_del_cliente.json` cada cuerpo que el cliente
 *      emite durante su suite —lo emite el código real, no una prueba—;
 *   2. esto lo reenvía al endpoint REAL y exige que el servidor no lo rechace
 *      por inválido.
 *
 * Lo que se comprueba NO es que la petición tenga éxito: un id inventado dará
 * 404 y una contraseña de prueba dará 401, y las dos cosas están bien. Lo que
 * no puede pasar es un **400 `validation_error`**: eso significa que cliente y
 * servidor no hablan el mismo idioma, y es invisible desde cualquiera de los
 * dos lados por separado.
 */

const CONTRATO = resolve(__dirname, '../../test/fixtures/cuerpos_del_cliente.json');

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let token = '';

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  const s = await login(app, 'superadmin1@enactus.co', 'Super123');
  token = s.accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

/** Un id que no existe. Da 404, que no es un fallo de contrato. */
const UUID = '00000000-0000-4000-8000-000000000000';

function leerContrato(): Record<string, Record<string, unknown>> {
  try {
    return JSON.parse(readFileSync(CONTRATO, 'utf8')) as Record<
      string,
      Record<string, unknown>
    >;
  } catch {
    return {};
  }
}

describe('el servidor acepta los cuerpos que arma el cliente', () => {
  it('el contrato existe y no está vacío', () => {
    const contrato = leerContrato();
    expect(
      Object.keys(contrato).length,
      `Falta ${CONTRATO} o quedó vacío. Se regenera con:\n` +
        '  GENERAR_CONTRATO=1 flutter test',
    ).toBeGreaterThan(0);
  });

  it('ningún cuerpo del cliente es rechazado por inválido', async () => {
    const contrato = leerContrato();
    const rechazados: string[] = [];

    for (const [clave, cuerpo] of Object.entries(contrato)) {
      const [metodo, plantilla] = clave.split(' ');
      const ruta = plantilla!.replace(/:id/g, UUID);
      resetRateLimits();

      const res = await app.request(ruta, {
        method: metodo,
        headers: { 'content-type': 'application/json', ...auth(token) },
        body: JSON.stringify(cuerpo),
      });

      if (res.status !== 400) continue;
      const texto = await res.text();
      if (!texto.includes('validation_error')) continue;

      rechazados.push(
        `${clave}\n      cuerpo:  ${JSON.stringify(cuerpo)}\n      dijo:    ${texto.slice(0, 260)}`,
      );
    }

    expect(
      rechazados,
      'el servidor rechazó por inválidos cuerpos que el cliente manda de ' +
        'verdad. O el cliente arma mal el cuerpo, o el esquema del servidor ' +
        'no admite la forma real. Los dos lados creen tener razón',
    ).toEqual([]);
  });

  it('el evento de calendario del cliente manda los dos ids, y se acepta', async () => {
    // El caso concreto que rompió, fijado aparte para que no se diluya en el
    // barrido: el cliente manda `courseId` y `laboratoryId` SIEMPRE, con
    // `null` en el que no aplica según el tipo.
    const contrato = leerContrato();
    const evento = contrato['POST /calendar-events'];
    expect(evento, 'el contrato no trae POST /calendar-events').toBeDefined();
    expect(Object.keys(evento!)).toContain('courseId');
    expect(Object.keys(evento!)).toContain('laboratoryId');

    resetRateLimits();
    const res = await app.request('/calendar-events', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(token) },
      body: JSON.stringify(evento),
    });
    expect(res.status, await res.text()).toBeLessThan(300);
  });
});
