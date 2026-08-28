import { and, asc, count, eq, ilike, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { courseModules, courses, lessons } from '../db/schema';
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
  if (!include.has('modules')) {
    return c.json(paginated(rows, total?.value ?? 0, query));
  }

  const withModules = await Promise.all(
    rows.map(async (course) => ({
      ...course,
      modules: await loadModules(db, course.id, include.has('lessons')),
    })),
  );
  return c.json(paginated(withModules, total?.value ?? 0, query));
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
  if (!include.has('modules')) return c.json(course);
  return c.json({
    ...course,
    modules: await loadModules(db, course.id, include.has('lessons')),
  });
});

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
      lessons: await db
        .select()
        .from(lessons)
        .where(eq(lessons.courseModuleId, m.id))
        .orderBy(asc(lessons.orderIndex)),
    })),
  );
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
