import { and, desc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  auditLog,
  courses,
  lessons,
  notifications,
  progress,
  progressLessons,
  submissionFiles,
  submissions,
} from '../db/schema';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  assertCanGrade,
  currentUser,
  isStudentLike,
  requireAuth,
  requireCanGrade,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

export const submissionRoutes = new Hono<AppEnv>();
submissionRoutes.use('*', requireAuth);

const createBody = z
  .object({
    courseId: z.uuid().optional(),
    rutaModuleId: z.uuid().optional(),
    lessonId: z.uuid().optional(),
    taskName: z.string().trim().min(1, 'El nombre de la entrega es obligatorio.'),
    comment: z.string().trim().default(''),
    files: z
      .array(
        z.object({
          s3Key: z.string().trim().min(1),
          fileName: z.string().trim().min(1),
          contentType: z.string().trim().min(1),
          sizeBytes: z.number().int().positive(),
        }),
      )
      .default([]),
  })
  .refine((b) => Boolean(b.courseId) !== Boolean(b.rutaModuleId), {
    message: 'Indicá exactamente uno: courseId o rutaModuleId.',
  });

const gradeBody = z.object({
  grade: z.number().nullable().optional(),
  gradingMode: z.enum(['points100', 'passfail', 'review', 'scale5']),
  feedback: z.string().trim().default(''),
});

const reviewBody = z.object({
  feedback: z.string().trim().min(1, 'El comentario es obligatorio.'),
});

const listQuery = paginationSchema.extend({
  courseId: z.uuid().optional(),
  studentId: z.uuid().optional(),
  pending: z.enum(['true', 'false']).optional(),
});

/** Rango válido de cada escala. Sin esto, una nota no significa nada. */
function assertGradeInRange(mode: string, grade: number | null | undefined): void {
  if (mode === 'review') {
    if (grade !== null && grade !== undefined) {
      throw badRequest('En modo revisión no se pone nota.');
    }
    return;
  }
  if (grade === null || grade === undefined) {
    throw badRequest('Falta la nota.');
  }
  const limits: Record<string, [number, number]> = {
    points100: [0, 100],
    passfail: [0, 100],
    scale5: [0, 5],
  };
  const range = limits[mode];
  if (!range) throw badRequest(`Escala desconocida: ${mode}.`);
  if (grade < range[0] || grade > range[1]) {
    throw badRequest(
      `La nota debe estar entre ${range[0]} y ${range[1]} en la escala ${mode}.`,
    );
  }
}

// ---------------------------------------------------------------------------

submissionRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = listQuery.parse(c.req.query());
  const db = c.get('db');

  const filters = [isNull(submissions.deletedAt)];

  if (isStudentLike(user.role)) {
    // Un estudiante ve SOLO las suyas. No hay parámetro que lo cambie.
    filters.push(eq(submissions.studentId, user.id));
  } else if (user.role === 'lxd') {
    filters.push(
      sql`${submissions.courseId} in (select c.id from courses c
                                       where c.creator_id = ${user.id})`,
    );
  } else if (user.role === 'mentor') {
    filters.push(
      sql`(case when exists (select 1 from mentor_review_courses m
                              where m.mentor_id = ${user.id})
             then ${submissions.courseId} in (select m.course_id from mentor_review_courses m
                                               where m.mentor_id = ${user.id})
             else ${submissions.courseId} in (
                    select c.id from courses c
                     where c.laboratory_id in (select lm.laboratory_id
                                                 from laboratory_mentors lm
                                                where lm.user_id = ${user.id}))
           end)`,
    );
  } else if (user.role === 'advisor') {
    filters.push(
      sql`${submissions.studentId} in (select u.id from users u
                                        where u.university = ${user.university}
                                          and u.university <> '')`,
    );
  } else if (user.role !== 'admin' && user.role !== 'superadmin') {
    // Empresa y Donante no ven entregas.
    return c.json(paginated([], 0, query));
  }

  if (query.courseId) filters.push(eq(submissions.courseId, query.courseId));
  if (query.studentId) filters.push(eq(submissions.studentId, query.studentId));
  if (query.pending === 'true') filters.push(isNull(submissions.gradedAt));

  const where = and(...filters);
  const rows = await db
    .select()
    .from(submissions)
    .where(where)
    .orderBy(desc(submissions.submittedAt))
    .limit(query.pageSize)
    .offset((query.page - 1) * query.pageSize);

  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(submissions)
    .where(where);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

/** Crear una entrega: solo el propio estudiante, y solo donde tiene acceso. */
submissionRoutes.post('/', async (c) => {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante puede hacer una entrega.');
  }
  const parsed = createBody.parse(await c.req.json());
  const db = c.get('db');

  if (parsed.courseId) {
    const [access] = await db.execute<{ course_id: string }>(sql`
      select course_id from student_course_access
       where student_id = ${user.id} and course_id = ${parsed.courseId}
    `);
    if (!access) throw forbidden('No tenés acceso a ese curso.');
  } else {
    const [lab] = await db.execute<{ laboratory_id: string }>(sql`
      select p.laboratory_id
        from ruta_modules rm
        join phases p on p.id = rm.phase_id
        join student_laboratories sl
          on sl.laboratory_id = p.laboratory_id and sl.student_id = ${user.id}
       where rm.id = ${parsed.rutaModuleId}
    `);
    if (!lab) throw forbidden('No estás asignado a ese laboratorio.');
  }

  const [created] = await db
    .insert(submissions)
    .values({
      courseId: parsed.courseId ?? null,
      rutaModuleId: parsed.rutaModuleId ?? null,
      studentId: user.id,
      lessonId: parsed.lessonId ?? null,
      taskName: parsed.taskName,
      comment: parsed.comment,
    })
    .returning();

  if (parsed.files.length > 0) {
    await db
      .insert(submissionFiles)
      .values(parsed.files.map((f) => ({ submissionId: created!.id, ...f })));
  }

  return c.json({ ...created, files: parsed.files }, 201);
});

/**
 * Calificar.
 *
 * Hoy `saveSubmission` es un upsert genérico que usan tanto el estudiante
 * (para crear) como el LXD (para escribir la nota), sin verificar nada. Acá
 * son dos endpoints con permisos distintos, y este exige `can_grade` EN EL
 * CONTEXTO del curso: Open Learning y Enactus son permisos separados.
 */
submissionRoutes.post('/:id/grade', requireCanGrade, async (c) => {
  const user = currentUser(c);
  const parsed = gradeBody.parse(await c.req.json());
  const db = c.get('db');

  const submission = await loadSubmission(db, c.req.param('id'));
  const course = submission.courseId
    ? await loadCourse(db, submission.courseId)
    : null;

  // El contexto sale del curso, no del cuerpo de la petición.
  assertCanGrade(user, course?.isOpenLearning ?? false);
  if (user.role === 'lxd' && course && course.creatorId !== user.id) {
    throw forbidden('Solo podés calificar entregas de los cursos que creaste.');
  }

  assertGradeInRange(parsed.gradingMode, parsed.grade);

  const grade = parsed.gradingMode === 'review' ? null : parsed.grade!;
  const [updated] = await db
    .update(submissions)
    .set({
      grade: grade === null ? null : grade.toFixed(2),
      gradingMode: parsed.gradingMode,
      gradedBy: grade === null ? null : user.id,
      gradedAt: grade === null ? null : new Date(),
      feedback: parsed.feedback,
      updatedAt: new Date(),
    })
    .where(eq(submissions.id, submission.id))
    .returning();

  // Calificar una actividad de curso es lo que la completa: a diferencia del
  // quiz (que se autocompleta al aprobar), la actividad depende de esta
  // revisión. Se marca completa, nunca se alterna.
  if (submission.courseId && submission.lessonId && submission.studentId) {
    await markLessonComplete(
      db,
      submission.studentId,
      submission.courseId,
      submission.lessonId,
    );
  }

  if (submission.studentId) {
    await db.insert(notifications).values({
      userId: submission.studentId,
      title: 'Entrega calificada',
      body: `"${submission.taskName}" tiene nueva retroalimentación.`,
    });
  }

  await db.insert(auditLog).values({
    actorId: user.id,
    action: 'submission.grade',
    entityType: 'submission',
    entityId: submission.id,
    oldValue: { grade: submission.grade, gradingMode: submission.gradingMode },
    newValue: { grade: updated!.grade, gradingMode: updated!.gradingMode },
    ip: c.get('requestIp'),
  });

  return c.json(updated);
});

/**
 * El Mentor revisa y COMENTA, pero no pone nota. Es explícito en la interfaz
 * actual ("Comentario (sin nota: el Mentor no califica)") y acá se hace
 * cumplir: este endpoint no toca `grade` bajo ninguna circunstancia.
 */
submissionRoutes.post('/:id/review', async (c) => {
  const user = currentUser(c);
  if (user.role !== 'mentor' && user.role !== 'admin' && user.role !== 'superadmin') {
    throw forbidden('Solo un Mentor (o un administrador) puede comentar una entrega.');
  }
  const { feedback } = reviewBody.parse(await c.req.json());
  const db = c.get('db');
  const submission = await loadSubmission(db, c.req.param('id'));

  const [updated] = await db
    .update(submissions)
    .set({
      feedback,
      reviewedBy: user.id,
      reviewedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(eq(submissions.id, submission.id))
    .returning();

  if (submission.studentId) {
    await db.insert(notifications).values({
      userId: submission.studentId,
      title: 'Entrega revisada',
      body: `"${submission.taskName}" tiene un comentario nuevo de tu Mentor.`,
    });
  }

  return c.json(updated);
});

/**
 * Borrado por el propio estudiante, solo mientras no esté calificada
 * (decisión C.7). Es lógico, no físico.
 */
submissionRoutes.delete('/:id', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const submission = await loadSubmission(db, c.req.param('id'));

  const esAdmin = user.role === 'admin' || user.role === 'superadmin';
  if (!esAdmin) {
    if (submission.studentId !== user.id) {
      throw forbidden('Solo podés borrar tus propias entregas.');
    }
    if (submission.gradedAt || submission.feedback.length > 0) {
      throw conflict(
        'No podés borrar una entrega que ya fue calificada o comentada.',
      );
    }
  }

  await db
    .update(submissions)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(submissions.id, submission.id));
  return c.body(null, 204);
});

// ---------------------------------------------------------------------------

type Db = AppEnv['Variables']['db'];

async function loadSubmission(db: Db, id: string) {
  const [row] = await db
    .select()
    .from(submissions)
    .where(and(eq(submissions.id, id), isNull(submissions.deletedAt)))
    .limit(1);
  if (!row) throw notFound('No se encontró la entrega.');
  return row;
}

async function loadCourse(db: Db, courseId: string) {
  const [row] = await db
    .select()
    .from(courses)
    .where(eq(courses.id, courseId))
    .limit(1);
  return row ?? null;
}

/** Marca completa sin alternar: revisar nunca debe des-completar. */
async function markLessonComplete(
  db: Db,
  studentId: string,
  courseId: string,
  lessonId: string,
) {
  const [belongs] = await db
    .select({ id: lessons.id })
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!belongs) return;

  const [row] = await db
    .insert(progress)
    .values({ studentId, courseId })
    .onConflictDoUpdate({
      target: [progress.studentId, progress.courseId],
      set: { updatedAt: new Date() },
    })
    .returning({ id: progress.id });

  await db
    .insert(progressLessons)
    .values({ progressId: row!.id, lessonId })
    .onConflictDoNothing();
}

export type { AuthUser };
