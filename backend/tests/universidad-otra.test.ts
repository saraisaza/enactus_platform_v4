import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * «Otra (¿cuál?)» en el desplegable de universidad.
 *
 * Lo que tiene que garantizar: que nadie se quede sin poder inscribirse, SIN
 * volver al texto libre que dejaba a los asesores sin ver a su gente. Lo
 * escrito se vuelve una fila del catálogo, y escribir lo mismo de otra forma
 * («universidad x», «UNIVERSIDAD X ») devuelve la misma fila.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let admin = '';
let estudiante = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, { ...init, headers: { ...(init.headers ?? {}), ...auth(token) } });

const crear = (token: string, name: string) =>
  req('/universities', token, json({ name }));

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
  admin = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  estudiante = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('Otra (¿cuál?)', () => {
  it('agrega la institución al catálogo y aparece en el desplegable', async () => {
    const res = await crear(admin, 'Institución Universitaria de Prueba');
    expect(res.status).toBe(201);
    const creada = (await res.json()) as { id: string; existente: boolean };
    expect(creada.existente).toBe(false);

    const lista = (await (await req('/universities', admin)).json()) as {
      data: { id: string; name: string }[];
    };
    expect(lista.data.find((u) => u.id === creada.id)?.name).toBe(
      'Institución Universitaria de Prueba',
    );
  });

  it('escrita de otra forma, devuelve la misma: no duplica', async () => {
    const res = await crear(admin, '  institución   universitaria de prueba ');
    expect(res.status).toBe(200);
    const misma = (await res.json()) as { name: string; existente: boolean };
    expect(misma.existente).toBe(true);
    expect(misma.name).toBe('Institución Universitaria de Prueba');
    const [n] = await sql<{ n: number }[]>`
      select count(*)::int as n from universities
       where slug = enactus_normalizar_universidad('Institución Universitaria de Prueba')`;
    expect(n!.n).toBe(1);
  });

  it('la persona inscrita con ella queda igual que con cualquier otra', async () => {
    const otra = (await (await crear(admin, 'Institución Universitaria de Prueba')).json()) as {
      id: string;
    };
    const res = await req(
      '/users',
      admin,
      json({
        name: 'Estudiante de Otra',
        email: 'otra@prueba.co',
        password: 'Clave123',
        role: 'student',
        studentType: 'enactus',
        universityId: otra.id,
      }),
    );
    expect(res.status, await res.clone().text()).toBe(201);
    // Escritura doble: el id y el texto del catálogo, no lo que alguien tecleó.
    const [fila] = await sql<{ university: string; university_id: string }[]>`
      select university, university_id from users where email = 'otra@prueba.co'`;
    expect(fila).toEqual({
      university: 'Institución Universitaria de Prueba',
      university_id: otra.id,
    });
  });

  it('una inactiva no se reactiva escribiéndola', async () => {
    await sql`insert into universities (name, slug, active)
              values ('Institución Dada de Baja', enactus_normalizar_universidad('Institución Dada de Baja'), false)`;
    expect((await crear(admin, 'institución dada de baja')).status).toBe(409);
  });

  it('un nombre vacío o de dos letras no entra', async () => {
    expect((await crear(admin, '  ')).status).toBe(400);
    expect((await crear(admin, 'UX')).status).toBe(400);
  });

  it('un estudiante no puede agregar al catálogo', async () => {
    expect((await crear(estudiante, 'Mi Universidad Inventada')).status).toBe(403);
  });
});
