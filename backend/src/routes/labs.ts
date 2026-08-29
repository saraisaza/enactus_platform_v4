import { and, asc, count, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';

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

const listQuery = paginationSchema;

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
    order_index: number;
    title: string;
    description: string;
    deadline: string | null;
    objectives: unknown;
    modules: unknown;
  }>(sql`
    select p.id, p.order_index, p.title, p.description, p.deadline::text,
           coalesce((select json_agg(json_build_object(
                        'id', o.id, 'category', o.category, 'text', o.text)
                      order by o.order_index)
                       from objectives o where o.phase_id = p.id), '[]'::json) as objectives,
           coalesce((select json_agg(json_build_object(
                        'id', rm.id, 'title', rm.title, 'orderIndex', rm.order_index,
                        'isMentorshipModule', rm.is_mentorship_module,
                        'courseIds', coalesce((select json_agg(rmc.course_id)
                                                 from ruta_module_courses rmc
                                                where rmc.ruta_module_id = rm.id), '[]'::json))
                      order by rm.order_index)
                       from ruta_modules rm where rm.phase_id = p.id), '[]'::json) as modules
      from phases p
     where p.laboratory_id = ${lab.id}
     order by p.order_index
  `);

  return c.json({ ...lab, phases });
});
