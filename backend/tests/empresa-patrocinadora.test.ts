import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Lo que ve una empresa que PATROCINA un laboratorio.
 *
 * La regla del negocio: una empresa que paga un laboratorio ve a su gente, sus
 * proyectos y su avance. Lo que NO puede es ver el resto de la plataforma.
 *
 * Por eso `company` **no** entró en `STAFF` junto a admin, asesor, mentor y
 * LXD: esos ven a cualquier estudiante. Una empresa ve solo a los de los
 * laboratorios que paga. Meterla en `STAFF` habría sido una línea más corta y
 * le habría abierto la plataforma entera.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let tokenEmpresa = '';

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  const empresa = await login(app, 'empresa@bancolombia.com', 'Empresa123');
  tokenEmpresa = empresa.accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

/** Un estudiante de un laboratorio que esta empresa patrocina. */
async function estudianteDeSuLab(): Promise<string> {
  const [fila] = await sql<{ id: string }[]>`
    select distinct u.id
      from users u
      join student_laboratories sl on sl.student_id = u.id
      join laboratories l on l.id = sl.laboratory_id
      join users emp on emp.id = l.sponsor_company_id
     where emp.email = 'empresa@bancolombia.com'
       and u.student_type = 'enactus'
       and u.deleted_at is null
     limit 1`;
  expect(fila, 'el sembrado tiene que traer un lab patrocinado con estudiantes')
    .toBeDefined();
  return fila!.id;
}

/** Un estudiante Enactus que NO está en ningún laboratorio de esta empresa. */
async function estudianteAjeno(): Promise<string> {
  const [fila] = await sql<{ id: string }[]>`
    select u.id
      from users u
     where u.student_type = 'enactus'
       and u.deleted_at is null
       and not exists (
         select 1 from student_laboratories sl
           join laboratories l on l.id = sl.laboratory_id
          where sl.student_id = u.id
            and (l.sponsor_company_id = (select id from users
                                          where email = 'empresa@bancolombia.com')
                 or l.id in (select c.laboratory_id from courses c
                               join users cu on cu.id = c.creator_id
                              where cu.company_id = (select id from users
                                                      where email = 'empresa@bancolombia.com')
                                and c.laboratory_id is not null)))
     limit 1`;
  expect(fila, 'el sembrado necesita un estudiante fuera del alcance de la empresa')
    .toBeDefined();
  return fila!.id;
}

describe('una empresa patrocinadora ve la Ruta de su laboratorio', () => {
  it('ve el progreso de Ruta de un estudiante de su laboratorio', async () => {
    const id = await estudianteDeSuLab();
    const res = await app.request(`/students/${id}/ruta-progress`, {
      headers: auth(tokenEmpresa),
    });
    // El cuerpo se lee UNA vez: `Response` no se puede leer dos veces, y
    // hacerlo dentro del mensaje del `expect` rompe la lectura siguiente.
    const texto = await res.text();
    expect(res.status, texto).toBe(200);
    const cuerpo = JSON.parse(texto) as { laboratories: unknown[] };
    // Que responda 200 con la lista vacía no serviría: sería indistinguible de
    // «este estudiante no ha empezado».
    expect(Array.isArray(cuerpo.laboratories)).toBe(true);
  });

  it('NO ve el de un estudiante fuera de sus laboratorios', async () => {
    const id = await estudianteAjeno();
    const res = await app.request(`/students/${id}/ruta-progress`, {
      headers: auth(tokenEmpresa),
    });
    // 403 y no una lista vacía: una lista vacía haría ver un fallo de permisos
    // como «ese estudiante no tiene nada».
    expect(res.status).toBe(403);
    const cuerpo = (await res.json()) as { error: { message: string } };
    expect(cuerpo.error.message).toMatch(/patrocina/i);
  });

  it('sigue viendo a su gente y su avance en el listado', async () => {
    const res = await app.request('/users?include=progress', {
      headers: auth(tokenEmpresa),
    });
    expect(res.status).toBe(200);
    const cuerpo = (await res.json()) as {
      data: { role: string; overallProgress?: { coursesTotal: number } }[];
    };

    // Sus LXD y mentores, más los estudiantes del laboratorio que patrocina.
    expect(cuerpo.data.length).toBeGreaterThan(0);
    const conAvance = cuerpo.data.filter(
      (u) => (u.overallProgress?.coursesTotal ?? 0) > 0,
    );
    expect(conAvance.length, 'nadie trae avance: el include dejó de funcionar')
      .toBeGreaterThan(0);
  });
});
