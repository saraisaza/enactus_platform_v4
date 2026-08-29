import { and, asc, count, eq, ilike, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { courseModules, courses } from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema, parseInclude } from '../lib/pagination';
import { CONTENT_ROLES, currentUser, requireAuth, requireRole } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import {
  assertCanEditCourse,
  courseDeletionBlockers,
  visibleCoursesFilter,
} from '../services/course-access';
import {
  lessonCountFor,
  videoLessonsWithoutSource,
} from '../services/course-content';

export const courseRoutes = new Hono<AppEnv>();
courseRoutes.use('*', requireAuth);

// ---------------------------------------------------------------------------
// Validación
// ---------------------------------------------------------------------------

const courseBody = z.object({
  name: z.string().trim().min(1, 'El nombre es obligatorio.'),
  subtitle: z.string().trim().default(''),
  description: z.string().trim().default(''),
  fullDescription: z.string().trim().default(''),
  laboratoryId: z.uuid().nullable().optional(),
  isOpenLearning: z.boolean().default(false),
  level: z.enum(['basic', 'intermediate', 'advanced']).default('basic'),
  estimatedHours: z.number().int().min(0).default(0),
  language: z.string().trim().default('es'),
  generatesCertificate: z.boolean().default(false),
  certifiedHours: z.number().int().min(0).default(0),
  maxStudents: z.number().int().min(0).default(0),
  visible: z.boolean().default(true),
});

const courseUpdate = courseBody.partial();

const listQuery = paginationSchema.extend({
  laboratoryId: z.uuid().optional(),
  status: z.enum(['draft', 'published', 'archived']).optional(),
  isOpenLearning: z.enum(['true', 'false']).optional(),
  creatorId: z.uuid().optional(),
  q: z.string().trim().optional(),
  include: z.string().optional(),
});

const moduleBody = z.object({
  title: z.string().trim().min(1, 'El título es obligatorio.'),
});

const reorderBody = z.object({
  orderedIds: z.array(z.uuid()).min(1, 'Hace falta al menos un id.'),
});

// ---------------------------------------------------------------------------
// Listado y detalle
// ---------------------------------------------------------------------------

courseRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = listQuery.parse(c.req.query());
  const scope = visibleCoursesFilter(user);

  // El Donante no ve cursos: se responde una página vacía, no un 403 — el
  // listado existe para todos, simplemente su alcance está vacío.
  if (!scope) return c.json(paginated([], 0, query));

  const filters = [scope];
  if (query.laboratoryId) filters.push(eq(courses.laboratoryId, query.laboratoryId));
  if (query.status) filters.push(eq(courses.status, query.status));
  if (query.creatorId) filters.push(eq(courses.creatorId, query.creatorId));
  if (query.isOpenLearning) {
    filters.push(eq(courses.isOpenLearning, query.isOpenLearning === 'true'));
  }
  if (query.q) filters.push(ilike(courses.name, `%${query.q}%`));

  const where = and(...filters);
  const db = c.get('db');

  const [rows, [total]] = await Promise.all([
    db
      .select()
      .from(courses)
      .where(where)
      .orderBy(asc(courses.name))
      .limit(query.pageSize)
      .offset((query.page - 1) * query.pageSize),
    db.select({ value: count() }).from(courses).where(where),
  ]);

  const include = parseInclude(query.include);

  // Nombre del laboratorio y del creador SIEMPRE: una tarjeta de curso los
  // muestra, y sin esto el cliente tendría que pedir un laboratorio y un
  // usuario por cada tarjeta de la grilla.
  let data: Record<string, unknown>[] = await withNames(db, rows);

  // `include=progress` agrega el avance de QUIEN PREGUNTA. Es una consulta
  // más, no una por tarjeta.
  if (include.has('progress')) {
    data = await withProgress(db, user.id, data);
  }

  if (include.has('modules')) {
    data = await Promise.all(
      data.map(async (course) => ({
        ...course,
        modules: await loadModules(db, course.id as string, include.has('lessons')),
      })),
    );
  }

  return c.json(paginated(data, total?.value ?? 0, query));
});

courseRoutes.get('/:id', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const scope = visibleCoursesFilter(user);
  if (!scope) throw notFound('No se encontró el curso.');

  const [course] = await db
    .select()
    .from(courses)
    .where(and(eq(courses.id, c.req.param('id')), scope))
    .limit(1);

  // 404 y no 403 a propósito: si un curso existe pero no está en el alcance
  // de quien pregunta, decir "no tenés permiso" ya confirma que existe.
  if (!course) throw notFound('No se encontró el curso.');

  const include = parseInclude(c.req.query('include'));
  const [named] = await withNames(db, [course]);
  let result: Record<string, unknown> = named ?? { ...course };

  if (include.has('progress')) {
    const [conProgreso] = await withProgress(db, user.id, [result]);
    if (conProgreso) result = conProgreso;
  }
  if (include.has('modules')) {
    result = {
      ...result,
      modules: await loadModules(db, course.id, include.has('lessons')),
    };
  }

  // Etiquetas, objetivos, competencias y ODS van SIEMPRE en el detalle: son
  // cuatro consultas chicas y la ficha del curso las muestra todas. Pedirlas
  // con un `include` obligaría a cada pantalla a acordarse.
  return c.json({ ...result, ...(await loadCourseMeta(db, course.id)) });
});

/** Agrega `laboratoryName` y `creatorName` a una lista de cursos. */
async function withNames(
  db: Db,
  rows: (typeof courses.$inferSelect)[],
): Promise<Record<string, unknown>[]> {
  if (rows.length === 0) return [];
  const ids = rows.map((r) => r.id);
  const extra = await db.execute<{
    id: string;
    laboratoryName: string | null;
    creatorName: string | null;
  }>(sql`
    select c.id,
           l.name as "laboratoryName",
           u.name as "creatorName"
      from courses c
      left join laboratories l on l.id = c.laboratory_id
      left join users u on u.id = c.creator_id
     where c.id in ${sql`(${sql.join(ids.map((id) => sql`${id}`), sql`, `)})`}
  `);
  const byId = new Map(extra.map((e) => [e.id, e]));
  return rows.map((r) => ({
    ...r,
    laboratoryName: byId.get(r.id)?.laboratoryName ?? null,
    creatorName: byId.get(r.id)?.creatorName ?? null,
  }));
}

/** Agrega el avance del estudiante a cada curso, en UNA consulta. */
async function withProgress(
  db: Db,
  studentId: string,
  rows: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  if (rows.length === 0) return [];
  const progress = await db.execute<{
    course_id: string;
    total_lessons: number;
    completed_lessons: number;
    ratio: string;
    is_complete: boolean;
  }>(sql`
    select course_id, total_lessons::int, completed_lessons::int,
           ratio::text, is_complete
      from course_progress where student_id = ${studentId}
  `);
  const byId = new Map(progress.map((p) => [p.course_id, p]));
  return rows.map((r) => {
    const p = byId.get(r.id as string);
    return {
      ...r,
      progress: {
        courseId: r.id,
        totalLessons: p?.total_lessons ?? 0,
        completedLessons: p?.completed_lessons ?? 0,
        ratio: Number(p?.ratio ?? 0),
        isComplete: p?.is_complete ?? false,
      },
    };
  });
}

// ---------------------------------------------------------------------------
// Crear, editar, publicar, borrar
// ---------------------------------------------------------------------------

courseRoutes.post('/', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = courseBody.parse(await c.req.json());
  const db = c.get('db');

  const [created] = await db
    .insert(courses)
    .values({
      ...body,
      laboratoryId: body.laboratoryId ?? null,
      creatorId: user.id,
      // Un curso nace en borrador: publicar es un acto explícito.
      status: 'draft',
    })
    .returning();

  return c.json(created, 201);
});

courseRoutes.patch('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = courseUpdate.parse(await c.req.json());
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);

  const [updated] = await db
    .update(courses)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(courses.id, course.id))
    .returning();

  return c.json(updated);
});

courseRoutes.post('/:id/publish', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);

  // Publicar un curso sin contenido lo haría aparecer en el portal de los
  // estudiantes como una tarjeta vacía.
  const lessonCount = await lessonCountFor(db, course.id);
  if (lessonCount === 0) {
    throw conflict('No se puede publicar un curso sin lecciones.', { lessonCount });
  }

  // Acá es donde vive la regla que la migración 0002 sacó de la base: una
  // lección a medio construir puede no tener video, un curso publicado no.
  const sinVideo = await videoLessonsWithoutSource(db, course.id);
  if (sinVideo.length > 0) {
    throw conflict(
      'Hay lecciones de video sin enlace ni archivo. Completalas antes de publicar.',
      { lessons: sinVideo },
    );
  }

  const [updated] = await db
    .update(courses)
    .set({ status: 'published', updatedAt: new Date() })
    .where(eq(courses.id, course.id))
    .returning();

  return c.json(updated);
});

courseRoutes.post('/:id/archive', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);
  const [updated] = await db
    .update(courses)
    .set({ status: 'archived', updatedAt: new Date() })
    .where(eq(courses.id, course.id))
    .returning();
  return c.json(updated);
});

/**
 * Borrado LÓGICO, y solo si el curso no tiene nada colgando.
 *
 * Decisión B.7: con vínculos a módulos de Ruta o con progreso de estudiantes
 * se responde 409 con el detalle de qué lo bloquea, y la acción ofrecida es
 * archivar. Nunca borrado físico desde acá.
 */
courseRoutes.delete('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);

  const blockers = await courseDeletionBlockers(db, course.id);
  const blocked =
    blockers.rutaModules > 0 ||
    blockers.objectives > 0 ||
    blockers.studentsWithProgress > 0;

  if (blocked) {
    throw conflict(
      'Este curso no se puede borrar porque está en uso. Archivalo en su lugar: ' +
        'deja de asignarse a estudiantes nuevos, pero quienes ya tienen progreso no se bloquean.',
      { ...blockers, suggestedAction: 'POST /courses/:id/archive' },
    );
  }

  await db
    .update(courses)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(courses.id, course.id));

  return c.body(null, 204);
});

// ---------------------------------------------------------------------------
// Módulos
// ---------------------------------------------------------------------------

courseRoutes.post('/:id/modules', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = moduleBody.parse(await c.req.json());
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);

  const [{ value: existing } = { value: 0 }] = await db
    .select({ value: count() })
    .from(courseModules)
    .where(eq(courseModules.courseId, course.id));

  const [created] = await db
    .insert(courseModules)
    .values({
      courseId: course.id,
      title: body.title,
      orderIndex: existing + 1,
    })
    .returning();

  return c.json(created, 201);
});

/**
 * Reordena TODOS los módulos de un curso de una sola vez.
 *
 * Un PATCH por módulo no sirve: `unique(course_id, order_index)` haría fallar
 * el primer intercambio, y a mitad de camino el orden quedaría inconsistente.
 * Acá se hace en una transacción y en dos pasos —primero a índices negativos,
 * después a los definitivos— para no chocar con esa restricción.
 */
courseRoutes.put('/:id/modules/order', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const { orderedIds } = reorderBody.parse(await c.req.json());
  const db = c.get('db');
  const course = await loadEditableCourse(db, c.req.param('id'), user);

  const existing = await db
    .select({ id: courseModules.id })
    .from(courseModules)
    .where(eq(courseModules.courseId, course.id));

  const existingIds = new Set(existing.map((m) => m.id));
  const missing = existing.filter((m) => !orderedIds.includes(m.id));
  const alien = orderedIds.filter((id) => !existingIds.has(id));

  if (alien.length > 0 || missing.length > 0) {
    throw conflict(
      'La lista de reordenamiento tiene que incluir exactamente los módulos de este curso, una sola vez cada uno.',
      { alien, missing: missing.map((m) => m.id) },
    );
  }

  await db.transaction(async (tx) => {
    for (const [i, id] of orderedIds.entries()) {
      await tx
        .update(courseModules)
        .set({ orderIndex: -(i + 1) })
        .where(eq(courseModules.id, id));
    }
    for (const [i, id] of orderedIds.entries()) {
      await tx
        .update(courseModules)
        .set({ orderIndex: i + 1, updatedAt: new Date() })
        .where(eq(courseModules.id, id));
    }
  });

  return c.json(await loadModules(db, course.id, false));
});

export const moduleRoutes = new Hono<AppEnv>();
moduleRoutes.use('*', requireAuth);

moduleRoutes.patch('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = moduleBody.parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadEditableModule(db, c.req.param('id'), user);

  const [updated] = await db
    .update(courseModules)
    .set({ title: body.title, updatedAt: new Date() })
    .where(eq(courseModules.id, mod.id))
    .returning();

  return c.json(updated);
});

moduleRoutes.delete('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const mod = await loadEditableModule(db, c.req.param('id'), user);

  // Los módulos no llevan `deleted_at`: viven dentro de un curso, que sí lo
  // tiene. Se borran de verdad y sus lecciones caen por CASCADE.
  await db.delete(courseModules).where(eq(courseModules.id, mod.id));
  await renumberModules(c.get('db'), mod.courseId);
  return c.body(null, 204);
});

// ---------------------------------------------------------------------------
// Helpers compartidos
// ---------------------------------------------------------------------------

type Db = AppEnv['Variables']['db'];

async function loadModules(db: Db, courseId: string, withLessons: boolean) {
  const mods = await db
    .select()
    .from(courseModules)
    .where(eq(courseModules.courseId, courseId))
    .orderBy(asc(courseModules.orderIndex));

  if (!withLessons) return mods;

  return Promise.all(
    mods.map(async (m) => ({
      ...m,
      lessons: await loadLessons(db, m.id),
    })),
  );
}

/**
 * Lecciones de un módulo, con el contenido que la pantalla necesita para
 * mostrarlas: las preguntas del quiz y la configuración de la actividad.
 *
 * **La clave de respuestas NUNCA sale de acá.** `answer_index` y `answer_text`
 * se quedan en la base: el quiz se califica en el servidor
 * (`POST /lessons/:id/quiz-attempt`). En la versión con Hive la respuesta
 * correcta viajaba al navegador dentro del curso, así que cualquiera podía
 * leerla desde las herramientas de desarrollo.
 */
async function loadLessons(db: Db, moduleId: string) {
  return db.execute<Record<string, unknown>>(sql`
    select l.id, l.title, l.type, l.description,
           l.duration_min as "durationMin", l.order_index as "orderIndex",
           l.resource_s3_key as "resourceS3Key",
           l.resource_file_name as "resourceFileName",
           l.external_url as "externalUrl",
           l.video_type as "videoType", l.video_url as "videoUrl",
           l.video_s3_key as "videoS3Key",
           l.video_duration_sec as "videoDurationSec",
           coalesce((
             select json_agg(json_build_object(
                      'id', q.id, 'kind', q.kind, 'question', q.question,
                      'options', coalesce((
                        select json_agg(o.text order by o.order_index)
                          from quiz_question_options o
                         where o.quiz_question_id = q.id), '[]'::json))
                    order by q.order_index)
               from quiz_questions q where q.lesson_id = l.id), '[]'::json
           ) as quiz,
           (select json_build_object(
                     'description', a.description,
                     'deadline', a.deadline::text,
                     'requiresFile', a.requires_file,
                     'requiresText', a.requires_text,
                     'maxFiles', a.max_files,
                     'gradingMode', a.grading_mode,
                     'rubric', coalesce((
                       select json_agg(json_build_object(
                                'criterion', r.criterion, 'points', r.points)
                              order by r.order_index)
                         from activity_rubric_items r
                        where r.lesson_id = a.lesson_id), '[]'::json))
              from lesson_activities a where a.lesson_id = l.id) as activity
      from lessons l
     where l.course_module_id = ${moduleId}
     order by l.order_index
  `);
}

/** Etiquetas, objetivos, competencias y ODS de un curso. */
async function loadCourseMeta(db: Db, courseId: string) {
  const [tags, objectives, competencies, ods] = await Promise.all([
    db.execute<{ tag: string }>(
      sql`select tag from course_tags where course_id = ${courseId} order by tag`,
    ),
    db.execute<{ id: string; category: string | null; text: string }>(sql`
      select id, category, text from course_objectives
       where course_id = ${courseId} order by order_index
    `),
    db.execute<{ code: string }>(sql`
      select competency_code as code from course_competencies
       where course_id = ${courseId} order by competency_code
    `),
    db.execute<{ code: string }>(sql`
      select ods_code as code from course_ods
       where course_id = ${courseId} order by ods_code
    `),
  ]);

  return {
    tags: tags.map((t) => t.tag),
    objectives,
    competencies: competencies.map((r) => r.code),
    ods: ods.map((r) => r.code),
  };
}

/** Carga un curso vivo y confirma que quien pide puede editarlo. */
export async function loadEditableCourse(
  db: Db,
  courseId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [course] = await db
    .select()
    .from(courses)
    .where(and(eq(courses.id, courseId), isNull(courses.deletedAt)))
    .limit(1);
  if (!course) throw notFound('No se encontró el curso.');
  assertCanEditCourse(user, course);
  return course;
}

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

/** Deja los índices consecutivos (1..n) después de borrar un módulo. */
async function renumberModules(db: Db, courseId: string) {
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo
        from course_modules where course_id = ${courseId}
    )
    update course_modules m
       set order_index = -o.nuevo
      from ordenados o where o.id = m.id
  `);
  await db.execute(sql`
    update course_modules set order_index = -order_index
     where course_id = ${courseId} and order_index < 0
  `);
}

/** Lanza 403 si el rol no puede crear contenido. Reutilizado por lecciones. */
export function assertContentRole(user: ReturnType<typeof currentUser>): void {
  if (!(CONTENT_ROLES as readonly string[]).includes(user.role)) {
    throw forbidden('Solo un LXD o un administrador puede editar contenido.');
  }
}
