import { and, asc, count, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { laboratories } from '../db/schema';
import { notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  currentUser,
  isStudentLike,
  requireAuth,
  requireEnactus,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * Laboratorios y su Ruta de Impacto.
 *
 * TODO este router está detrás de `requireEnactus`: un estudiante de Open
 * Learning no debe poder obtener datos de laboratorios ni manipulando la URL
 * ni llamando el endpoint directamente. Recibe 403, no una lista vacía.
 */
export const labRoutes = new Hono<AppEnv>();
labRoutes.use('*', requireAuth, requireEnactus);

const listQuery = paginationSchema.extend({
  /** `all` trae toda la red en versión reducida (ver el handler). */
  scope: z.enum(['all']).optional(),
});

/** Mentor o LXD de un laboratorio, con lo justo para poder contactarlo. */
type LabStaff = {
  id: string;
  name: string;
  email: string;
  avatarS3Key: string | null;
  availability: string;
};

/** Alcance de lectura por rol, igual criterio que el de cursos. */
function scopeFor(user: AuthUser) {
  const alive = isNull(laboratories.deletedAt);
  if (user.role === 'admin' || user.role === 'superadmin') return alive;

  if (isStudentLike(user.role)) {
    return and(
      alive,
      sql`${laboratories.id} in (select sl.laboratory_id from student_laboratories sl
                                  where sl.student_id = ${user.id})`,
    )!;
  }
  if (user.role === 'mentor') {
    return and(
      alive,
      sql`${laboratories.id} in (select lm.laboratory_id from laboratory_mentors lm
                                  where lm.user_id = ${user.id})`,
    )!;
  }
  if (user.role === 'lxd') {
    return and(
      alive,
      sql`${laboratories.id} in (select c.laboratory_id from courses c
                                  where c.creator_id = ${user.id}
                                    and c.laboratory_id is not null)`,
    )!;
  }
  if (user.role === 'company') {
    // Los patrocinados a mano MÁS aquellos donde alguno de sus LXD tiene un
    // curso (misma regla que `DataProvider.labsForCompany`).
    return and(
      alive,
      sql`(${laboratories.sponsorCompanyId} = ${user.id}
           or ${laboratories.id} in (
             select c.laboratory_id from courses c
               join users u on u.id = c.creator_id
              where u.company_id = ${user.id} and c.laboratory_id is not null))`,
    )!;
  }
  if (user.role === 'advisor') {
    return and(
      alive,
      sql`${laboratories.id} in (
            select sl.laboratory_id from student_laboratories sl
              join users u on u.id = sl.student_id
             where u.university = ${user.university} and u.university <> '')`,
    )!;
  }
  // Donante: su portal no tiene laboratorios.
  return null;
}

labRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = listQuery.parse(c.req.query());

  // `scope=all`: TODOS los laboratorios de la red, en versión reducida.
  //
  // La pantalla de Laboratorios muestra "otros laboratorios de la red" para
  // que un estudiante sepa qué existe y pueda pedirle uno a su administrador.
  // No filtra nada sensible: el nombre y la descripción de cada laboratorio ya
  // salen SIN sesión en `/site-content`, para la portada. Lo que no se
  // devuelve acá es la estructura de la Ruta ni el avance de nadie.
  if (query.scope === 'all') {
    const rows = await c.get('db').execute<{
      id: string;
      name: string;
      description: string;
      teamCount: number;
    }>(sql`
      select l.id, l.name, l.description,
             (select count(distinct gm.group_id)::int
                from student_laboratories sl
                join group_members gm on gm.user_id = sl.student_id
               where sl.laboratory_id = l.id) as "teamCount"
        from laboratories l
       where l.deleted_at is null
       order by l.name
    `);
    return c.json(paginated(rows, rows.length, query));
  }

  const scope = scopeFor(user);
  if (!scope) return c.json(paginated([], 0, query));

  const db = c.get('db');
  const [rows, [total]] = await Promise.all([
    db
      .select()
      .from(laboratories)
      .where(scope)
      .orderBy(asc(laboratories.name))
      .limit(query.pageSize)
      .offset((query.page - 1) * query.pageSize),
    db.select({ value: count() }).from(laboratories).where(scope),
  ]);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

labRoutes.get('/:id', async (c) => {
  const user = currentUser(c);
  const scope = scopeFor(user);
  if (!scope) throw notFound('No se encontró el laboratorio.');

  const db = c.get('db');
  const [lab] = await db
    .select()
    .from(laboratories)
    .where(and(eq(laboratories.id, c.req.param('id')), scope))
    .limit(1);
  if (!lab) throw notFound('No se encontró el laboratorio.');

  // Estructura de la Ruta: fases con sus objetivos y módulos. El AVANCE de un
  // estudiante puntual vive en `/students/:id/ruta-progress`, no acá — este
  // endpoint describe el laboratorio, no a quién lo está cursando.
  const phases = await db.execute<{
    id: string;
    orderIndex: number;
    title: string;
    description: string;
    deadline: string | null;
    objectives: unknown;
    modules: unknown;
  }>(sql`
    select p.id, p.order_index as "orderIndex", p.title, p.description,
           p.deadline::text as deadline,
           -- courseIds de cada objetivo: son los cursos que hay que
           -- completar para darlo por cumplido. Sin ellos el editor de Ruta
           -- mostraría el objetivo pero no qué lo satisface, y guardarlo lo
           -- dejaría sin cursos — es decir, imposible de completar.
           coalesce((select json_agg(json_build_object(
                        'id', o.id, 'category', o.category, 'text', o.text,
                        'courseIds', coalesce((select json_agg(oc.course_id)
                                                 from objective_courses oc
                                                where oc.objective_id = o.id), '[]'::json))
                      order by o.order_index)
                       from objectives o where o.phase_id = p.id), '[]'::json) as objectives,
           coalesce((select json_agg(json_build_object(
                        'id', rm.id, 'title', rm.title, 'orderIndex', rm.order_index,
                        'isMentorshipModule', rm.is_mentorship_module,
                        'courseIds', coalesce((select json_agg(rmc.course_id)
                                                 from ruta_module_courses rmc
                                                where rmc.ruta_module_id = rm.id), '[]'::json),
                        -- Las lecturas y entregas propias del módulo, las que
                        -- no vienen de un curso.
                        'ownLessons', coalesce((select json_agg(json_build_object(
                                                  'id', l.id, 'title', l.title,
                                                  'type', l.type,
                                                  'description', l.description,
                                                  'durationMin', l.duration_min,
                                                  'orderIndex', l.order_index,
                                                  'resourceS3Key', l.resource_s3_key,
                                                  'resourceFileName', l.resource_file_name,
                                                  'externalUrl', l.external_url)
                                                order by l.order_index)
                                                 from lessons l
                                                where l.ruta_module_id = rm.id), '[]'::json))
                      order by rm.order_index)
                       from ruta_modules rm where rm.phase_id = p.id), '[]'::json) as modules
      from phases p
     where p.laboratory_id = ${lab.id}
     order by p.order_index
  `);

  // Quiénes acompañan el laboratorio y quién lo patrocina. Sin esto la
  // pantalla de detalle tendría que listar TODOS los usuarios de la
  // plataforma y filtrar en el navegador — que es exactamente lo que hacía
  // con Hive, y por qué cualquier rol podía enumerar a todo el mundo.
  // Se incluyen correo y disponibilidad: son las personas que ACOMPAÑAN este
  // laboratorio, y coordinar una mentoría necesita cómo contactarlas. Es
  // información de contacto acotada a quienes ya trabajan con esta persona,
  // no un directorio de la plataforma.
  const staffColumns = sql`u.id, u.name, u.email,
           u.avatar_s3_key as "avatarS3Key",
           coalesce(u.profile ->> 'availability', '') as availability`;

  const mentors = await db.execute<LabStaff>(sql`
    select ${staffColumns}
      from laboratory_mentors lm
      join users u on u.id = lm.user_id and u.deleted_at is null
     where lm.laboratory_id = ${lab.id}
     order by u.name
  `);

  // El LXD de un laboratorio no es una asignación explícita: es quien creó
  // sus cursos. Misma definición que usa `scopeFor` para decidir qué
  // laboratorios ve un LXD — una sola regla, no dos que puedan discrepar.
  const lxds = await db.execute<LabStaff>(sql`
    select distinct ${staffColumns}
      from courses c
      join users u on u.id = c.creator_id and u.deleted_at is null
     where c.laboratory_id = ${lab.id} and c.deleted_at is null
     order by u.name
  `);

  let sponsorName: string | null = null;
  if (lab.sponsorCompanyId) {
    const [sponsor] = await db.execute<{ name: string }>(sql`
      select company_name as name from users
       where id = ${lab.sponsorCompanyId} and deleted_at is null
       limit 1
    `);
    sponsorName = sponsor?.name || null;
  }

  // Avance AGREGADO del grupo: cuántos de los estudiantes asignados
  // completaron cada fase. Es lo que ve un Admin, LXD, Mentor o Empresa —
  // ellos no tienen "su" avance en este laboratorio.
  //
  // Sale de la vista `phase_completion`, la misma que decide si se puede
  // emitir un certificado: una sola definición de "fase completa" para todo
  // el sistema.
  const [assigned] = await db.execute<{ value: number }>(sql`
    select count(*)::int as value from student_laboratories
     where laboratory_id = ${lab.id}
  `);

  // `phase_completion` ya está restringida a los estudiantes asignados al
  // laboratorio de la fase, así que alcanza con filtrar por `laboratory_id`:
  // volver a unir con `student_laboratories` no agregaría nada.
  const completions = await db.execute<{
    phaseId: string;
    value: number;
  }>(sql`
    select phase_id as "phaseId", count(*)::int as value
      from phase_completion
     where laboratory_id = ${lab.id} and is_complete
     group by phase_id
  `);
  const doneByPhase = new Map(completions.map((r) => [r.phaseId, r.value]));

  return c.json({
    ...lab,
    phases: phases.map((p) => ({
      ...p,
      completedByCount: doneByPhase.get(p.id) ?? 0,
    })),
    mentors,
    lxds,
    sponsorName,
    studentsAssigned: assigned?.value ?? 0,
  });
});
