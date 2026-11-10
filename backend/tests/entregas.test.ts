import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Las entregas con fecha (pedido de Sara, 2026-11-10).
 *
 * El calendario del estudiante solo mostraba los eventos que alguien
 * agendaba. Las fechas límite —de una actividad de un curso, de una fase de
 * un laboratorio— existían, pero no aparecían en ningún calendario, y el
 * inicio no sabía decir «tiene una entrega esta semana».
 *
 * `GET /calendar-events/entregas` las junta: cada quien recibe las suyas y
 * solo las suyas, con `done` cuando ya entregó.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
const tok: Record<string, string> = {};

const CURSO_IA = seedId('crs_ia_1'); // lab_ia: lo cursa est1, no est3
const ACTIVIDAD_IA = seedId('lia5'); // actividad de crs_ia_1
const ASISTENCIA = seedId('lab_ia_fase1_mod2_asistencia'); // entrega propia de la Ruta
const LAB_IA = seedId('lab_ia');

interface Entrega {
  kind: string;
  id: string;
  title: string;
  dueDate: string;
  done: boolean;
  courseId: string | null;
  courseName: string | null;
  laboratoryId: string | null;
  laboratoryName: string | null;
  phaseOrder: number | null;
}

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

async function entregasDe(quien: string): Promise<Entrega[]> {
  const res = await pedir('/calendar-events/entregas', 'GET', tok[quien]!);
  expect(res.status, await res.clone().text()).toBe(200);
  return ((await res.json()) as { data: Entrega[] }).data;
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  for (const [clave, correo, clave2] of [
    ['est1', 'estudiante1@uniandes.edu.co', 'Est123'], // lab_ia y lab_impacto
    ['est3', 'estudiante3@unal.edu.co', 'Est123'], // lab_agua y lab_agricultura
    ['abierta', 'camila.rivas@gmail.com', 'Est123'], // Open Learning: marketing
    ['lxdIa', 'lxd.ia@enactus.co', 'Lxd123'],
    ['admin', 'admin@enactus.co', 'Admin123'],
  ] as const) {
    tok[clave] = (await login(t.app, correo, clave2)).accessToken;
  }
  // El sembrado trae a est1 con esta actividad ya hecha: se parte de cero,
  // para que la prueba no dependa de lo que el sembrado decida mañana.
  const EST1 = seedId('est1');
  await sql`delete from progress_lessons pl using progress p
             where pl.progress_id = p.id and p.student_id = ${EST1}
               and pl.lesson_id = ${ACTIVIDAD_IA}`;
  await sql`delete from submissions where student_id = ${EST1} and lesson_id = ${ACTIVIDAD_IA}`;
  // El sembrado no trae fechas en las actividades: se ponen acá.
  await sql`update lesson_activities set deadline = '2026-11-12' where lesson_id = ${ACTIVIDAD_IA}`;
  await sql`update lesson_activities set deadline = '2026-11-20' where lesson_id = ${ASISTENCIA}`;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('las entregas de un curso', () => {
  it('quien cursa el curso recibe la actividad con su fecha', async () => {
    const actividad = (await entregasDe('est1')).find((e) => e.id === ACTIVIDAD_IA);
    expect(actividad).toMatchObject({
      kind: 'course_activity',
      title: 'Proyecto: IA para su comunidad',
      dueDate: '2026-11-12',
      done: false,
      courseId: CURSO_IA,
      laboratoryId: LAB_IA,
    });
    expect(actividad!.courseName).toBeTruthy();
    expect(actividad!.laboratoryName).toBeTruthy();
  });

  it('quien no lo cursa no la recibe', async () => {
    expect((await entregasDe('est3')).map((e) => e.id)).not.toContain(ACTIVIDAD_IA);
  });

  it('una actividad sin fecha no es una entrega con fecha', async () => {
    await sql`update lesson_activities set deadline = null where lesson_id = ${ACTIVIDAD_IA}`;
    expect((await entregasDe('est1')).map((e) => e.id)).not.toContain(ACTIVIDAD_IA);
    await sql`update lesson_activities set deadline = '2026-11-12' where lesson_id = ${ACTIVIDAD_IA}`;
  });

  it('un curso en borrador no recuerda nada: para el estudiante no existe', async () => {
    await sql`update courses set status = 'draft' where id = ${CURSO_IA}`;
    expect((await entregasDe('est1')).map((e) => e.id)).not.toContain(ACTIVIDAD_IA);
    await sql`update courses set status = 'published' where id = ${CURSO_IA}`;
    expect((await entregasDe('est1')).map((e) => e.id)).toContain(ACTIVIDAD_IA);
  });

  it('al entregar queda hecha, sin esperar la nota', async () => {
    const res = await pedir('/submissions', 'POST', tok.est1!, {
      courseId: CURSO_IA,
      lessonId: ACTIVIDAD_IA,
      taskName: 'Proyecto: IA para su comunidad',
      comment: 'Mi propuesta.',
      files: [{
        s3Key: 'entregas/propuesta.pdf', fileName: 'propuesta.pdf',
        contentType: 'application/pdf', sizeBytes: 1024,
      }],
    });
    expect(res.status, await res.clone().text()).toBe(201);
    const actividad = (await entregasDe('est1')).find((e) => e.id === ACTIVIDAD_IA);
    expect(actividad!.done).toBe(true);
  });
});

describe('las entregas de un laboratorio', () => {
  it('las fases con fecha de sus laboratorios, con su número', async () => {
    const fases = (await entregasDe('est1')).filter((e) => e.kind === 'lab_phase');
    // El sembrado le pone fecha a las fases 1 y 2 del laboratorio de IA.
    expect(fases.map((f) => [f.laboratoryId, f.phaseOrder, f.dueDate])).toEqual([
      [LAB_IA, 1, '2026-07-01'],
      [LAB_IA, 2, '2026-08-02'],
    ]);
    expect(fases.every((f) => f.courseId === null && f.done === false)).toBe(true);
  });

  it('la entrega propia de un módulo de la Ruta', async () => {
    const asistencia = (await entregasDe('est1')).find((e) => e.id === ASISTENCIA);
    expect(asistencia).toMatchObject({
      kind: 'lab_activity', dueDate: '2026-11-20', laboratoryId: LAB_IA, phaseOrder: 1,
    });
  });

  it('nada de un laboratorio que no es suyo', async () => {
    const ajenas = (await entregasDe('est3')).filter((e) => e.laboratoryId === LAB_IA);
    expect(ajenas).toEqual([]);
  });
});

describe('quién las recibe', () => {
  it('llegan en orden de fecha', async () => {
    const fechas = (await entregasDe('est1')).map((e) => e.dueDate);
    expect(fechas).toEqual([...fechas].sort());
    expect(fechas.length).toBeGreaterThanOrEqual(4);
  });

  it('un Open Learning solo las de sus cursos, nunca de un laboratorio', async () => {
    const [leccion] = await sql<{ id: string }[]>`
      insert into lessons (course_module_id, order_index, title, type)
      select cm.id, 90, 'Plan de marketing', 'activity'
        from course_modules cm where cm.course_id = ${seedId('crs_ol_marketing')}
       order by cm.order_index limit 1
      returning id`;
    await sql`insert into lesson_activities (lesson_id, deadline)
              values (${leccion!.id}, '2026-11-14')`;
    const suyas = await entregasDe('abierta');
    expect(suyas.map((e) => [e.kind, e.title, e.dueDate, e.laboratoryId])).toEqual([
      ['course_activity', 'Plan de marketing', '2026-11-14', null],
    ]);
  });

  it('quien no estudia recibe la lista vacía, no un error', async () => {
    expect(await entregasDe('lxdIa')).toEqual([]);
    expect(await entregasDe('admin')).toEqual([]);
  });

  it('sin sesión: 401', async () => {
    const res = await t.app.request('/calendar-events/entregas');
    expect(res.status).toBe(401);
  });
});
