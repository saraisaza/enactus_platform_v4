import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { makeTestClient, resetTestDatabase } from './helpers/db';

/**
 * Verifica que las vistas de `0001_completeness.sql` reproducen EXACTAMENTE
 * las reglas que hoy viven en `data_provider.dart` (líneas 178-311).
 *
 * No alcanza con que las vistas existan: una vista mal escrita se crea, migra
 * y devuelve resultados plausibles pero equivocados. Cada prueba de acá monta
 * un escenario concreto y comprueba el booleano contra la regla original.
 *
 * Escenario base (un laboratorio con las 3 fases):
 *   L  ── P1 ── RM1  (curso C1 + lectura propia OL1)
 *     │     └── RM2  (lectura propia OL2, módulo de mentoría)
 *     ├── P2 ── RM3  (lectura propia OL3)
 *     └── P3 ── RM4  (lectura propia OL4)
 *   C1 ── M1 ── lecciones CL1, CL2
 */

let sql: Sql;

const ids = {
  student: '',
  openLearner: '',
  lab: '',
  course: '',
  courseLesson1: '',
  courseLesson2: '',
  phase1: '',
  phase2: '',
  phase3: '',
  module1: '',
  module2: '',
  module3: '',
  module4: '',
  own1: '',
  own2: '',
  own3: '',
  own4: '',
  objectiveSinCursos: '',
  objectiveConCurso: '',
};

async function one<T extends Record<string, unknown>>(
  query: string,
): Promise<T> {
  const rows = await sql.unsafe<T[]>(query);
  const row = rows[0];
  if (!row) throw new Error(`La consulta no devolvió filas:\n${query}`);
  return row;
}

/** Marca completa una lección DE CURSO para un estudiante. */
async function completeCourseLesson(lessonId: string) {
  await sql.unsafe(`
    insert into progress (student_id, course_id)
    values ('${ids.student}', '${ids.course}')
    on conflict (student_id, course_id) do nothing
  `);
  await sql.unsafe(`
    insert into progress_lessons (progress_id, lesson_id)
    select p.id, '${lessonId}' from progress p
     where p.student_id = '${ids.student}' and p.course_id = '${ids.course}'
    on conflict do nothing
  `);
}

/** Marca completa una lectura/entrega PROPIA de un módulo de la Ruta. */
async function completeOwnLesson(lessonId: string) {
  await sql.unsafe(`
    insert into ruta_progress (student_id, laboratory_id)
    values ('${ids.student}', '${ids.lab}')
    on conflict (student_id, laboratory_id) do nothing
  `);
  await sql.unsafe(`
    insert into ruta_progress_lessons (ruta_progress_id, lesson_id)
    select rp.id, '${lessonId}' from ruta_progress rp
     where rp.student_id = '${ids.student}' and rp.laboratory_id = '${ids.lab}'
    on conflict do nothing
  `);
}

const isCourseComplete = async () =>
  (
    await one<{ is_complete: boolean }>(
      `select is_complete from course_progress
        where student_id='${ids.student}' and course_id='${ids.course}'`,
    )
  ).is_complete;

const isModuleComplete = async (moduleId: string) =>
  (
    await one<{ is_complete: boolean }>(
      `select is_complete from ruta_module_completion
        where student_id='${ids.student}' and ruta_module_id='${moduleId}'`,
    )
  ).is_complete;

const isPhaseComplete = async (phaseId: string) =>
  (
    await one<{ is_complete: boolean }>(
      `select is_complete from phase_completion
        where student_id='${ids.student}' and phase_id='${phaseId}'`,
    )
  ).is_complete;

const isRutaComplete = async () =>
  (
    await one<{ is_complete: boolean }>(
      `select is_complete from ruta_completion
        where student_id='${ids.student}' and laboratory_id='${ids.lab}'`,
    )
  ).is_complete;

beforeAll(async () => {
  await resetTestDatabase();
  sql = makeTestClient();

  ids.student = (
    await one<{ id: string }>(`
      insert into users (name, email, password_hash, role, student_type)
      values ('Estudiante Enactus', 'enactus@test.co', 'x', 'student', 'enactus')
      returning id`)
  ).id;
  ids.openLearner = (
    await one<{ id: string }>(`
      insert into users (name, email, password_hash, role, student_type)
      values ('Open Learner', 'ol@test.co', 'x', 'student', 'open_learning')
      returning id`)
  ).id;

  ids.lab = (
    await one<{ id: string }>(
      `insert into laboratories (name) values ('Laboratorio IA') returning id`,
    )
  ).id;
  await sql.unsafe(`
    insert into student_laboratories (student_id, laboratory_id)
    values ('${ids.student}', '${ids.lab}')`);

  ids.course = (
    await one<{ id: string }>(`
      insert into courses (name, laboratory_id)
      values ('Introducción a la IA', '${ids.lab}') returning id`)
  ).id;
  const courseModule = (
    await one<{ id: string }>(`
      insert into course_modules (course_id, order_index, title)
      values ('${ids.course}', 1, 'Módulo 1') returning id`)
  ).id;
  ids.courseLesson1 = (
    await one<{ id: string }>(`
      insert into lessons (course_module_id, order_index, title, type,
                           video_type, video_url)
      values ('${courseModule}', 1, '¿Qué es la IA?', 'video',
              'external', 'https://youtu.be/a') returning id`)
  ).id;
  ids.courseLesson2 = (
    await one<{ id: string }>(`
      insert into lessons (course_module_id, order_index, title, type)
      values ('${courseModule}', 2, 'Material de apoyo', 'pdf') returning id`)
  ).id;

  const phaseIds: string[] = [];
  for (const [index, title] of ['Fase 1', 'Fase 2', 'Fase 3'].entries()) {
    phaseIds.push(
      (
        await one<{ id: string }>(`
          insert into phases (laboratory_id, order_index, title)
          values ('${ids.lab}', ${index + 1}, '${title}') returning id`)
      ).id,
    );
  }
  [ids.phase1, ids.phase2, ids.phase3] = phaseIds as [string, string, string];

  const mkModule = async (phaseId: string, order: number, title: string) =>
    (
      await one<{ id: string }>(`
        insert into ruta_modules (phase_id, order_index, title)
        values ('${phaseId}', ${order}, '${title}') returning id`)
    ).id;
  const mkOwnLesson = async (moduleId: string, title: string) =>
    (
      await one<{ id: string }>(`
        insert into lessons (ruta_module_id, order_index, title, type)
        values ('${moduleId}', 1, '${title}', 'activity') returning id`)
    ).id;

  ids.module1 = await mkModule(ids.phase1, 1, 'Módulo 1');
  ids.module2 = await mkModule(ids.phase1, 2, 'Mentoría');
  ids.module3 = await mkModule(ids.phase2, 1, 'Módulo 1');
  ids.module4 = await mkModule(ids.phase3, 1, 'Módulo 1');

  ids.own1 = await mkOwnLesson(ids.module1, 'Guía de la Fase 1');
  ids.own2 = await mkOwnLesson(ids.module2, 'Confirmar asistencia');
  ids.own3 = await mkOwnLesson(ids.module3, 'Entrega Fase 2');
  ids.own4 = await mkOwnLesson(ids.module4, 'Entrega Fase 3');

  await sql.unsafe(`
    insert into ruta_module_courses (ruta_module_id, course_id)
    values ('${ids.module1}', '${ids.course}')`);

  ids.objectiveSinCursos = (
    await one<{ id: string }>(`
      insert into objectives (phase_id, category, text)
      values ('${ids.phase1}', 'entrepreneurship', 'Objetivo sin cursos')
      returning id`)
  ).id;
  ids.objectiveConCurso = (
    await one<{ id: string }>(`
      insert into objectives (phase_id, category, text)
      values ('${ids.phase1}', 'business', 'Comprender los fundamentos de la IA')
      returning id`)
  ).id;
  await sql.unsafe(`
    insert into objective_courses (objective_id, course_id)
    values ('${ids.objectiveConCurso}', '${ids.course}')`);
});

afterAll(async () => {
  await sql.end();
});

describe('acceso a cursos (regla studentHasCourse)', () => {
  it('un Enactus ve los cursos de su laboratorio sin asignárselos', async () => {
    const rows = await sql<{ course_id: string }[]>`
      select course_id from student_course_access
       where student_id = ${ids.student}
    `;
    expect(rows.map((r) => r.course_id)).toEqual([ids.course]);
  });

  it('un Open Learning NO ve los cursos de laboratorio, aunque existan', async () => {
    const rows = await sql<{ course_id: string }[]>`
      select course_id from student_course_access
       where student_id = ${ids.openLearner}
    `;
    expect(rows).toHaveLength(0);
  });

  it('un Open Learning ve solo el curso que se le asignó directamente', async () => {
    const [ol] = await sql<{ id: string }[]>`
      insert into courses (name, is_open_learning)
      values ('Marketing Digital', true) returning id
    `;
    await sql`
      insert into student_courses (student_id, course_id)
      values (${ids.openLearner}, ${ol!.id})
    `;
    const rows = await sql<{ course_id: string }[]>`
      select course_id from student_course_access
       where student_id = ${ids.openLearner}
    `;
    expect(rows.map((r) => r.course_id)).toEqual([ol!.id]);
  });
});

describe('completitud, paso a paso', () => {
  it('al principio no hay nada completo', async () => {
    expect(await isCourseComplete()).toBe(false);
    expect(await isModuleComplete(ids.module1)).toBe(false);
    expect(await isPhaseComplete(ids.phase1)).toBe(false);
    expect(await isRutaComplete()).toBe(false);
  });

  it('un curso a medias no está completo, y el avance es exacto', async () => {
    await completeCourseLesson(ids.courseLesson1);
    const row = await one<{
      ratio: string;
      completed_lessons: string;
      total_lessons: string;
      is_complete: boolean;
    }>(`select ratio, completed_lessons, total_lessons, is_complete
          from course_progress
         where student_id='${ids.student}' and course_id='${ids.course}'`);
    expect(Number(row.ratio)).toBeCloseTo(0.5);
    expect(row.completed_lessons).toBe('1');
    expect(row.total_lessons).toBe('2');
    expect(row.is_complete).toBe(false);
  });

  it('el curso se completa cuando TODAS sus lecciones están completas', async () => {
    await completeCourseLesson(ids.courseLesson2);
    expect(await isCourseComplete()).toBe(true);
  });

  it('el módulo NO se completa solo con su curso: faltan sus lecturas propias', async () => {
    // El curso ya está al 100%, pero RM1 también tiene una lectura propia.
    expect(await isModuleComplete(ids.module1)).toBe(false);
    await completeOwnLesson(ids.own1);
    expect(await isModuleComplete(ids.module1)).toBe(true);
  });

  it('la fase exige TODOS sus módulos, no solo el primero', async () => {
    expect(await isPhaseComplete(ids.phase1)).toBe(false);
    await completeOwnLesson(ids.own2);
    expect(await isPhaseComplete(ids.phase1)).toBe(true);
  });

  it('la Ruta exige las 3 fases', async () => {
    expect(await isRutaComplete()).toBe(false);
    await completeOwnLesson(ids.own3);
    expect(await isPhaseComplete(ids.phase2)).toBe(true);
    expect(await isRutaComplete()).toBe(false);
    await completeOwnLesson(ids.own4);
    expect(await isPhaseComplete(ids.phase3)).toBe(true);
    expect(await isRutaComplete()).toBe(true);
  });
});

describe('las tres reglas que no son obvias', () => {
  it('regla 1: un módulo sin nada configurado NUNCA cuenta como completo', async () => {
    // Un módulo vacío no puede verse "listo" antes de que el Admin lo
    // configure — y al agregarlo, la fase que ya estaba completa deja de
    // estarlo sola. Es exactamente el caso de la decisión B.1.
    const [vacio] = await sql<{ id: string }[]>`
      insert into ruta_modules (phase_id, order_index, title)
      values (${ids.phase3}, 2, 'Módulo sin configurar') returning id
    `;
    expect(await isModuleComplete(vacio!.id)).toBe(false);
    expect(await isPhaseComplete(ids.phase3)).toBe(false);
    expect(await isRutaComplete()).toBe(false);

    await sql`delete from ruta_modules where id = ${vacio!.id}`;
    expect(await isRutaComplete()).toBe(true);
  });

  it('regla 2: un objetivo sin cursos vinculados NUNCA se completa', async () => {
    const sinCursos = await one<{ is_complete: boolean }>(
      `select is_complete from objective_completion
        where student_id='${ids.student}' and objective_id='${ids.objectiveSinCursos}'`,
    );
    expect(sinCursos.is_complete).toBe(false);

    const conCurso = await one<{ is_complete: boolean }>(
      `select is_complete from objective_completion
        where student_id='${ids.student}' and objective_id='${ids.objectiveConCurso}'`,
    );
    expect(conCurso.is_complete).toBe(true);
  });

  it('regla 3: la completitud se deriva — agregar contenido la revierte sola', async () => {
    expect(await isCourseComplete()).toBe(true);

    const [cm] = await sql<{ id: string }[]>`
      select id from course_modules where course_id = ${ids.course} limit 1
    `;
    const [nueva] = await sql<{ id: string }[]>`
      insert into lessons (course_module_id, order_index, title, type)
      values (${cm!.id}, 3, 'Lección nueva del LXD', 'pdf') returning id
    `;

    // Sin tocar ninguna columna de progreso, el curso deja de estar completo,
    // y con él el módulo, la fase y la Ruta.
    expect(await isCourseComplete()).toBe(false);
    expect(await isModuleComplete(ids.module1)).toBe(false);
    expect(await isPhaseComplete(ids.phase1)).toBe(false);
    expect(await isRutaComplete()).toBe(false);

    await completeCourseLesson(nueva!.id);
    expect(await isRutaComplete()).toBe(true);
  });
});

describe('desbloqueo de fases', () => {
  it('la fase 1 siempre está desbloqueada; las demás exigen la anterior', async () => {
    // Un estudiante nuevo, sin nada hecho, en el mismo laboratorio.
    const [nuevo] = await sql<{ id: string }[]>`
      insert into users (name, email, password_hash, role, student_type)
      values ('Recién llegado', 'nuevo@test.co', 'x', 'student', 'enactus')
      returning id
    `;
    await sql`
      insert into student_laboratories (student_id, laboratory_id)
      values (${nuevo!.id}, ${ids.lab})
    `;

    const rows = await sql<{ order_index: number; is_unlocked: boolean }[]>`
      select p.order_index, pu.is_unlocked
        from phase_unlocked pu
        join phases p on p.id = pu.phase_id
       where pu.student_id = ${nuevo!.id}
       order by p.order_index
    `;
    expect(rows.map((r) => r.is_unlocked)).toEqual([true, false, false]);

    // Y para quien ya completó todo, las tres están desbloqueadas.
    const mias = await sql<{ is_unlocked: boolean }[]>`
      select pu.is_unlocked
        from phase_unlocked pu
        join phases p on p.id = pu.phase_id
       where pu.student_id = ${ids.student}
       order by p.order_index
    `;
    expect(mias.map((r) => r.is_unlocked)).toEqual([true, true, true]);
  });
});

describe('guardia del certificado (validada en la base, no en la pantalla)', () => {
  it('rechaza el certificado si la Ruta no está completa', async () => {
    const [otro] = await sql<{ id: string }[]>`
      insert into users (name, email, password_hash, role, student_type)
      values ('Sin terminar', 'sinterminar@test.co', 'x', 'student', 'enactus')
      returning id
    `;
    await sql`
      insert into student_laboratories (student_id, laboratory_id)
      values (${otro!.id}, ${ids.lab})
    `;

    let message = '';
    try {
      await sql.unsafe(`
        insert into certificates (code, student_id, laboratory_id,
          student_name_snapshot, laboratory_name_snapshot, issuer_name_snapshot,
          requirements_snapshot)
        values ('ENC-2026-90001', '${otro!.id}', '${ids.lab}',
                'Sin terminar', 'Laboratorio IA', 'LXD', '{}'::jsonb)
      `);
    } catch (error) {
      message = error instanceof Error ? error.message : String(error);
    }
    expect(message).toContain('no está completa');
  });

  it('acepta el certificado de quien sí completó las 3 fases', async () => {
    expect(await isRutaComplete()).toBe(true);
    await sql.unsafe(`
      insert into certificates (code, student_id, laboratory_id,
        student_name_snapshot, laboratory_name_snapshot, issuer_name_snapshot,
        requirements_snapshot)
      values ('ENC-2026-90002', '${ids.student}', '${ids.lab}',
              'Estudiante Enactus', 'Laboratorio IA', 'LXD', '{}'::jsonb)
    `);
    const row = await one<{ code: string }>(
      `select code from certificates where student_id='${ids.student}'`,
    );
    expect(row.code).toBe('ENC-2026-90002');
  });

  it('no permite dos certificados del mismo laboratorio para la misma persona', async () => {
    let message = '';
    try {
      await sql.unsafe(`
        insert into certificates (code, student_id, laboratory_id,
          student_name_snapshot, laboratory_name_snapshot, issuer_name_snapshot,
          requirements_snapshot)
        values ('ENC-2026-90003', '${ids.student}', '${ids.lab}',
                'Estudiante Enactus', 'Laboratorio IA', 'LXD', '{}'::jsonb)
      `);
    } catch (error) {
      message = error instanceof Error ? error.message : String(error);
    }
    expect(message).toContain('certificates_student_lab_unique');
  });
});
