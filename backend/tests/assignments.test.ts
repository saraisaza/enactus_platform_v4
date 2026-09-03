import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Asignar material a un estudiante.
 *
 * Lo que más importa acá no es el código de respuesta sino el EFECTO: una
 * asignación que devuelve 200 y no cambia lo que el estudiante ve es peor que
 * un error, porque nadie la vuelve a mirar. Por eso casi cada caso termina
 * comprobando `GET /courses` con la sesión del propio estudiante, que es la
 * misma consulta que alimenta su pantalla.
 *
 * El agujero que estas pruebas cubren era real y silencioso: `student_courses`
 * existía desde la primera migración, la vista `student_course_access` la
 * leía, y ningún endpoint escribía ahí. Una cuenta de Open Learning no podía
 * recibir un curso por ningún medio salvo el sembrado.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let adminToken = '';
let lxdToken = '';
let olToken = '';
let enactusToken = '';

const EST_OL = seedId('est_ol1');
const EST_ENACTUS = seedId('est1');

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const put = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PUT' });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

/** Los ids de curso que este estudiante ve hoy en su pantalla. */
async function cursosVisibles(token: string): Promise<string[]> {
  const res = await req('/courses?pageSize=100', token);
  expect(res.status).toBe(200);
  const page = await body<{ data: { id: string }[] }>(res);
  return page.data.map((c) => c.id);
}

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  olToken = (await login(app, 'camila.rivas@gmail.com', 'Est123')).accessToken;
  enactusToken = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123'))
    .accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('GET /users/:id/assignments', () => {
  it('devuelve lo que el estudiante tiene asignado hoy', async () => {
    const res = await req(`/users/${EST_ENACTUS}/assignments`, adminToken);
    expect(res.status).toBe(200);

    const data = await body<{
      studentType: string;
      laboratoryIds: string[];
      courseIds: string[];
    }>(res);
    expect(data.studentType).toBe('enactus');
    expect(data.laboratoryIds).toHaveLength(2);
    expect(data.laboratoryIds).toContain(seedId('lab_ia'));
  });

  it('devuelve las DOS listas, no solo la del tipo de cuenta', async () => {
    // Un Enactus con filas viejas en `student_courses` no las usa, pero el
    // administrador tiene que poder verlas: es la única pista de por qué
    // alguien no ve lo que cree tener.
    const res = await req(`/users/${EST_OL}/assignments`, adminToken);
    const data = await body<{
      laboratoryIds: string[];
      courseIds: string[];
    }>(res);
    expect(data.courseIds).toEqual([seedId('crs_ol_marketing')]);
    expect(data.laboratoryIds).toEqual([]);
  });

  it('404 si el id no es de un estudiante', async () => {
    const res = await req(`/users/${seedId('lxd1')}/assignments`, adminToken);
    expect(res.status).toBe(404);
  });

  it('403 para quien no administra', async () => {
    const res = await req(`/users/${EST_OL}/assignments`, lxdToken);
    expect(res.status).toBe(403);
  });
});

describe('PUT /users/:id/courses — Open Learning', () => {
  it('el curso asignado APARECE en la pantalla del estudiante', async () => {
    // Punta a punta: antes no lo ve, se asigna, ahora sí lo ve.
    const antes = await cursosVisibles(olToken);
    expect(antes).not.toContain(seedId('crs_agua_1'));

    const res = await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing'), seedId('crs_agua_1')],
    });
    expect(res.status).toBe(200);

    const despues = await cursosVisibles(olToken);
    expect(despues).toContain(seedId('crs_agua_1'));
    expect(despues).toContain(seedId('crs_ol_marketing'));
  });

  it('quitar un curso le quita el acceso', async () => {
    await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing')],
    });
    const visibles = await cursosVisibles(olToken);
    expect(visibles).not.toContain(seedId('crs_agua_1'));
    expect(visibles).toContain(seedId('crs_ol_marketing'));
  });

  it('la lista vacía lo deja sin material, y no falla', async () => {
    const res = await put(`/users/${EST_OL}/courses`, adminToken, { ids: [] });
    expect(res.status).toBe(200);
    expect(await cursosVisibles(olToken)).toEqual([]);

    // Se restaura para no arrastrar el vacío al resto de la suite.
    await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing')],
    });
  });

  it('avisa cuáles no puede ver todavía en vez de asignarlos en silencio', async () => {
    await sql`update courses set status = 'draft' where id = ${seedId('crs_agua_1')}`;
    try {
      const res = await put(`/users/${EST_OL}/courses`, adminToken, {
        ids: [seedId('crs_ol_marketing'), seedId('crs_agua_1')],
      });
      const data = await body<{ notReady: { id: string }[] }>(res);
      expect(data.notReady.map((x) => x.id)).toEqual([seedId('crs_agua_1')]);

      // La asignación se guardó, pero el estudiante sigue sin verlo: eso es
      // justamente lo que `notReady` está avisando.
      expect(await cursosVisibles(olToken)).not.toContain(seedId('crs_agua_1'));
    } finally {
      await sql`update courses set status = 'published' where id = ${seedId('crs_agua_1')}`;
      await put(`/users/${EST_OL}/courses`, adminToken, {
        ids: [seedId('crs_ol_marketing')],
      });
    }
  });

  it('409 al asignarle cursos sueltos a un Enactus', async () => {
    // No es un capricho: `student_course_access` ni siquiera mira
    // `student_courses` para un Enactus, así que guardarlo sería un 200 que
    // no hace nada.
    const res = await put(`/users/${EST_ENACTUS}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing')],
    });
    expect(res.status).toBe(409);
    expect(await body<{ error: { message: string } }>(res)).toMatchObject({
      error: { code: 'conflict' },
    });
  });

  it('409 con un curso que ya no existe, sin tocar lo anterior', async () => {
    const res = await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing'), '00000000-0000-4000-8000-000000000123'],
    });
    expect(res.status).toBe(409);
    // Lo que tenía sigue intacto: se valida ANTES de borrar.
    expect(await cursosVisibles(olToken)).toContain(seedId('crs_ol_marketing'));
  });

  it('403 para quien no administra', async () => {
    const res = await put(`/users/${EST_OL}/courses`, lxdToken, { ids: [] });
    expect(res.status).toBe(403);
  });
});

describe('PUT /users/:id/laboratories — Enactus', () => {
  it('asignar un laboratorio da acceso a sus cursos', async () => {
    const res = await put(`/users/${EST_ENACTUS}/laboratories`, adminToken, {
      ids: [seedId('lab_ia'), seedId('lab_impacto'), seedId('lab_agua')],
    });
    expect(res.status).toBe(200);

    // El acceso al curso NO se asignó: llega por ser del laboratorio.
    expect(await cursosVisibles(enactusToken)).toContain(seedId('crs_agua_1'));
  });

  it('quitarlo se lo quita, pero su avance no se borra', async () => {
    const antes = await sql`
      select count(*)::int as n from progress
       where student_id = ${EST_ENACTUS} and course_id = ${seedId('crs_ia_1')}`;

    await put(`/users/${EST_ENACTUS}/laboratories`, adminToken, {
      ids: [seedId('lab_impacto')],
    });
    expect(await cursosVisibles(enactusToken)).not.toContain(
      seedId('crs_ia_1'),
    );

    const despues = await sql`
      select count(*)::int as n from progress
       where student_id = ${EST_ENACTUS} and course_id = ${seedId('crs_ia_1')}`;
    expect(despues[0]!.n).toBe(antes[0]!.n);

    // Y al reasignarlo lo vuelve a ver tal cual.
    await put(`/users/${EST_ENACTUS}/laboratories`, adminToken, {
      ids: [seedId('lab_ia'), seedId('lab_impacto')],
    });
    expect(await cursosVisibles(enactusToken)).toContain(seedId('crs_ia_1'));
  });

  it('409 al asignarle un laboratorio a Open Learning', async () => {
    const res = await put(`/users/${EST_OL}/laboratories`, adminToken, {
      ids: [seedId('lab_ia')],
    });
    expect(res.status).toBe(409);
    // Y sigue sin laboratorios: el rechazo es antes de escribir.
    const rows = await sql`
      select count(*)::int as n from student_laboratories
       where student_id = ${EST_OL}`;
    expect(rows[0]!.n).toBe(0);
  });

  it('409 con un laboratorio que ya no existe', async () => {
    const res = await put(`/users/${EST_ENACTUS}/laboratories`, adminToken, {
      ids: ['00000000-0000-4000-8000-000000000456'],
    });
    expect(res.status).toBe(409);
  });

  it('403 para quien no administra', async () => {
    const res = await put(`/users/${EST_ENACTUS}/laboratories`, lxdToken, {
      ids: [],
    });
    expect(res.status).toBe(403);
  });
});

describe('queda registro de quién asignó qué', () => {
  it('cada cambio deja una entrada de auditoría con el antes y el después', async () => {
    await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing'), seedId('crs_agua_1')],
    });

    const rows = await sql<{ newValue: { courseIds: string[] } }[]>`
      select new_value as "newValue" from audit_log
       where entity_id = ${EST_OL} and action = 'student.courses'
       order by created_at desc limit 1`;
    expect(rows).toHaveLength(1);
    expect(rows[0]!.newValue.courseIds).toContain(seedId('crs_agua_1'));

    await put(`/users/${EST_OL}/courses`, adminToken, {
      ids: [seedId('crs_ol_marketing')],
    });
  });
});
