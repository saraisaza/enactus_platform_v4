import { and, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { courses, staffNotes } from '../db/schema';
import { forbidden, notFound } from '../lib/errors';
import { currentUser, requireAuth } from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * Seguimiento de un curso: quiénes lo cursan, cómo van y las notas privadas
 * del equipo docente.
 *
 * Todo lo que la tabla de seguimiento muestra por estudiante —avance, nota
 * promedio, última actividad, comentario— sale de UNA consulta. Resolverlo en
 * el cliente serían cuatro peticiones por fila: con treinta estudiantes, 120
 * viajes para dibujar una tabla.
 */
export const courseTrackingRoutes = new Hono<AppEnv>();
courseTrackingRoutes.use('*', requireAuth);

/**
 * Quién puede ver el seguimiento de un curso.
 *
 * Es más amplio que editarlo: el Mentor y el Asesor acompañan sin poder
 * cambiar el contenido. Pero NO es público — un estudiante no ve cómo va el
 * resto de la clase.
 */
async function loadTrackableCourse(
  db: AppEnv['Variables']['db'],
  courseId: string,
  user: AuthUser,
) {
  const [course] = await db
    .select()
    .from(courses)
    .where(and(eq(courses.id, courseId), isNull(courses.deletedAt)))
    .limit(1);
  if (!course) throw notFound('No se encontró el curso.');

  if (user.role === 'admin' || user.role === 'superadmin') return course;
  if (user.role === 'lxd' && course.creatorId === user.id) return course;

  if (user.role === 'mentor') {
    const [ok] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from laboratory_mentors lm
       where lm.user_id = ${user.id}
         and lm.laboratory_id = ${course.laboratoryId}
       limit 1
    `);
    if (ok) return course;
  }

  if (user.role === 'advisor' && user.university) {
    // Un asesor sigue a los de su universidad: le sirve si alguno cursa esto.
    const [ok] = await db.execute<{ ok: number }>(sql`
      select 1 as ok
        from student_course_access a
        join users u on u.id = a.student_id
       where a.course_id = ${course.id}
         and u.university = ${user.university}
       limit 1
    `);
    if (ok) return course;
  }

  // 404 y no 403: un 403 confirmaría que el curso existe.
  throw notFound('No se encontró el curso.');
}

/**
 * Los estudiantes del curso, con todo lo que la tabla de seguimiento muestra.
 *
 * `lastActivityAt` es lo más reciente entre marcar una lección y hacer una
 * entrega: es "cuándo se supo de esta persona por última vez", que es la
 * pregunta que se está haciendo quien mira la tabla.
 */
courseTrackingRoutes.get('/:id/students', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadTrackableCourse(db, c.req.param('id'), user);

  const rows = await db.execute<{
    id: string;
    name: string;
    email: string;
    avatarS3Key: string | null;
    university: string;
    career: string;
    sponsorName: string | null;
    totalLessons: number;
    completedLessons: number;
    ratio: string;
    isComplete: boolean;
    avgGrade: string | null;
    gradedCount: number;
    pendingCount: number;
    lastActivityAt: string | null;
    note: string;
  }>(sql`
    select u.id, u.name, u.email, u.avatar_s3_key as "avatarS3Key",
           u.university, u.career,
           -- El patrocinador, para agrupar el avance por empresa. Mismo
           -- LEFT JOIN que resuelve sponsorName en /auth/me.
           nullif(sp.company_name, '')             as "sponsorName",
           coalesce(cp.total_lessons, 0)::int      as "totalLessons",
           coalesce(cp.completed_lessons, 0)::int  as "completedLessons",
           coalesce(cp.ratio, 0)::text             as ratio,
           coalesce(cp.is_complete, false)         as "isComplete",
           g.avg_grade::text                       as "avgGrade",
           coalesce(g.graded_count, 0)::int        as "gradedCount",
           coalesce(g.pending_count, 0)::int       as "pendingCount",
           greatest(pl.last_lesson, g.last_submission)::text as "lastActivityAt",
           coalesce(n.note, '')                    as note
      from student_course_access a
      join users u on u.id = a.student_id and u.deleted_at is null
      left join course_progress cp
             on cp.student_id = u.id and cp.course_id = a.course_id
      left join lateral (
        select avg(s.grade)                                   as avg_grade,
               count(*) filter (where s.graded_at is not null) as graded_count,
               count(*) filter (where s.graded_at is null)     as pending_count,
               max(s.submitted_at)                             as last_submission
          from submissions s
         where s.course_id = a.course_id
           and s.student_id = u.id
           and s.deleted_at is null
      ) g on true
      left join lateral (
        select max(pl.completed_at) as last_lesson
          from progress p
          join progress_lessons pl on pl.progress_id = p.id
         where p.student_id = u.id and p.course_id = a.course_id
      ) pl on true
      left join users sp on sp.id = u.company_id and sp.deleted_at is null
      left join staff_notes n
             on n.student_id = u.id and n.course_id = a.course_id
     where a.course_id = ${course.id}
     order by u.name
  `);

  return c.json({
    courseId: course.id,
    courseName: course.name,
    students: rows.map((r) => ({
      id: r.id,
      name: r.name,
      email: r.email,
      avatarS3Key: r.avatarS3Key,
      university: r.university,
      career: r.career,
      sponsorName: r.sponsorName,
      progress: {
        courseId: course.id,
        courseName: course.name,
        totalLessons: r.totalLessons,
        completedLessons: r.completedLessons,
        ratio: Number(r.ratio),
        isComplete: r.isComplete,
      },
      // La nota promedio llega como texto (`numeric`) para no perder
      // precisión; `null` cuando esta persona no tiene ninguna calificada.
      avgGrade: r.avgGrade === null ? null : Number(r.avgGrade),
      gradedCount: r.gradedCount,
      pendingCount: r.pendingCount,
      lastActivityAt: r.lastActivityAt,
      note: r.note,
    })),
  });
});

/** Cifras del encabezado del seguimiento. */
courseTrackingRoutes.get('/:id/stats', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadTrackableCourse(db, c.req.param('id'), user);

  const [stats] = await db.execute<{
    enrolled: number;
    completed: number;
    avgProgress: string;
    avgGrade: string | null;
    pending: number;
  }>(sql`
    select count(*)::int                                        as enrolled,
           count(*) filter (where cp.is_complete)::int          as completed,
           coalesce(avg(cp.ratio), 0)::text                     as "avgProgress",
           (select avg(s.grade)::text from submissions s
             where s.course_id = ${course.id}
               and s.graded_at is not null
               and s.deleted_at is null)                        as "avgGrade",
           (select count(*)::int from submissions s
             where s.course_id = ${course.id}
               and s.graded_at is null
               and s.deleted_at is null)                        as pending
      from student_course_access a
      left join course_progress cp
             on cp.student_id = a.student_id and cp.course_id = a.course_id
     where a.course_id = ${course.id}
  `);

  return c.json({
    enrolled: stats?.enrolled ?? 0,
    completed: stats?.completed ?? 0,
    avgProgress: Number(stats?.avgProgress ?? 0),
    // `null`, no 0: "nadie tiene nota todavía" y "todos sacaron cero" son
    // cosas distintas y la pantalla las muestra distinto.
    avgGrade: stats?.avgGrade == null ? null : Number(stats.avgGrade),
    pending: stats?.pending ?? 0,
  });
});

const noteBody = z.object({
  note: z.string().trim().max(4000, 'El comentario es demasiado largo.'),
});

/**
 * Comentario privado del equipo docente sobre un estudiante en un curso.
 *
 * **El estudiante no lo ve.** No hay endpoint que se lo devuelva: la tabla
 * `staff_notes` solo se lee desde acá, y acá solo entra quien puede seguir el
 * curso. Se llamaba `mentor_notes` y el nombre mentía — quien las escribe es
 * el LXD desde su seguimiento, no el Mentor.
 *
 * Es un PUT y no un POST porque hay UNA nota por estudiante y curso: escribir
 * dos veces reemplaza, no acumula.
 */
courseTrackingRoutes.put('/:id/students/:studentId/note', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadTrackableCourse(db, c.req.param('id'), user);
  const studentId = c.req.param('studentId');
  const { note } = noteBody.parse(await c.req.json());

  // Un asesor acompaña, pero no escribe en el cuaderno del curso.
  if (user.role === 'advisor') {
    throw forbidden('Los comentarios del curso los escribe su equipo docente.');
  }

  // La persona tiene que cursarlo: si no, la nota quedaría colgando de un
  // par (estudiante, curso) que no existe.
  const [enrolled] = await db.execute<{ ok: number }>(sql`
    select 1 as ok from student_course_access
     where course_id = ${course.id} and student_id = ${studentId}
     limit 1
  `);
  if (!enrolled) {
    throw notFound('Esa persona no está en este curso.');
  }

  const [saved] = await db
    .insert(staffNotes)
    .values({ studentId, courseId: course.id, authorId: user.id, note })
    .onConflictDoUpdate({
      target: [staffNotes.studentId, staffNotes.courseId],
      set: { note, authorId: user.id, updatedAt: new Date() },
    })
    .returning();

  return c.json(saved);
});
