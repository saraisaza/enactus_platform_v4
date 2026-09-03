import { and, asc, count, eq, ilike, isNull, or, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { auditLog, refreshTokens, users } from '../db/schema';
import { limitedUser, publicUser } from '../lib/dto';
import { conflict, forbidden, notFound } from '../lib/errors';
import { hashPassword } from '../lib/password';
import { paginated, paginationSchema, parseInclude } from '../lib/pagination';
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
  /** `team` y/o `progress`. Ver el handler. */
  include: z.string().optional(),
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
    // Quienes tienen acceso a alguno de sus cursos, más las cuentas de
    // empresa.
    //
    // Las empresas están acá porque el constructor de cursos deja elegir el
    // patrocinador y `PATCH /courses/:id` se lo permite al LXD: sin poder
    // listarlas, podía guardar un patrocinio pero no ver de quién. Una cuenta
    // de empresa es una organización, no una persona, y su nombre ya aparece
    // como patrocinador en todo el resto de la plataforma.
    return and(
      alive,
      sql`(${users.id} in (select a.student_id from student_course_access a
                             join courses c on c.id = a.course_id
                            where c.creator_id = ${user.id})
           or ${users.role} = 'company')`,
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
  let data: Record<string, unknown>[] = rows.map(shape);

  // `include=team,progress` agrega el equipo, el patrocinador y el avance
  // general de cada persona, en DOS consultas para toda la página.
  //
  // Es lo que necesitan las tablas de seguimiento de LXD, Mentor y Asesor.
  // Sin esto, cada fila haría cuatro peticiones: el equipo, el proyecto, el
  // patrocinador y el avance — que es exactamente lo que hacía la versión con
  // Hive, solo que contra memoria en vez de contra la red.
  const include = parseInclude(query.include);
  if (
    rows.length > 0 &&
    (include.has('team') || include.has('progress') || include.has('reviews'))
  ) {
    const ids = rows.map((r) => r.id);

    if (include.has('team')) {
      const teams = await db.execute<{
        userId: string;
        groupId: string;
        groupName: string;
        projectId: string;
        projectName: string;
        projectStage: string;
        roleInProject: string;
        sponsorName: string | null;
      }>(sql`
        select gm.user_id as "userId",
               g.id as "groupId", g.name as "groupName",
               pr.id as "projectId", pr.name as "projectName",
               pr.stage as "projectStage",
               gm.role_in_project as "roleInProject",
               nullif(sp.company_name, '') as "sponsorName"
          from group_members gm
          join groups g on g.id = gm.group_id and g.deleted_at is null
          join projects pr on pr.id = g.project_id and pr.deleted_at is null
          join users u on u.id = gm.user_id
          left join users sp on sp.id = u.company_id and sp.deleted_at is null
         where gm.user_id = any(${sql.param(ids)}::uuid[])
      `);
      const byUser = new Map(teams.map((t) => [t.userId, t]));
      data = data.map((u) => {
        const team = byUser.get(u.id as string);
        return {
          ...u,
          team: team
            ? {
                groupId: team.groupId,
                groupName: team.groupName,
                projectId: team.projectId,
                projectName: team.projectName,
                projectStage: team.projectStage,
                roleInProject: team.roleInProject,
              }
            : null,
          sponsorName: team?.sponsorName ?? null,
        };
      });
    }

    if (include.has('progress')) {
      // Avance GENERAL: el promedio de sus cursos accesibles. Se calcula
      // sobre `course_progress`, la misma vista que alimenta cada pantalla
      // de estudiante — no hay una segunda definición de "cómo va".
      const overall = await db.execute<{
        studentId: string;
        ratio: string;
        coursesTotal: number;
        coursesDone: number;
      }>(sql`
        select student_id as "studentId",
               coalesce(avg(ratio), 0)::text            as ratio,
               count(*)::int                            as "coursesTotal",
               count(*) filter (where is_complete)::int as "coursesDone"
          from course_progress
         where student_id = any(${sql.param(ids)}::uuid[])
         group by student_id
      `);
      const byStudent = new Map(overall.map((r) => [r.studentId, r]));
      data = data.map((u) => {
        const row = byStudent.get(u.id as string);
        return {
          ...u,
          overallProgress: {
            ratio: Number(row?.ratio ?? 0),
            coursesTotal: row?.coursesTotal ?? 0,
            coursesDone: row?.coursesDone ?? 0,
          },
        };
      });
    }

    if (include.has('reviews')) {
      // Cuántas entregas revisó cada mentor. El portal Empresa lo muestra por
      // mentor y además lo suma por laboratorio: sin esto serían dos consultas
      // por fila, que es justo lo que hacía la versión con Hive.
      const revisiones = await db.execute<{ mentorId: string; reviews: number }>(sql`
        select reviewed_by as "mentorId", count(*)::int as reviews
          from submissions
         where reviewed_by = any(${sql.param(ids)}::uuid[])
           and reviewed_at is not null
           and deleted_at is null
         group by reviewed_by
      `);
      const byMentor = new Map(revisiones.map((r) => [r.mentorId, r.reviews]));
      data = data.map((u) => ({
        ...u,
        reviewsCount: byMentor.get(u.id as string) ?? 0,
      }));
    }
  }

  return c.json(paginated(data, total?.value ?? 0, query));
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

/** Los roles que una cuenta de empresa puede dar de alta. */
const COMPANY_CAN_CREATE = ['lxd', 'mentor'];

userRoutes.post('/', requireRole(...ADMIN_ROLES, 'company'), async (c) => {
  const admin = currentUser(c);
  const body = createBody.parse(await c.req.json());
  const db = c.get('db');

  assertStudentType(body.role, body.studentType);

  /**
   * Una empresa da de alta a SU equipo formador, y nada más.
   *
   * Es una capacidad real del portal Empresa —una empresa que patrocina trae
   * sus propios formadores— pero acotada en las dos direcciones que importan:
   * solo los roles `lxd` y `mentor`, y la cuenta queda atada a la empresa que
   * la creó (`companyId`), lo diga o no el formulario. Sin ese amarre, una
   * empresa podría crear una cuenta suelta —o peor, otra cuenta de empresa— y
   * usarla para ver lo que su alcance no le permite.
   *
   * `canGrade*` tampoco se acepta en el alta: se cambia por su propio
   * endpoint, que además es de Admin y deja registro.
   */
  if (admin.role === 'company') {
    if (!COMPANY_CAN_CREATE.includes(body.role)) {
      throw forbidden(
        'Una empresa solo puede crear cuentas de LXD o de mentor para su equipo.',
      );
    }
    body.companyId = admin.id;
  }

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

/**
 * El parcheo acepta una contraseña NUEVA, opcional.
 *
 * Es el único camino para restablecer la de alguien que la perdió, y sin él la
 * plataforma no tenía ninguno. No se parece a los demás campos: no se guarda
 * tal cual sino hasheada, y **cierra las sesiones abiertas de esa persona** —
 * un restablecimiento que deja vivo el token anterior no restablece nada.
 */
const updateBody = createBody.partial().extend({
  password: z
    .string()
    .min(6, 'La contraseña necesita al menos 6 caracteres.')
    .optional(),
});

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

  const { password, ...campos } = body;

  const [updated] = await db
    .update(users)
    .set({
      ...campos,
      studentType,
      ...(password
        ? {
            passwordHash: await hashPassword(password),
            // Se la eligió administración, no la persona: tiene que
            // cambiarla antes de volver a usar la plataforma.
            mustChangePassword: true,
          }
        : {}),
      updatedAt: new Date(),
    })
    .where(eq(users.id, id))
    .returning();

  // Restablecer la contraseña cierra las sesiones abiertas de esa persona. Si
  // no, quien tuviera el token anterior seguiría dentro — y restablecer una
  // contraseña justamente se hace cuando se sospecha de eso.
  if (password) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(and(eq(refreshTokens.userId, id), isNull(refreshTokens.revokedAt)));
  }

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'user.update',
    entityType: 'user',
    entityId: id,
    oldValue: { role: before.role, studentType: before.studentType },
    newValue: {
      role: updated!.role,
      studentType: updated!.studentType,
      // Queda constancia de QUE se cambió, nunca de a qué.
      passwordReset: password !== undefined,
    },
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
    throw conflict('No puede eliminar su propia cuenta.');
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
