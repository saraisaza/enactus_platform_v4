import { asc, count, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  courseModules,
  lessons,
  quizAttempts,
  quizQuestions,
} from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import {
  assertValidVideoUpload,
  createUploadUrl,
  videoKeyFor,
} from '../lib/s3';
import {
  CONTENT_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { loadEditableCourse } from './courses';

type Db = AppEnv['Variables']['db'];

const lessonType = z.enum([
  'video',
  'pdf',
  'resource',
  'link',
  'quiz',
  'activity',
  'survey',
]);

const lessonBody = z.object({
  title: z.string().trim().min(1, 'El título es obligatorio.'),
  type: lessonType.default('video'),
  description: z.string().trim().default(''),
  durationMin: z.number().int().min(0).default(0),
  /** Solo `type = 'link'`. */
  externalUrl: z.url().nullable().optional(),
});

const lessonUpdate = lessonBody.partial();

const reorderBody = z.object({
  orderedIds: z.array(z.uuid()).min(1, 'Hace falta al menos un id.'),
});

const uploadUrlBody = z.object({
  contentType: z.string().trim().min(1, 'Falta el content-type del archivo.'),
  sizeBytes: z.number().int().positive('El tamaño debe ser mayor a 0.'),
});

const confirmUploadBody = z.object({
  key: z.string().trim().min(1),
  sizeBytes: z.number().int().positive(),
  mimeType: z.string().trim().min(1),
  durationSec: z.number().int().min(0).optional(),
});

const externalVideoBody = z.object({
  url: z.url('Tiene que ser una URL válida (YouTube o Vimeo).'),
  durationSec: z.number().int().min(0).optional(),
});

// ---------------------------------------------------------------------------
// Rutas colgadas de un módulo: crear y reordenar lecciones
// ---------------------------------------------------------------------------

export const moduleLessonRoutes = new Hono<AppEnv>();
moduleLessonRoutes.use('*', requireAuth);

moduleLessonRoutes.post('/:id/lessons', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = lessonBody.parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadEditableModule(db, c.req.param('id'), user);

  if (body.type === 'link' && !body.externalUrl) {
    throw conflict('Una lección de tipo enlace necesita su URL.');
  }

  const [{ value: existing } = { value: 0 }] = await db
    .select({ value: count() })
    .from(lessons)
    .where(eq(lessons.courseModuleId, mod.id));

  const [created] = await db
    .insert(lessons)
    .values({
      courseModuleId: mod.id,
      title: body.title,
      type: body.type,
      description: body.description,
      durationMin: body.durationMin,
      externalUrl: body.externalUrl ?? null,
      orderIndex: existing + 1,
    })
    .returning();

  return c.json(created, 201);
});

/** Mismo mecanismo de dos pasos que el reordenamiento de módulos. */
moduleLessonRoutes.put(
  '/:id/lessons/order',
  requireRole(...CONTENT_ROLES),
  async (c) => {
    const user = currentUser(c);
    const { orderedIds } = reorderBody.parse(await c.req.json());
    const db = c.get('db');
    const mod = await loadEditableModule(db, c.req.param('id'), user);

    const existing = await db
      .select({ id: lessons.id })
      .from(lessons)
      .where(eq(lessons.courseModuleId, mod.id));

    const existingIds = new Set(existing.map((l) => l.id));
    const alien = orderedIds.filter((id) => !existingIds.has(id));
    const missing = existing.filter((l) => !orderedIds.includes(l.id));
    if (alien.length > 0 || missing.length > 0) {
      throw conflict(
        'La lista de reordenamiento tiene que incluir exactamente las lecciones de este módulo, una sola vez cada una.',
        { alien, missing: missing.map((l) => l.id) },
      );
    }

    await db.transaction(async (tx) => {
      for (const [i, id] of orderedIds.entries()) {
        await tx.update(lessons).set({ orderIndex: -(i + 1) }).where(eq(lessons.id, id));
      }
      for (const [i, id] of orderedIds.entries()) {
        await tx
          .update(lessons)
          .set({ orderIndex: i + 1, updatedAt: new Date() })
          .where(eq(lessons.id, id));
      }
    });

    const ordered = await db
      .select()
      .from(lessons)
      .where(eq(lessons.courseModuleId, mod.id))
      .orderBy(asc(lessons.orderIndex));
    return c.json(ordered);
  },
);

// ---------------------------------------------------------------------------
// Rutas de una lección
// ---------------------------------------------------------------------------

export const lessonRoutes = new Hono<AppEnv>();
lessonRoutes.use('*', requireAuth);

lessonRoutes.patch('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = lessonUpdate.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  const [updated] = await db
    .update(lessons)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(lessons.id, lesson.id))
    .returning();

  return c.json(updated);
});

lessonRoutes.delete('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  await db.delete(lessons).where(eq(lessons.id, lesson.id));
  if (lesson.courseModuleId) await renumberLessons(db, lesson.courseModuleId);
  return c.body(null, 204);
});

/**
 * Paso 1 del flujo de subida: la API firma un permiso de escritura sobre S3.
 *
 * El archivo NO pasa por acá — va directo del navegador a S3. API Gateway
 * corta el payload en 10 MB y un video de 400 MB lo revienta.
 *
 * Se valida ANTES de firmar: tipo permitido (mp4/webm), tamaño ≤ 500 MB y rol
 * con permiso de crear contenido. Una URL firmada es un permiso real de
 * escritura sobre el bucket; no se emite a la ligera.
 */
lessonRoutes.post('/:id/video-upload-url', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = uploadUrlBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidVideoUpload(body);

  const key = videoKeyFor(lesson.id, body.contentType);
  const signed = await createUploadUrl({
    key,
    contentType: body.contentType,
    sizeBytes: body.sizeBytes,
  });

  return c.json({
    ...signed,
    // El cliente sube con PUT y este content-type exacto, o S3 rechaza.
    method: 'PUT',
    headers: { 'Content-Type': body.contentType },
  });
});

/**
 * Paso 3: el navegador confirma que la subida terminó y la lección queda
 * apuntando al archivo. Los videos propios se sirven después por CloudFront
 * con URL firmada, nunca por URL directa de S3.
 */
lessonRoutes.post('/:id/video', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = confirmUploadBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidVideoUpload({
    contentType: body.mimeType,
    sizeBytes: body.sizeBytes,
  });

  // La key tiene que ser la de ESTA lección: si no, alguien podría apuntar
  // su lección a un archivo subido para otra.
  if (!body.key.startsWith(`lessons/${lesson.id}/`)) {
    throw conflict('Esa key no corresponde a esta lección.');
  }

  const [updated] = await db
    .update(lessons)
    .set({
      type: 'video',
      videoType: 'uploaded',
      videoS3Key: body.key,
      videoUrl: null,
      videoSizeBytes: body.sizeBytes,
      videoMimeType: body.mimeType,
      videoDurationSec: body.durationSec ?? null,
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  return c.json(updated);
});

/** Video externo: se guarda el enlace, no hay archivo ni S3 de por medio. */
lessonRoutes.post('/:id/video-external', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = externalVideoBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  const [updated] = await db
    .update(lessons)
    .set({
      type: 'video',
      videoType: 'external',
      videoUrl: body.url,
      videoS3Key: null,
      videoSizeBytes: null,
      videoMimeType: null,
      videoDurationSec: body.durationSec ?? null,
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  return c.json(updated);
});

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

const quizAttemptBody = z.object({
  /** Una respuesta por pregunta: `{ [questionId]: índice | texto }`. */
  answers: z.record(z.string(), z.union([z.number().int(), z.string()])),
});

/** Umbral de aprobación. El mismo 60% que aplicaba el diálogo en Flutter. */
const PASSING_SCORE = 60;

/**
 * Resuelve un quiz y devuelve la nota.
 *
 * **La corrección ocurre acá, nunca en el cliente.** Antes el curso viajaba al
 * navegador con la clave de respuestas dentro, así que cualquiera podía leerla
 * desde las herramientas de desarrollo, y la nota que el cliente reportaba se
 * guardaba sin verificar. Ahora `answer_index`/`answer_text` no salen de la
 * base: llegan las respuestas, se comparan contra la clave y vuelve el
 * resultado.
 *
 * Se devuelve qué preguntas estuvieron bien —eso es retroalimentación
 * legítima— pero NO cuál era la respuesta correcta de las falladas: si la
 * devolviera, bastaría con enviar un intento en blanco para obtener la clave
 * completa.
 */
lessonRoutes.post('/:id/quiz-attempt', async (c) => {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante resuelve un quiz.');
  }

  const db = c.get('db');
  const lessonId = c.req.param('id');
  const body = quizAttemptBody.parse(await c.req.json());

  await assertLessonVisible(db, user, lessonId);

  const questions = await db
    .select()
    .from(quizQuestions)
    .where(eq(quizQuestions.lessonId, lessonId))
    .orderBy(asc(quizQuestions.orderIndex));

  if (questions.length === 0) {
    throw conflict('Esta lección no tiene preguntas configuradas.');
  }

  const correctness: Record<string, boolean> = {};
  let correct = 0;
  for (const question of questions) {
    const given = body.answers[question.id];
    const ok = isCorrect(question, given);
    correctness[question.id] = ok;
    if (ok) correct += 1;
  }

  const score = Math.round((correct / questions.length) * 100);
  const passed = score >= PASSING_SCORE;

  const [attempt] = await db
    .insert(quizAttempts)
    .values({
      lessonId,
      studentId: user.id,
      answers: body.answers,
      score,
      passed,
    })
    .returning();

  return c.json({
    attemptId: attempt!.id,
    score,
    passed,
    correctCount: correct,
    totalQuestions: questions.length,
    correctness,
  });
});

/**
 * Compara una respuesta contra la clave.
 *
 * `multiple` y `truefalse` van por índice; `short` y `fill` por texto,
 * normalizando espacios, mayúsculas y tildes — quien escribe "Analisis" no
 * está equivocado respecto de "análisis". `order` todavía no se corrige
 * automáticamente: no hay ningún quiz que la use y adivinar el formato de su
 * clave sería inventar una regla.
 */
function isCorrect(
  question: typeof quizQuestions.$inferSelect,
  given: number | string | undefined,
): boolean {
  if (given === undefined) return false;

  if (question.kind === 'multiple' || question.kind === 'truefalse') {
    return typeof given === 'number' && given === question.answerIndex;
  }
  if (question.kind === 'short' || question.kind === 'fill') {
    if (typeof given !== 'string' || question.answerText === null) return false;
    return normalize(given) === normalize(question.answerText);
  }
  return false;
}

const normalize = (text: string) =>
  text
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ');

/**
 * Una persona solo resuelve quizzes de cursos a los que tiene acceso.
 *
 * Se apoya en `student_course_access`, la misma vista con la que se calcula la
 * completitud: si un curso no está en su acceso, tampoco cuenta para su avance.
 */
async function assertLessonVisible(
  db: Db,
  user: ReturnType<typeof currentUser>,
  lessonId: string,
): Promise<void> {
  const [row] = await db.execute<{ ok: number }>(sql`
    select 1 as ok
      from lessons l
      join course_modules cm on cm.id = l.course_module_id
      join student_course_access a
        on a.course_id = cm.course_id and a.student_id = ${user.id}
     where l.id = ${lessonId}
     limit 1
  `);
  if (!row) throw notFound('No se encontró la lección.');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadEditableModule(
  db: Db,
  moduleId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [mod] = await db
    .select()
    .from(courseModules)
    .where(eq(courseModules.id, moduleId))
    .limit(1);
  if (!mod) throw notFound('No se encontró el módulo.');
  await loadEditableCourse(db, mod.courseId, user);
  return mod;
}

async function loadEditableLesson(
  db: Db,
  lessonId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [lesson] = await db
    .select()
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!lesson) throw notFound('No se encontró la lección.');

  if (lesson.courseModuleId) {
    const [mod] = await db
      .select()
      .from(courseModules)
      .where(eq(courseModules.id, lesson.courseModuleId))
      .limit(1);
    if (!mod) throw notFound('No se encontró el módulo de la lección.');
    await loadEditableCourse(db, mod.courseId, user);
  } else if (user.role !== 'admin' && user.role !== 'superadmin') {
    // Las lecciones propias de un módulo de la Ruta de Impacto las edita el
    // Admin desde el editor de Ruta, no el LXD desde su curso.
    throw notFound('No se encontró la lección.');
  }
  return lesson;
}

async function renumberLessons(db: Db, moduleId: string) {
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo
        from lessons where course_module_id = ${moduleId}
    )
    update lessons l set order_index = -o.nuevo
      from ordenados o where o.id = l.id
  `);
  await db.execute(sql`
    update lessons set order_index = -order_index
     where course_module_id = ${moduleId} and order_index < 0
  `);
}

