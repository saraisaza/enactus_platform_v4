import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { auth, json, login, makeTestApp } from './helpers/app';
import { makeTestClient, seedTestDatabase } from './helpers/db';

/**
 * R2 — escritura doble de universidad.
 *
 * Vive en su propio archivo y no junto a las pruebas del relleno porque
 * necesita el sembrado COMPLETO, y aquellas limpian tablas entre casos para
 * poder montar cada escenario de cero. Mezclar los dos regímenes de limpieza
 * dejaba la base a medias y rompía con un CHECK de `submissions` — una prueba
 * roja por el montaje, no por lo que dice medir, que es la peor clase de
 * prueba roja.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let tokenAdmin = '';

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = makeTestClient();
  await seedTestDatabase();
  const admin = await login(app, 'admin@enactus.co', 'Admin123');
  tokenAdmin = admin.accessToken;
}, 120_000);

afterAll(async () => {
  await sql.end();
});

const cabeceras = () => ({
  ...(json({}).headers as Record<string, string>),
  ...auth(tokenAdmin),
});

describe('escritura doble: las dos columnas dicen lo mismo (R2)', () => {
  /**
   * La condición literal para poder desplegar R3.
   *
   * Hasta R3 la visibilidad del asesor compara TEXTO. Escribir solo el id
   * dejaría al estudiante con universidad puesta y aun así invisible para su
   * asesor; escribir solo el texto —lo de antes— deja el id vacío, y entonces
   * R3 lo haría desaparecer. Las dos tienen que decir lo mismo en todo
   * momento.
   */
  it('mandar universityId escribe también el texto, del catálogo', async () => {
    const [uni] = await sql<{ id: string; name: string }[]>`
      select id, name from universities where active and slug <> 'sin asignar' limit 1`;

    const res = await app.request('/users', {
      ...json({
        name: 'Nueva Persona',
        email: 'nueva.persona@ejemplo.test',
        password: 'unaClaveLarga1',
        role: 'student',
        studentType: 'enactus',
        universityId: uni!.id,
        // Se manda texto CONTRADICTORIO a propósito: tiene que ganar el
        // catálogo. Si ganara lo que manda el cliente, el campo de texto libre
        // seguiría vivo por la puerta de atrás.
        university: 'Lo Que Sea Que Yo Escriba',
      }),
      headers: cabeceras(),
    });
    expect(res.status, await res.text()).toBeLessThan(300);

    const [fila] = await sql<{ university: string; university_id: string }[]>`
      select university, university_id from users where email = 'nueva.persona@ejemplo.test'`;
    expect(fila!.university_id).toBe(uni!.id);
    expect(fila!.university).toBe(uni!.name);
  });

  it('una universidad inactiva se rechaza al asignar', async () => {
    const [inactiva] = await sql<{ id: string }[]>`
      insert into universities (name, slug, active)
      values ('Inactiva de prueba', 'inactiva de prueba', false)
      on conflict do nothing returning id`;
    const uni =
      inactiva ??
      (await sql<{ id: string }[]>`
        select id from universities where slug = 'inactiva de prueba'`)[0];

    const res = await app.request('/users', {
      ...json({
        name: 'Otra Persona',
        email: 'otra.persona@ejemplo.test',
        password: 'unaClaveLarga1',
        role: 'student',
        studentType: 'enactus',
        universityId: uni!.id,
      }),
      headers: cabeceras(),
    });
    // 409 y no 404: la universidad existe, lo que no admite es una asignación
    // nueva. Decir «no existe» mandaría a buscar un problema que no es.
    expect(res.status).toBe(409);
    const cuerpo = (await res.json()) as { error: { message: string } };
    expect(cuerpo.error.message).toMatch(/inactiva/i);

    const quedo = await sql`select 1 from users where email = 'otra.persona@ejemplo.test'`;
    expect(quedo.length).toBe(0);
  });
});
