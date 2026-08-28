import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { verifyPassword } from '../src/lib/password';
import { makeTestClient, seedId, seedTestDatabase } from './helpers/db';

/**
 * El seed no es solo "que corra": tiene que dejar la base en un estado con el
 * que se puedan probar las reglas del dominio. Estas pruebas verifican
 * exactamente eso, incluidos los tres requisitos que la Fase 2 agrega sobre
 * el seed original de Flutter.
 */

let sql: Sql;

beforeAll(async () => {
  await seedTestDatabase();
  sql = makeTestClient();
}, 120_000);

afterAll(async () => {
  await sql.end();
});

describe('cobertura de roles', () => {
  it('están presentes los 9 roles', async () => {
    const rows = await sql<{ role: string; count: string }[]>`
      select role, count(*)::text as count from users group by role
    `;
    expect(rows.map((r) => r.role).sort()).toEqual([
      'admin',
      'advisor',
      'alumni',
      'company',
      'donor',
      'lxd',
      'mentor',
      'student',
      'superadmin',
    ]);
    expect(rows).toHaveLength(9);
  });

  it('replica el reparto de usuarios del SeedService de Flutter', async () => {
    const [row] = await sql<{ count: string }[]>`
      select count(*)::text as count from users
    `;
    // 2 superadmin + 1 admin + 3 lxd + 1 mentor + 1 advisor + 1 company
    // + 1 donor + 4 estudiantes Enactus + 1 Open Learning + 1 alumni.
    expect(Number(row?.count)).toBe(16);
  });
});

describe('contraseñas', () => {
  it('se guardan hasheadas con bcrypt, nunca en texto plano', async () => {
    const [row] = await sql<{ password_hash: string }[]>`
      select password_hash from users where email = 'admin@enactus.co'
    `;
    const hash = row?.password_hash ?? '';
    expect(hash).not.toBe('Admin123');
    expect(hash.startsWith('$2')).toBe(true);
    expect(await verifyPassword('Admin123', hash)).toBe(true);
    expect(await verifyPassword('otra-cosa', hash)).toBe(false);
  });
});

describe('requisitos que la Fase 2 agrega sobre el seed original', () => {
  it('hay un LXD que SÍ puede calificar y otro que no', async () => {
    const rows = await sql<
      { email: string; ol: boolean; ex: boolean }[]
    >`
      select email,
             can_grade_open_learning as ol,
             can_grade_enactus as ex
        from users where role = 'lxd' order by email
    `;
    const puede = rows.find((r) => r.email === 'lxd.ia@enactus.co');
    const noPuede = rows.find((r) => r.email === 'lxd.agua@enactus.co');
    expect(puede?.ol).toBe(true);
    expect(puede?.ex).toBe(true);
    expect(noPuede?.ol).toBe(false);
    expect(noPuede?.ex).toBe(false);
  });

  it('hay un estudiante con la Ruta de Impacto parcialmente completa', async () => {
    const rows = await sql<
      { order_index: number; modules_done: string; modules_total: string; is_complete: boolean }[]
    >`
      select p.order_index, pc.modules_done::text, pc.modules_total::text,
             pc.is_complete
        from phase_completion pc
        join phases p on p.id = pc.phase_id
       where pc.student_id = ${seedId('est1')}
         and p.laboratory_id = ${seedId('lab_ia')}
       order by p.order_index
    `;
    // Fase 1: el módulo de contenido completo, el de mentoría pendiente.
    expect(rows[0]?.modules_done).toBe('1');
    expect(rows[0]?.modules_total).toBe('2');
    expect(rows[0]?.is_complete).toBe(false);

    // Y por lo tanto la Ruta entera está incompleta: sirve para probar que
    // el certificado se rechaza.
    const [ruta] = await sql<{ is_complete: boolean }[]>`
      select is_complete from ruta_completion
       where student_id = ${seedId('est1')} and laboratory_id = ${seedId('lab_ia')}
    `;
    expect(ruta?.is_complete).toBe(false);
  });

  it('el curso del módulo 1 sí está completo (el avance es real, no cero)', async () => {
    const [row] = await sql<
      { ratio: string; is_complete: boolean }[]
    >`
      select ratio, is_complete from course_progress
       where student_id = ${seedId('est1')} and course_id = ${seedId('crs_ia_1')}
    `;
    expect(Number(row?.ratio)).toBe(1);
    expect(row?.is_complete).toBe(true);

    // La alumni del mismo laboratorio tiene MENOS avance: 2 de 6 lecciones.
    const [alum] = await sql<{ ratio: string }[]>`
      select ratio from course_progress
       where student_id = ${seedId('alum1')} and course_id = ${seedId('crs_ia_1')}
    `;
    expect(Number(alum?.ratio)).toBeCloseTo(0.3333, 3);
  });
});

describe('brechas de modelo del frontend, ahora sembradas', () => {
  it('cada integrante de un equipo tiene su rol dentro del proyecto', async () => {
    const rows = await sql<{ name: string; role_in_project: string }[]>`
      select u.name, gm.role_in_project
        from group_members gm
        join users u on u.id = gm.user_id
       where gm.group_id = ${seedId('grp1')}
       order by u.name
    `;
    expect(rows).toHaveLength(3);
    expect(rows.every((r) => r.role_in_project.length > 0)).toBe(true);
    expect(rows.map((r) => r.role_in_project)).toContain('leader');
  });

  it('las evidencias que hablan de un proyecto lo tienen asociado', async () => {
    const rows = await sql<{ title: string; project_id: string | null }[]>`
      select title, project_id from evidences order by title
    `;
    const conProyecto = rows.filter((r) => r.project_id !== null);
    expect(conProyecto.length).toBeGreaterThan(0);
    expect(conProyecto.every((r) => r.project_id === seedId('prj1'))).toBe(true);
  });
});

describe('estructura sembrada', () => {
  it('los 6 laboratorios tienen sus 3 fases', async () => {
    const rows = await sql<{ count: string }[]>`
      select count(*)::text as count from phases group by laboratory_id
    `;
    expect(rows).toHaveLength(6);
    expect(rows.every((r) => r.count === '3')).toBe(true);
  });

  it('el curso demo trae quiz, actividad con rúbrica y encuesta', async () => {
    const [quiz] = await sql<{ count: string }[]>`
      select count(*)::text as count from quiz_questions
       where lesson_id = ${seedId('lia4')}
    `;
    expect(Number(quiz?.count)).toBe(4);

    const [rubrica] = await sql<{ count: string; total: string }[]>`
      select count(*)::text as count, coalesce(sum(points),0)::text as total
        from activity_rubric_items where lesson_id = ${seedId('lia5')}
    `;
    expect(Number(rubrica?.count)).toBe(5);
    expect(Number(rubrica?.total)).toBe(100);

    const [encuesta] = await sql<{ count: string }[]>`
      select count(*)::text as count from quiz_questions
       where lesson_id = ${seedId('lia6')}
    `;
    expect(Number(encuesta?.count)).toBe(2);
  });

  it('las lecciones de video traen su origen y son de tipo uploaded', async () => {
    const rows = await sql<
      { video_type: string; video_s3_key: string | null }[]
    >`
      select video_type, video_s3_key from lessons where type = 'video'
    `;
    expect(rows.length).toBeGreaterThan(0);
    expect(rows.every((r) => r.video_type === 'uploaded')).toBe(true);
    expect(rows.every((r) => (r.video_s3_key ?? '').length > 0)).toBe(true);
  });

  it('la nota sembrada trae su escala y su autor', async () => {
    const [row] = await sql<
      { grade: string; grading_mode: string; graded_by: string }[]
    >`
      select grade, grading_mode, graded_by from submissions
       where id = ${seedId('sub1')}
    `;
    expect(Number(row?.grade)).toBe(4.5);
    expect(row?.grading_mode).toBe('scale5');
    expect(row?.graded_by).toBe(seedId('lxd1'));
  });
});

describe('acceso Enactus vs Open Learning ya sembrado', () => {
  it('la estudiante de Open Learning solo ve su curso asignado', async () => {
    const rows = await sql<{ course_id: string }[]>`
      select course_id from student_course_access
       where student_id = ${seedId('est_ol1')}
    `;
    expect(rows.map((r) => r.course_id)).toEqual([seedId('crs_ol_marketing')]);
  });

  it('una estudiante Enactus ve los cursos de sus laboratorios sin asignarlos', async () => {
    const rows = await sql<{ course_id: string }[]>`
      select course_id from student_course_access
       where student_id = ${seedId('est1')} order by course_id
    `;
    expect(rows.map((r) => r.course_id).sort()).toEqual(
      [seedId('crs_ia_1'), seedId('crs_impacto_1')].sort(),
    );
  });
});
