import { and, asc, count, eq, ilike, isNull, or, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { auditLog, users } from '../db/schema';
import { limitedUser, publicUser } from '../lib/dto';
import { conflict, forbidden, notFound } from '../lib/errors';
import { hashPassword } from '../lib/password';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  ADMIN_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * Personas de la plataforma.
 *
 * Este router no existía, y su ausencia era el motivo de que cinco portales
 * siguieran sin migrar: todos necesitan saber "quiénes son mis estudiantes",
 * "quién es el mentor de este laboratorio", "quiénes son mis LXD".
 *
 * La versión con Hive resolvía eso teniendo la tabla entera de usuarios en el
 * navegador, con contraseña incluida. Acá cada rol ve **solo a quien le
 * corresponde**, y de las personas que no son de su equipo ve una ficha
 * recortada, sin cédula, sin teléfono y sin correo.
 */
export const userRoutes = new Hono<AppEnv>();
userRoutes.use('*', requireAuth);

const listQuery = paginationSchema.extend({
  role: z.string().optional(),
  laboratoryId: z.uuid().optional(),
  groupId: z.uuid().optional(),
  companyId: z.uuid().optional(),
  q: z.string().trim().optional(),
});

/**
 * A quién puede ver cada rol.
 *
 * Devuelve `null` cuando el rol no ve a nadie: eso responde una página vacía,
 * no un 403 — el listado existe para todos, su alcance simplemente está vacío.
 *
 * Cada regla es la MISMA que ya usa el resto de la API para ese rol, para que
 * no haya dos definiciones de "mis estudiantes" que puedan discrepar.
 */
function scopeFor(user: AuthUser) {
  const alive = isNull(users.deletedAt);

  if (user.role === 'admin' || user.role === 'superadmin') return alive;

  if (user.role === 'advisor') {
    // Los de su universidad. Sin universidad no ve a nadie: si no, un asesor
    // recién creado vería a todas las personas sin universidad asignada.
    if (!user.university) return null;
    return and(alive, eq(users.university, user.university))!;
  }

  if (user.role === 'lxd') {
    // Quienes tienen acceso a alguno de sus cursos.
    return and(
      alive,
      sql`${users.id} in (select a.student_id from student_course_access a
                            join courses c on c.id = a.course_id
                           where c.creator_id = ${user.id})`,
    )!;
  }

  if (user.role === 'mentor') {
    // Los estudiantes de sus laboratorios, y los mentores con los que los
    // comparte.
    return and(
      alive,
      sql`(${users.id} in (select sl.student_id from student_laboratories sl
                            where sl.laboratory_id in (
                              select lm.laboratory_id from laboratory_mentors lm
                               where lm.user_id = ${user.id}))
           or ${users.id} in (select lm2.user_id from laboratory_mentors lm2
                               where lm2.laboratory_id in (
                                 select lm.laboratory_id from laboratory_mentors lm
                                  where lm.user_id = ${user.id})))`,
    )!;
  }

  if (user.role === 'company') {
    // Su gente: quien tiene `company_id` apuntando a la empresa, más los
    // estudiantes de los laboratorios que patrocina.
    return and(
      alive,
      sql`(${users.companyId} = ${user.id}
           or ${users.id} in (select sl.student_id from student_laboratories sl
                               where sl.laboratory_id in (
                                 select l.id from laboratories l
                                  where l.sponsor_company_id = ${user.id})))`,
    )!;
  }

  if (user.role === 'donor') {
    // Solo los estudiantes que apoya.
    return and(alive, eq(users.donorId, user.id))!;
  }

  // Estudiante y alumni: no tienen directorio de personas. Su equipo llega
  // dentro del proyecto, con el rol de cada integrante.
  return null;
}

/**
 * ¿Se le pueden mostrar los datos de contacto de esta persona a quien
 * pregunta?
 *
 * La regla es la misma que separa `publicUser` de `limitedUser`: correo,
 * teléfono y cédula son datos personales. Los ve quien administra la
 * plataforma y quien acompaña a esa persona; el resto ve la ficha recortada.
 */
function canSeeContactDetails(viewer: AuthUser): boolean {
  return (
    viewer.role === 'admin' ||
    viewer.role === 'superadmin' ||
    viewer.role === 'advisor' ||
    viewer.role === 'lxd' ||
    viewer.role === 'mentor'
  );
}

userRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = listQuery.parse(c.req.query());
  const scope = scopeFor(user);
  if (!scope) return c.json(paginated([], 0, query));

  const filters = [scope];
  if (query.role) {
    // Se acepta una lista: `?role=student,alumni`.
    const roles = query.role.split(',').map((r) => r.trim()).filter(Boolean);
    if (roles.length > 0) {
      filters.push(
        or(...roles.map((r) => eq(users.role, r as AuthUser['role'])))!,
      );
    }
  }
  if (query.laboratoryId) {
    filters.push(
      sql`${users.id} in (select sl.student_id from student_laboratories sl
                           where sl.laboratory_id = ${query.laboratoryId})`,
    );
  }
  if (query.groupId) {
    filters.push(
      sql`${users.id} in (select gm.user_id from group_members gm
                           where gm.group_id = ${query.groupId})`,
    );
  }
  if (query.companyId) filters.push(eq(users.companyId, query.companyId));
  if (query.q) filters.push(ilike(users.name, `%${query.q}%`));

  const where = and(...filters);
  const db = c.get('db');
  const [rows, [total]] = await Promise.all([
    db
      .select()
      .from(users)
      .where(where)
      .orderBy(asc(users.name))
      .limit(query.pageSize)
      .offset((query.page - 1) * query.pageSize),
    db.select({ value: count() }).from(users).where(where),
  ]);

  const shape = canSeeContactDetails(user) ? publicUser : limitedUser;
  return c.json(paginated(rows.map(shape), total?.value ?? 0, query));
});

userRoutes.get('/:id', async (c) => {
  const user = currentUser(c);
  const id = c.req.param('id');

  // Cualquiera puede pedirse a sí mismo, sin pasar por el alcance.
  if (id === user.id) return c.json(publicUser(user));

  const scope = scopeFor(user);
  // 404 y no 403: si la persona existe pero está fuera del alcance de quien
  // pregunta, un 403 ya confirmaría que existe.
  if (!scope) throw notFound('No encontramos esa persona.');

  const [found] = await c
    .get('db')
    .select()
    .from(users)
    .where(and(eq(users.id, id), scope))
    .limit(1);
  if (!found) throw notFound('No encontramos esa persona.');

  return c.json(canSeeContactDetails(user) ? publicUser(found) : limitedUser(found));
});

// ---------------------------------------------------------------------------
// Alta y edición: solo administración
// ---------------------------------------------------------------------------

const createBody = z.object({
  name: z.string().trim().min(1, 'El nombre es obligatorio.'),
  email: z.email('El correo no es válido.'),
  password: z.string().min(6, 'La contraseña necesita al menos 6 caracteres.'),
  role: z.enum([
    'superadmin', 'admin', 'lxd', 'mentor', 'advisor',
    'company', 'donor', 'student', 'alumni',
  ]),
  studentType: z.enum(['enactus', 'open_learning']).nullable().optional(),
  phone: z.string().trim().default(''),
  cedula: z.string().trim().default(''),
  city: z.string().trim().default(''),
  university: z.string().trim().default(''),
  career: z.string().trim().default(''),
  companyName: z.string().trim().default(''),
  impactCode: z.string().trim().nullable().optional(),
  companyId: z.uuid().nullable().optional(),
  donorId: z.uuid().nullable().optional(),
  profile: z.record(z.string(), z.unknown()).optional(),
});

/**
 * El tipo de estudiante es obligatorio para un estudiante y prohibido para
 * cualquier otro rol: es lo que separa eduXaction de Open Learning en TODA la
 * API, y una cuenta sin él quedaría en un limbo donde ninguna de las dos
 * reglas de aislamiento aplica.
 */
function assertStudentType(role: string, studentType?: string | null): void {
  if (isStudentLike(role)) {
    if (!studentType) {
      throw conflict(
        'Una cuenta de estudiante necesita su tipo: eduXaction u Open Learning.',
      );
    }
    return;
  }
  if (studentType) {
    throw conflict(`El rol ${role} no lleva tipo de estudiante.`);
  }
}

userRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const admin = currentUser(c);
  const body = createBody.parse(await c.req.json());
  const db = c.get('db');

  assertStudentType(body.role, body.studentType);

  // Solo un superadmin crea otro superadmin: si no, un admin podría
  // ascenderse creando una cuenta y entrando con ella.
  if (body.role === 'superadmin' && admin.role !== 'superadmin') {
    throw forbidden('Solo un superadmin puede crear otro superadmin.');
  }

  const [existing] = await db
    .select({ id: users.id })
    .from(users)
    .where(sql`lower(${users.email}) = lower(${body.email})`)
    .limit(1);
  if (existing) throw conflict('Ya existe una cuenta con ese correo.');

  const { password, ...rest } = body;
  const [created] = await db
    .insert(users)
    .values({
      ...rest,
      studentType: body.studentType ?? null,
      passwordHash: await hashPassword(password),
      // `canGrade*` NO se acepta en el alta: se cambia por su propio endpoint,
      // que deja registro en `audit_log`.
    })
    .returning();

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'user.create',
    entityType: 'user',
    entityId: created!.id,
    newValue: { role: created!.role, email: created!.email },
    ip: c.get('requestIp'),
  });

  return c.json(publicUser(created!), 201);
});

const updateBody = createBody.partial().omit({ password: true });

userRoutes.patch('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const admin = currentUser(c);
  const body = updateBody.parse(await c.req.json());
  const db = c.get('db');
  const id = c.req.param('id');

  const [before] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, id), isNull(users.deletedAt)))
    .limit(1);
  if (!before) throw notFound('No encontramos esa persona.');

  const role = body.role ?? before.role;
  const studentType =
    body.studentType !== undefined ? body.studentType : before.studentType;
  assertStudentType(role, studentType);

  if (role === 'superadmin' && admin.role !== 'superadmin') {
    throw forbidden('Solo un superadmin puede otorgar el rol de superadmin.');
  }

  const [updated] = await db
    .update(users)
    .set({ ...body, studentType, updatedAt: new Date() })
    .where(eq(users.id, id))
    .returning();

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'user.update',
    entityType: 'user',
    entityId: id,
    oldValue: { role: before.role, studentType: before.studentType },
    newValue: { role: updated!.role, studentType: updated!.studentType },
    ip: c.get('requestIp'),
  });

  return c.json(publicUser(updated!));
});

userRoutes.delete('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const admin = currentUser(c);
  const id = c.req.param('id');

  // Nadie se borra a sí mismo: dejaría la plataforma sin quien la administre
  // si fuera la última cuenta con ese rol, y es casi siempre un accidente.
  if (id === admin.id) {
    throw conflict('No podés eliminar tu propia cuenta.');
  }

  const db = c.get('db');
  const [deleted] = await db
    .update(users)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(users.id, id), isNull(users.deletedAt)))
    .returning({ id: users.id, role: users.role });
  if (!deleted) throw notFound('No encontramos esa persona.');

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'user.delete',
    entityType: 'user',
    entityId: id,
    oldValue: { role: deleted.role },
    ip: c.get('requestIp'),
  });

  return c.body(null, 204);
});
