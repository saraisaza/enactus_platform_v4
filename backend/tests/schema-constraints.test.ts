import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { makeTestClient, resetTestDatabase } from './helpers/db';

/**
 * El esquema tiene que hacer cumplir sus propias reglas, no confiar en que la
 * aplicación las respete. Cada prueba de acá ataca una restricción concreta
 * con datos que DEBEN ser rechazados por PostgreSQL.
 *
 * Sin esto, "puse un CHECK" es una afirmación sin verificar: un CHECK mal
 * escrito compila, migra y no rechaza nada.
 */

let sql: Sql;

/** Falla si la sentencia NO revienta, y devuelve el mensaje si revienta. */
async function expectRejected(statement: string): Promise<string> {
  try {
    await sql.unsafe(statement);
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
  throw new Error(
    `La base ACEPTÓ una fila que debía rechazar:\n${statement.trim()}`,
  );
}

beforeAll(async () => {
  await resetTestDatabase();
  sql = makeTestClient();
});

afterAll(async () => {
  await sql.end();
});

describe('users', () => {
  it('exige student_type en student/alumni y lo prohíbe en el resto', async () => {
    // Un estudiante sin tipo: no se puede saber si ve la Ruta de Impacto.
    const sinTipo = await expectRejected(`
      insert into users (name, email, password_hash, role)
      values ('Sin tipo', 'sintipo@test.co', 'x', 'student')
    `);
    expect(sinTipo).toContain('users_student_type_matches_role');

    // Un admin con tipo de estudiante: no significa nada.
    const adminConTipo = await expectRejected(`
      insert into users (name, email, password_hash, role, student_type)
      values ('Admin raro', 'adminraro@test.co', 'x', 'admin', 'enactus')
    `);
    expect(adminConTipo).toContain('users_student_type_matches_role');

    await sql.unsafe(`
      insert into users (name, email, password_hash, role, student_type)
      values ('Ana', 'ana@test.co', 'x', 'student', 'enactus')
    `);
    const [row] = await sql<{ student_type: string }[]>`
      select student_type from users where email = 'ana@test.co'
    `;
    expect(row?.student_type).toBe('enactus');
  });

  it('no permite dos cuentas que solo difieren en mayúsculas', async () => {
    await sql.unsafe(`
      insert into users (name, email, password_hash, role)
      values ('Admin', 'Admin@Enactus.co', 'x', 'admin')
    `);
    const dup = await expectRejected(`
      insert into users (name, email, password_hash, role)
      values ('Otro', 'admin@enactus.co', 'x', 'admin')
    `);
    expect(dup).toContain('users_email_lower_unique');
  });

  it('reserva impact_code para el rol donor', async () => {
    const noDonante = await expectRejected(`
      insert into users (name, email, password_hash, role, impact_code)
      values ('Falso donante', 'falso@test.co', 'x', 'advisor', 'ENACTUS-2026-1')
    `);
    expect(noDonante).toContain('users_impact_code_only_donor');

    await sql.unsafe(`
      insert into users (name, email, password_hash, role, impact_code)
      values ('Fundación', 'donante@test.co', 'x', 'donor', 'ENACTUS-2026-1')
    `);
    const dup = await expectRejected(`
      insert into users (name, email, password_hash, role, impact_code)
      values ('Otra', 'donante2@test.co', 'x', 'donor', 'ENACTUS-2026-1')
    `);
    expect(dup).toContain('users_impact_code_unique');
  });

  it('deja can_grade con los defaults reales del código Flutter', async () => {
    await sql.unsafe(`
      insert into users (name, email, password_hash, role)
      values ('LXD nuevo', 'lxd.defaults@test.co', 'x', 'lxd')
    `);
    const [row] = await sql<
      { can_grade_open_learning: boolean; can_grade_enactus: boolean }[]
    >`
      select can_grade_open_learning, can_grade_enactus
      from users where email = 'lxd.defaults@test.co'
    `;
    // Open Learning activo (el LXD es el docente), Enactus desactivado.
    expect(row?.can_grade_open_learning).toBe(true);
    expect(row?.can_grade_enactus).toBe(false);
  });
});

describe('lessons', () => {
  let courseModuleId = '';
  let rutaModuleId = '';

  beforeAll(async () => {
    const [lab] = await sql<{ id: string }[]>`
      insert into laboratories (name) values ('Lab prueba') returning id
    `;
    const [phase] = await sql<{ id: string }[]>`
      insert into phases (laboratory_id, order_index, title)
      values (${lab!.id}, 1, 'Fase 1') returning id
    `;
    const [rm] = await sql<{ id: string }[]>`
      insert into ruta_modules (phase_id, order_index, title)
      values (${phase!.id}, 1, 'Módulo 1') returning id
    `;
    const [course] = await sql<{ id: string }[]>`
      insert into courses (name) values ('Curso prueba') returning id
    `;
    const [cm] = await sql<{ id: string }[]>`
      insert into course_modules (course_id, order_index, title)
      values (${course!.id}, 1, 'Módulo 1') returning id
    `;
    rutaModuleId = rm!.id;
    courseModuleId = cm!.id;
  });

  it('exige exactamente un padre (módulo de curso o módulo de Ruta)', async () => {
    const huerfana = await expectRejected(`
      insert into lessons (title, type) values ('Huérfana', 'pdf')
    `);
    expect(huerfana).toContain('lessons_exactly_one_parent');

    const dosPadres = await expectRejected(`
      insert into lessons (title, type, course_module_id, ruta_module_id)
      values ('Dos padres', 'pdf', '${courseModuleId}', '${rutaModuleId}')
    `);
    expect(dosPadres).toContain('lessons_exactly_one_parent');
  });

  it('exige coherencia entre video_type y su origen', async () => {
    const externalSinUrl = await expectRejected(`
      insert into lessons (title, type, course_module_id, video_type)
      values ('Sin URL', 'video', '${courseModuleId}', 'external')
    `);
    expect(externalSinUrl).toContain('lessons_video_source');

    const uploadedSinKey = await expectRejected(`
      insert into lessons (title, type, course_module_id, video_type)
      values ('Sin key', 'video', '${courseModuleId}', 'uploaded')
    `);
    expect(uploadedSinKey).toContain('lessons_video_source');

    // Los dos orígenes a la vez: ambiguo, ¿cuál se reproduce?
    const ambos = await expectRejected(`
      insert into lessons (title, type, course_module_id, video_type, video_url, video_s3_key)
      values ('Ambos', 'video', '${courseModuleId}', 'external',
              'https://youtu.be/x', 'videos/x.mp4')
    `);
    expect(ambos).toContain('lessons_video_source');

    // Una lección de video sin ningún origen tampoco sirve.
    const videoSinOrigen = await expectRejected(`
      insert into lessons (title, type, course_module_id)
      values ('Video vacío', 'video', '${courseModuleId}')
    `);
    expect(videoSinOrigen).toContain('lessons_video_type_requires_source');

    // Los dos casos válidos sí entran.
    await sql.unsafe(`
      insert into lessons (title, type, course_module_id, video_type, video_url)
      values ('Externo', 'video', '${courseModuleId}', 'external', 'https://youtu.be/x')
    `);
    await sql.unsafe(`
      insert into lessons (title, type, course_module_id, video_type,
                           video_s3_key, video_size_bytes, video_mime_type)
      values ('Propio', 'video', '${courseModuleId}', 'uploaded',
              'videos/leccion.mp4', 104857600, 'video/mp4')
    `);
    const [counted] = await sql<{ count: string }[]>`
      select count(*)::text as count from lessons where type = 'video'
    `;
    expect(Number(counted?.count)).toBe(2);
  });

  it('una lección de tipo link necesita su URL', async () => {
    const sinUrl = await expectRejected(`
      insert into lessons (title, type, course_module_id)
      values ('Enlace vacío', 'link', '${courseModuleId}')
    `);
    expect(sinUrl).toContain('lessons_link_requires_url');
  });

  it('una lección que no es video puede no tener video ninguno', async () => {
    await sql.unsafe(`
      insert into lessons (title, type, ruta_module_id)
      values ('Guía de la fase', 'pdf', '${rutaModuleId}')
    `);
    const [row] = await sql<{ video_type: string | null }[]>`
      select video_type from lessons where title = 'Guía de la fase'
    `;
    expect(row?.video_type).toBeNull();
  });
});

describe('submissions', () => {
  let studentId = '';
  let courseId = '';
  let groupId = '';
  let rutaModuleId = '';

  beforeAll(async () => {
    const [student] = await sql<{ id: string }[]>`
      insert into users (name, email, password_hash, role, student_type)
      values ('Entregador', 'entrega@test.co', 'x', 'student', 'enactus')
      returning id
    `;
    const [course] = await sql<{ id: string }[]>`
      insert into courses (name) values ('Curso entregas') returning id
    `;
    const [project] = await sql<{ id: string }[]>`
      insert into projects (name) values ('Proyecto') returning id
    `;
    const [group] = await sql<{ id: string }[]>`
      insert into groups (name, project_id) values ('Equipo', ${project!.id})
      returning id
    `;
    const [rm] = await sql<{ id: string }[]>`
      select rm.id from ruta_modules rm limit 1
    `;
    studentId = student!.id;
    courseId = course!.id;
    groupId = group!.id;
    rutaModuleId = rm!.id;
  });

  it('exige exactamente un contexto (curso o módulo de Ruta)', async () => {
    const ninguno = await expectRejected(`
      insert into submissions (task_name, student_id) values ('Suelta', '${studentId}')
    `);
    expect(ninguno).toContain('submissions_exactly_one_context');

    const ambos = await expectRejected(`
      insert into submissions (task_name, student_id, course_id, ruta_module_id)
      values ('Ambos', '${studentId}', '${courseId}', '${rutaModuleId}')
    `);
    expect(ambos).toContain('submissions_exactly_one_context');
  });

  it('exige exactamente un autor (estudiante o equipo)', async () => {
    const ambos = await expectRejected(`
      insert into submissions (task_name, course_id, student_id, group_id)
      values ('Ambos', '${courseId}', '${studentId}', '${groupId}')
    `);
    expect(ambos).toContain('submissions_exactly_one_author');
  });

  it('no acepta una nota sin escala ni autor', async () => {
    // Es el problema real de hoy: cuatro escalas conviven en el mismo campo
    // `double? grade` y el número por sí solo no significa nada.
    const sinEscala = await expectRejected(`
      insert into submissions (task_name, course_id, student_id, grade)
      values ('Sin escala', '${courseId}', '${studentId}', 85)
    `);
    expect(sinEscala).toContain('submissions_grade_has_scale_and_author');

    await sql.unsafe(`
      insert into submissions (task_name, course_id, student_id, grade,
                               grading_mode, graded_by, graded_at)
      values ('Con escala', '${courseId}', '${studentId}', 85,
              'points100', '${studentId}', now())
    `);
    const [row] = await sql<{ grade: string; grading_mode: string }[]>`
      select grade, grading_mode from submissions where task_name = 'Con escala'
    `;
    expect(row?.grading_mode).toBe('points100');
  });

  it('en modo review no puede haber nota', async () => {
    const conNota = await expectRejected(`
      insert into submissions (task_name, course_id, student_id, grade,
                               grading_mode, graded_by, graded_at)
      values ('Review con nota', '${courseId}', '${studentId}', 50,
              'review', '${studentId}', now())
    `);
    expect(conNota).toContain('submissions_review_mode_has_no_grade');
  });
});

describe('calendar_events', () => {
  it('ata el evento al objeto correcto según su tipo', async () => {
    const [lab] = await sql<{ id: string }[]>`
      select id from laboratories limit 1
    `;
    const [course] = await sql<{ id: string }[]>`select id from courses limit 1`;

    // Una sesión de Open Learning sin curso no la puede ver nadie.
    const syncSinCurso = await expectRejected(`
      insert into calendar_events (title, starts_at, type)
      values ('Sesión', now(), 'open_learning_sync')
    `);
    expect(syncSinCurso).toContain('calendar_events_target_matches_type');

    // Una mentoría no se cuelga de un curso.
    const mentoriaConCurso = await expectRejected(`
      insert into calendar_events (title, starts_at, type, course_id)
      values ('Mentoría', now(), 'mentoria', '${course!.id}')
    `);
    expect(mentoriaConCurso).toContain('calendar_events_target_matches_type');

    await sql.unsafe(`
      insert into calendar_events (title, starts_at, type, laboratory_id)
      values ('Mentoría', now(), 'mentoria', '${lab!.id}')
    `);
  });
});

// La unicidad de `certificates` se prueba en `completeness.test.ts`: el
// trigger `certificates_require_complete_ruta` exige una Ruta completa para
// poder insertar siquiera el primero, y ese escenario ya está montado allá.
