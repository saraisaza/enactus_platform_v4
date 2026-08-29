import { and, asc, desc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  calendarEvents,
  communicationResources,
  evidences,
  notifications,
} from '../db/schema';
import { forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  ADMIN_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

// ---------------------------------------------------------------------------
// Evidencias de impacto (Donante)
// ---------------------------------------------------------------------------

export const evidenceRoutes = new Hono<AppEnv>();
evidenceRoutes.use('*', requireAuth);

const evidenceBody = z.object({
  donorId: z.uuid(),
  projectId: z.uuid().nullable().optional(),
  type: z.enum(['photo', 'video', 'testimonial', 'report', 'story']),
  title: z.string().trim().min(1, 'El título es obligatorio.'),
  description: z.string().trim().default(''),
  s3Key: z.string().trim().nullable().optional(),
  fileName: z.string().trim().nullable().optional(),
  contentType: z.string().trim().nullable().optional(),
  sizeBytes: z.number().int().positive().nullable().optional(),
});

evidenceRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = paginationSchema
    .extend({ donorId: z.uuid().optional(), projectId: z.uuid().optional() })
    .parse(c.req.query());
  const db = c.get('db');

  const filters = [isNull(evidences.deletedAt)];
  if (user.role === 'donor') {
    // Un donante ve SOLO las suyas, sin importar qué pida.
    filters.push(eq(evidences.donorId, user.id));
  } else if (user.role !== 'admin' && user.role !== 'superadmin') {
    // Nadie más tiene evidencias en su portal.
    return c.json(paginated([], 0, query));
  } else if (query.donorId) {
    filters.push(eq(evidences.donorId, query.donorId));
  }
  if (query.projectId) filters.push(eq(evidences.projectId, query.projectId));

  const where = and(...filters);
  const rows = await db
    .select()
    .from(evidences)
    .where(where)
    .orderBy(desc(evidences.evidenceDate))
    .limit(query.pageSize)
    .offset((query.page - 1) * query.pageSize);
  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(evidences)
    .where(where);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

evidenceRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const body = evidenceBody.parse(await c.req.json());
  const [created] = await c
    .get('db')
    .insert(evidences)
    .values({ ...body, projectId: body.projectId ?? null })
    .returning();
  return c.json(created, 201);
});

evidenceRoutes.patch('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const body = evidenceBody.partial().parse(await c.req.json());
  const [updated] = await c
    .get('db')
    .update(evidences)
    .set({ ...body, updatedAt: new Date() })
    .where(and(eq(evidences.id, c.req.param('id')), isNull(evidences.deletedAt)))
    .returning();
  if (!updated) throw notFound('No se encontró la evidencia.');
  return c.json(updated);
});

evidenceRoutes.delete('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const [updated] = await c
    .get('db')
    .update(evidences)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(evidences.id, c.req.param('id')), isNull(evidences.deletedAt)))
    .returning({ id: evidences.id });
  if (!updated) throw notFound('No se encontró la evidencia.');
  return c.body(null, 204);
});

// ---------------------------------------------------------------------------
// Calendario
// ---------------------------------------------------------------------------

export const calendarRoutes = new Hono<AppEnv>();
calendarRoutes.use('*', requireAuth);

const eventBody = z.object({
  title: z.string().trim().min(1, 'El título es obligatorio.'),
  description: z.string().trim().default(''),
  startsAt: z.iso.datetime(),
  type: z.enum(['open_learning_sync', 'ruta_impacto', 'mentoria']),
  meetLink: z.string().trim().default(''),
  guests: z.string().trim().default(''),
  courseId: z.uuid().nullable().optional(),
  laboratoryId: z.uuid().nullable().optional(),
});

/**
 * Visibilidad por rol y tipo de evento — traduce `calendarEventsFor`:
 * `ruta_impacto` es global para el mundo Enactus; `mentoria` sigue atado al
 * laboratorio; `open_learning_sync` al curso.
 */
calendarRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = paginationSchema.parse(c.req.query());
  const db = c.get('db');
  const alive = isNull(calendarEvents.deletedAt);

  let scope = alive;
  if (user.role === 'admin' || user.role === 'superadmin') {
    // ve todo
  } else if (user.role === 'lxd') {
    scope = and(
      alive,
      sql`${calendarEvents.courseId} in (select c.id from courses c
                                          where c.creator_id = ${user.id})`,
    )!;
  } else if (user.role === 'mentor') {
    scope = and(
      alive,
      sql`(${calendarEvents.type} = 'ruta_impacto'
           or ${calendarEvents.laboratoryId} in (select lm.laboratory_id
                                                   from laboratory_mentors lm
                                                  where lm.user_id = ${user.id}))`,
    )!;
  } else if (user.role === 'advisor') {
    scope = and(
      alive,
      sql`(${calendarEvents.type} = 'ruta_impacto'
           or ${calendarEvents.laboratoryId} in (
                select sl.laboratory_id from student_laboratories sl
                  join users u on u.id = sl.student_id
                 where u.university = ${user.university} and u.university <> ''))`,
    )!;
  } else if (isStudentLike(user.role)) {
    const esEnactus = user.studentType === 'enactus';
    scope = and(
      alive,
      sql`(
        (${calendarEvents.type} = 'ruta_impacto' and ${esEnactus})
        or (${calendarEvents.type} = 'mentoria'
            and ${calendarEvents.laboratoryId} in (select sl.laboratory_id
                                                     from student_laboratories sl
                                                    where sl.student_id = ${user.id}))
        or (${calendarEvents.type} = 'open_learning_sync'
            and ${calendarEvents.courseId} in (select a.course_id
                                                 from student_course_access a
                                                where a.student_id = ${user.id}))
      )`,
    )!;
  } else {
    // Empresa y Donante no tienen calendario.
    return c.json(paginated([], 0, query));
  }

  const rows = await db
    .select()
    .from(calendarEvents)
    .where(scope)
    .orderBy(asc(calendarEvents.startsAt))
    .limit(query.pageSize)
    .offset((query.page - 1) * query.pageSize);
  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(calendarEvents)
    .where(scope);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

calendarRoutes.post('/', async (c) => {
  const user = currentUser(c);
  const body = eventBody.parse(await c.req.json());
  assertCanCreateEvent(user.role, body.type);

  const [created] = await c
    .get('db')
    .insert(calendarEvents)
    .values({
      ...body,
      startsAt: new Date(body.startsAt),
      courseId: body.courseId ?? null,
      laboratoryId: body.laboratoryId ?? null,
      createdBy: user.id,
    })
    .returning();
  return c.json(created, 201);
});

calendarRoutes.patch('/:id', async (c) => {
  const user = currentUser(c);
  const { startsAt, ...body } = eventBody.partial().parse(await c.req.json());
  const db = c.get('db');
  const event = await loadEvent(db, c.req.param('id'));
  assertOwnsEvent(user.role, user.id, event.createdBy);

  const [updated] = await db
    .update(calendarEvents)
    .set({
      ...body,
      ...(startsAt ? { startsAt: new Date(startsAt) } : {}),
      updatedAt: new Date(),
    })
    .where(eq(calendarEvents.id, event.id))
    .returning();
  return c.json(updated);
});

calendarRoutes.delete('/:id', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const event = await loadEvent(db, c.req.param('id'));
  assertOwnsEvent(user.role, user.id, event.createdBy);

  await db
    .update(calendarEvents)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(calendarEvents.id, event.id));
  return c.body(null, 204);
});

function assertCanCreateEvent(role: string, type: string): void {
  if (role === 'admin' || role === 'superadmin') return;
  if (role === 'lxd' && type === 'open_learning_sync') return;
  if (role === 'mentor' && (type === 'ruta_impacto' || type === 'mentoria')) return;
  throw forbidden(`Tu rol no puede crear eventos de tipo ${type}.`);
}

function assertOwnsEvent(role: string, userId: string, createdBy: string | null): void {
  if (role === 'admin' || role === 'superadmin') return;
  if (createdBy === userId) return;
  throw forbidden('Solo podés editar los eventos que creaste.');
}

async function loadEvent(db: AppEnv['Variables']['db'], id: string) {
  const [row] = await db
    .select()
    .from(calendarEvents)
    .where(and(eq(calendarEvents.id, id), isNull(calendarEvents.deletedAt)))
    .limit(1);
  if (!row) throw notFound('No se encontró el evento.');
  return row;
}

// ---------------------------------------------------------------------------
// Recursos de Comunicaciones
// ---------------------------------------------------------------------------

export const commResourceRoutes = new Hono<AppEnv>();
commResourceRoutes.use('*', requireAuth);

const resourceBody = z
  .object({
    title: z.string().trim().min(1, 'El título es obligatorio.'),
    description: z.string().trim().default(''),
    type: z.enum(['file', 'link']),
    fileName: z.string().trim().nullable().optional(),
    s3Key: z.string().trim().nullable().optional(),
    contentType: z.string().trim().nullable().optional(),
    sizeBytes: z.number().int().positive().nullable().optional(),
    url: z.url().nullable().optional(),
  })
  .refine((b) => (b.type === 'file' ? Boolean(b.s3Key) : Boolean(b.url)), {
    message: 'Un recurso de archivo necesita s3Key; uno de enlace, url.',
  });

/** Los publica Admin; los consultan Asesor, Mentor y LXD (solo lectura). */
const READERS = ['admin', 'superadmin', 'advisor', 'mentor', 'lxd'];

commResourceRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = paginationSchema.parse(c.req.query());
  if (!READERS.includes(user.role)) {
    return c.json(paginated([], 0, query));
  }

  const db = c.get('db');
  const where = isNull(communicationResources.deletedAt);
  const rows = await db
    .select()
    .from(communicationResources)
    .where(where)
    .orderBy(desc(communicationResources.createdAt))
    .limit(query.pageSize)
    .offset((query.page - 1) * query.pageSize);
  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(communicationResources)
    .where(where);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

commResourceRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const body = resourceBody.parse(await c.req.json());
  const [created] = await c
    .get('db')
    .insert(communicationResources)
    .values({ ...body, uploadedBy: currentUser(c).id })
    .returning();
  return c.json(created, 201);
});

commResourceRoutes.delete('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const [updated] = await c
    .get('db')
    .update(communicationResources)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(
      and(
        eq(communicationResources.id, c.req.param('id')),
        isNull(communicationResources.deletedAt),
      ),
    )
    .returning({ id: communicationResources.id });
  if (!updated) throw notFound('No se encontró el recurso.');
  return c.body(null, 204);
});

// ---------------------------------------------------------------------------
// Notificaciones
// ---------------------------------------------------------------------------

export const notificationRoutes = new Hono<AppEnv>();
notificationRoutes.use('*', requireAuth);

/** Siempre las propias: no hay parámetro para pedir las de otro. */
notificationRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = paginationSchema.parse(c.req.query());
  const db = c.get('db');

  const rows = await db
    .select()
    .from(notifications)
    .where(eq(notifications.userId, user.id))
    .orderBy(desc(notifications.createdAt))
    .limit(query.pageSize)
    .offset((query.page - 1) * query.pageSize);
  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(notifications)
    .where(eq(notifications.userId, user.id));
  const [unread] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(notifications)
    .where(and(eq(notifications.userId, user.id), isNull(notifications.readAt)));

  return c.json({
    ...paginated(rows, total?.value ?? 0, query),
    unread: unread?.value ?? 0,
  });
});

notificationRoutes.post('/read', async (c) => {
  const user = currentUser(c);
  await c
    .get('db')
    .update(notifications)
    .set({ readAt: new Date() })
    .where(and(eq(notifications.userId, user.id), isNull(notifications.readAt)));
  return c.body(null, 204);
});
