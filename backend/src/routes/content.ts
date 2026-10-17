import { and, asc, desc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import type { Database } from '../db/client';
import {
  calendarEvents,
  clients,
  communicationResources,
  courses,
  evidences,
  laboratories,
  notifications,
} from '../db/schema';
import { TIPOS_DESDE_LA_APP } from '../lib/avisos';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import { parcial } from '../lib/parcial';
import {
  ADMIN_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';
import { delMismoCliente } from '../services/frontera-de-cliente';

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
  const body = parcial(evidenceBody).parse(await c.req.json());
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

const TIPOS_DE_EVENTO = [
  'open_learning_sync',
  'ruta_impacto',
  'mentoria',
  'laboratorio',
  'organizacion',
] as const;
type TipoDeEvento = (typeof TIPOS_DE_EVENTO)[number];

const eventBody = z.object({
  title: z.string().trim().min(1, 'El título es obligatorio.'),
  description: z.string().trim().default(''),
  startsAt: z.iso.datetime(),
  type: z.enum(TIPOS_DE_EVENTO),
  meetLink: z.string().trim().default(''),
  guests: z.string().trim().default(''),
  courseId: z.uuid().nullable().optional(),
  laboratoryId: z.uuid().nullable().optional(),
  clientId: z.uuid().nullable().optional(),
});

/**
 * Quién ve cada evento:
 *
 * - **De un curso** (`open_learning_sync`): todo el que lo cursa
 *   (estudiantes o empleados), quien lo creó y, si el curso es de una
 *   empresa, su supervisor.
 * - **De un laboratorio** (`laboratorio`, y la `mentoria` que agenda el
 *   Mentor): sus estudiantes, sus mentores y los asesores de su universidad.
 * - **De una organización** (`organizacion`): toda la gente de ese cliente.
 * - **De la Ruta de Impacto** (`ruta_impacto`): todo el mundo Enactus.
 *
 * El admin ve todo. Empresa (patrocinadora) y Donante no tienen calendario.
 */
function alcanceDelCalendario(user: AuthUser) {
  const alive = isNull(calendarEvents.deletedAt);
  const cliente = user.clientId;
  const deSuOrganizacion = cliente
    ? sql`(${calendarEvents.type}::text = 'organizacion' and ${calendarEvents.clientId} = ${cliente})`
    : sql`false`;

  if (user.role === 'admin' || user.role === 'superadmin') return alive;
  if (user.role === 'lxd') {
    return and(
      alive,
      sql`(
        ${calendarEvents.courseId} in (select c.id from courses c where c.creator_id = ${user.id})
        or ${calendarEvents.createdBy} = ${user.id}
        or (${calendarEvents.type}::text = 'laboratorio'
            and ${calendarEvents.laboratoryId} in (select c.laboratory_id from courses c
                                                    where c.creator_id = ${user.id}))
        or ${deSuOrganizacion}
      )`,
    )!;
  }
  if (user.role === 'supervisor') {
    return and(
      alive,
      cliente
        ? sql`(
            ${deSuOrganizacion}
            or ${calendarEvents.courseId} in (select c.id from courses c where c.client_id = ${cliente})
          )`
        : sql`false`,
    )!;
  }
  if (user.role === 'mentor') {
    return and(
      alive,
      sql`(${calendarEvents.type} = 'ruta_impacto'
           or ${calendarEvents.laboratoryId} in (select lm.laboratory_id
                                                   from laboratory_mentors lm
                                                  where lm.user_id = ${user.id})
           or ${deSuOrganizacion})`,
    )!;
  }
  if (user.role === 'advisor') {
    return and(
      alive,
      sql`(${calendarEvents.type} = 'ruta_impacto'
           or ${calendarEvents.laboratoryId} in (
                select sl.laboratory_id from student_laboratories sl
                  join users u on u.id = sl.student_id
                 where u.university = ${user.university} and u.university <> '')
           or ${deSuOrganizacion})`,
    )!;
  }
  if (isStudentLike(user.role)) {
    const esEnactus = user.studentType === 'enactus';
    return and(
      alive,
      sql`(
        (${calendarEvents.type} = 'ruta_impacto' and ${esEnactus})
        or (${calendarEvents.type}::text in ('mentoria', 'laboratorio')
            and ${calendarEvents.laboratoryId} in (select sl.laboratory_id
                                                     from student_laboratories sl
                                                    where sl.student_id = ${user.id}))
        or (${calendarEvents.type} = 'open_learning_sync'
            and ${calendarEvents.courseId} in (select a.course_id
                                                 from student_course_access a
                                                where a.student_id = ${user.id}))
        or ${deSuOrganizacion}
      )`,
    )!;
  }
  return null;
}

calendarRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = paginationSchema.parse(c.req.query());
  const db = c.get('db');
  const scope = alcanceDelCalendario(user);
  if (!scope) return c.json(paginated([], 0, query));

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

/** A qué apunta un evento: solo lo que su tipo lleva; lo demás, nulo. */
interface DestinoDelEvento {
  type: TipoDeEvento;
  courseId: string | null;
  laboratoryId: string | null;
  clientId: string | null;
}

function destinoDe(e: {
  type: TipoDeEvento;
  courseId?: string | null | undefined;
  laboratoryId?: string | null | undefined;
  clientId?: string | null | undefined;
}): DestinoDelEvento {
  return {
    type: e.type,
    courseId: e.type === 'open_learning_sync' ? (e.courseId ?? null) : null,
    laboratoryId:
      e.type === 'laboratorio' || e.type === 'mentoria' ? (e.laboratoryId ?? null) : null,
    clientId: e.type === 'organizacion' ? (e.clientId ?? null) : null,
  };
}

/**
 * Quién agenda qué:
 *
 * - **Admin**: cualquier curso, laboratorio u organización, y la Ruta.
 * - **LXD**: los cursos que creó, los laboratorios de esos cursos y su
 *   propia organización. Un LXD sin cliente es del equipo de eduXaction
 *   (sin frontera, como el admin): elige la organización.
 * - **Mentor**: eventos de la Ruta y mentorías, como siempre.
 */
async function assertPuedeAgendar(db: Database, user: AuthUser, d: DestinoDelEvento) {
  const esAdmin = user.role === 'admin' || user.role === 'superadmin';
  const permitidos: readonly string[] = esAdmin
    ? TIPOS_DE_EVENTO
    : user.role === 'lxd'
      ? ['open_learning_sync', 'laboratorio', 'organizacion']
      : user.role === 'mentor'
        ? ['ruta_impacto', 'mentoria']
        : [];
  if (!permitidos.includes(d.type)) {
    throw forbidden(`Su rol no puede crear eventos de tipo ${d.type}.`);
  }

  if (d.type === 'open_learning_sync') {
    if (!d.courseId) throw badRequest('Elija el curso del evento.');
    const [curso] = await db
      .select({ creatorId: courses.creatorId })
      .from(courses)
      .where(eq(courses.id, d.courseId))
      .limit(1);
    if (!curso) throw notFound('No se encontró el curso.');
    if (!esAdmin && curso.creatorId !== user.id) {
      throw forbidden('Solo puede agendar en los cursos que usted creó.');
    }
  }

  if (d.type === 'laboratorio') {
    if (!d.laboratoryId) throw badRequest('Elija el laboratorio del evento.');
    const [lab] = await db
      .select({ id: laboratories.id })
      .from(laboratories)
      .where(eq(laboratories.id, d.laboratoryId))
      .limit(1);
    if (!lab) throw notFound('No se encontró el laboratorio.');
    if (!esAdmin) {
      const [suyo] = await db
        .select({ id: courses.id })
        .from(courses)
        .where(and(eq(courses.creatorId, user.id), eq(courses.laboratoryId, d.laboratoryId)))
        .limit(1);
      if (!suyo) throw forbidden('Solo puede agendar en los laboratorios de sus cursos.');
    }
  }

  if (d.type === 'organizacion') {
    if (!d.clientId) throw badRequest('Elija la organización del evento.');
    const [cliente] = await db
      .select({ id: clients.id })
      .from(clients)
      .where(eq(clients.id, d.clientId))
      .limit(1);
    if (!cliente) throw notFound('No se encontró el cliente.');
    if (!esAdmin && user.clientId && d.clientId !== user.clientId) {
      throw forbidden('Solo puede agendar para su propia organización.');
    }
  }
}

/**
 * Para qué organizaciones puede agendar quien pregunta: la suya, si es de
 * un cliente; todas las activas, si es admin o del equipo de eduXaction.
 * Es lo que ofrece la pantalla al elegir «toda la organización».
 */
calendarRoutes.get('/organizaciones', requireRole('admin', 'superadmin', 'lxd'), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const esAdmin = user.role === 'admin' || user.role === 'superadmin';
  const filas = await db
    .select({ id: clients.id, name: clients.name })
    .from(clients)
    .where(
      !esAdmin && user.clientId
        ? eq(clients.id, user.clientId)
        : eq(clients.active, true),
    )
    .orderBy(asc(clients.name));
  return c.json({ data: filas });
});

calendarRoutes.post('/', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const body = eventBody.parse(await c.req.json());
  const destino = destinoDe(body);
  await assertPuedeAgendar(db, user, destino);

  const [created] = await db
    .insert(calendarEvents)
    .values({
      ...body,
      ...destino,
      startsAt: new Date(body.startsAt),
      createdBy: user.id,
    })
    .returning();
  return c.json(created, 201);
});

calendarRoutes.patch('/:id', async (c) => {
  const user = currentUser(c);
  const { startsAt, ...body } = parcial(eventBody).parse(await c.req.json());
  const db = c.get('db');
  const event = await loadEvent(db, c.req.param('id'));
  assertOwnsEvent(user.role, user.id, event.createdBy);

  // Lo que queda después del cambio, completo: cambiar de curso (o de tipo)
  // se revisa igual que crear.
  const destino = destinoDe({
    type: body.type ?? event.type,
    courseId: body.courseId !== undefined ? body.courseId : event.courseId,
    laboratoryId: body.laboratoryId !== undefined ? body.laboratoryId : event.laboratoryId,
    clientId: body.clientId !== undefined ? body.clientId : event.clientId,
  });
  await assertPuedeAgendar(db, user, destino);

  const [updated] = await db
    .update(calendarEvents)
    .set({
      ...body,
      ...destino,
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

function assertOwnsEvent(role: string, userId: string, createdBy: string | null): void {
  if (role === 'admin' || role === 'superadmin') return;
  if (createdBy === userId) return;
  throw forbidden('Solo puede editar los eventos que usted creó.');
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

/**
 * El tipo de aviso que manda la app, para que quien lo recibe lo lea en su
 * idioma (ver `lib/avisos.ts`). Opcional: un aviso sin tipo se muestra con su
 * título y su texto, tal como se escribieron.
 */
const tipoDeAviso = {
  kind: z.enum(TIPOS_DESDE_LA_APP).optional(),
  params: z.record(z.string(), z.string().max(300)).optional(),
};

const notifyBody = z.object({
  userIds: z
    .array(z.uuid())
    .min(1, 'Falta a quién avisarle.')
    .max(200, 'Son demasiados destinatarios para un solo aviso.'),
  title: z.string().trim().min(1, 'El aviso necesita un título.'),
  body: z.string().trim().default(''),
  ...tipoDeAviso,
});

/**
 * Manda un aviso a una o varias personas.
 *
 * **A quién se le puede avisar es una pregunta de permisos, no de formulario.**
 * La regla es una sola y reusa alcances que ya existen: se le puede avisar a
 * quien uno ya podría ver — el alcance de `GET /users`— o, si quien manda es
 * Donante o Empresa, a cualquier estudiante Enactus, que es exactamente lo que
 * BuscaTalento ofrece hacer.
 *
 * Un destinatario fuera de alcance responde 403 con **cuántos**, nunca con
 * quiénes: decir "estos tres ids no existen y estos dos sí" convertiría el
 * endpoint en una forma de enumerar la plataforma.
 *
 * Nadie recibe el correo de nadie: el aviso llega a la bandeja de la persona
 * dentro de la plataforma. Es la razón por la que BuscaTalento puede mostrar
 * perfiles sin mostrar datos de contacto.
 */
notificationRoutes.post('/', async (c) => {
  const user = currentUser(c);
  const body = notifyBody.parse(await c.req.json());
  const db = c.get('db');

  const destinatarios = [...new Set(body.userIds)];
  const permitidos = await notifiableUserIds(db, user, destinatarios);

  if (permitidos.length !== destinatarios.length) {
    throw forbidden(
      'Hay destinatarios a los que su rol no puede escribirles.',
    );
  }

  const created = await db
    .insert(notifications)
    .values(
      permitidos.map((userId) => ({
        userId,
        title: body.title,
        body: body.body,
        kind: body.kind ?? null,
        params: body.kind ? (body.params ?? {}) : null,
      })),
    )
    .returning({ id: notifications.id });

  return c.json({ sent: created.length }, 201);
});

/**
 * De los ids pedidos, cuáles puede notificar quien manda.
 *
 * Se resuelve con UNA consulta que replica los dos alcances en su `where`, en
 * vez de traer los usuarios y filtrarlos en memoria: la lista puede ser de
 * doscientos y la comprobación tiene que ser barata para no invitar a saltarla.
 */
async function notifiableUserIds(
  db: AppEnv['Variables']['db'],
  sender: ReturnType<typeof currentUser>,
  ids: string[],
): Promise<string[]> {
  // El admin se salta el ALCANCE, no la EXISTENCIA. Devolverle los ids tal
  // cual dejaba que uno inexistente llegara al insert y reventara contra la
  // clave ajena: un 500 donde correspondía un 403.
  const esAdmin = sender.role === 'admin' || sender.role === 'superadmin';

  // Donante y Empresa alcanzan a todo estudiante Enactus: es el alcance de
  // BuscaTalento, y sin él la pantalla ofrecería contactar a alguien que
  // después no puede contactar.
  const porTalento =
    sender.role === 'donor' || sender.role === 'company'
      ? sql`(u.student_type = 'enactus' and u.role in ('student', 'alumni'))`
      : sql`false`;

  const alcancePropio = (() => {
    if (esAdmin) return sql`true`;
    if (sender.role === 'advisor') {
      return sql`(u.university = ${sender.university} and u.university <> '')`;
    }
    if (sender.role === 'lxd') {
      return sql`u.id in (select a.student_id from student_course_access a
                            join courses c on c.id = a.course_id
                           where c.creator_id = ${sender.id})`;
    }
    if (sender.role === 'mentor') {
      return sql`u.id in (select sl.student_id from student_laboratories sl
                           where sl.laboratory_id in (
                             select lm.laboratory_id from laboratory_mentors lm
                              where lm.user_id = ${sender.id}))`;
    }
    if (sender.role === 'company') {
      return sql`u.company_id = ${sender.id}`;
    }
    if (sender.role === 'donor') {
      return sql`u.donor_id = ${sender.id}`;
    }
    // Estudiante y alumni no mandan avisos a nadie.
    return sql`false`;
  })();

  const rows = await db.execute<{ id: string }>(sql`
    select u.id from users u
     where u.deleted_at is null
       and u.id = any(${sql.param(ids)}::uuid[])
       and (${alcancePropio} or ${porTalento})
       and ${delMismoCliente(sender, sql`u.id`)}
  `);
  return rows.map((r) => r.id);
}

/**
 * Le avisa al equipo de administración, sin decir quiénes son.
 *
 * Existe porque la alternativa era peor: la pantalla de un aliado buscaba el
 * correo de un admin en la lista completa de usuarios y abría el cliente de
 * correo. Esa lista ya no existe para un aliado —y no debería—, así que el
 * aviso va por la bandeja de la plataforma y a quién le llega lo resuelve el
 * servidor.
 *
 * Cualquier cuenta con sesión puede usarlo: es el canal de "necesito ayuda".
 * Va acotado a 500 caracteres para que no se convierta en otra cosa.
 */
notificationRoutes.post('/admins', async (c) => {
  const user = currentUser(c);
  const body = z
    .object({
      title: z.string().trim().min(1, 'El aviso necesita un título.').max(120),
      body: z.string().trim().max(500).default(''),
      ...tipoDeAviso,
    })
    .parse(await c.req.json());

  const db = c.get('db');
  const admins = await db.execute<{ id: string }>(sql`
    select id from users
     where role in ('admin', 'superadmin') and deleted_at is null
  `);
  if (admins.length === 0) {
    throw conflict('No hay ninguna cuenta de administración registrada.');
  }

  // Quién lo mandó va en el cuerpo, no en el título: el título lo escribe
  // quien pide, y sin la firma el aviso llegaría sin remitente.
  await db.insert(notifications).values(
    admins.map((a) => ({
      userId: a.id,
      title: body.title,
      body: `${body.body}\n\n— ${user.name} (${user.email})`.trim(),
      // La firma también va en los datos, para que la app la agregue al texto
      // que arma en el idioma de quien lee. La pone el servidor, no quien pide.
      kind: body.kind ?? null,
      params: body.kind
        ? { ...(body.params ?? {}), remitente: user.name, correo: user.email }
        : null,
    })),
  );

  return c.json({ sent: admins.length }, 201);
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
