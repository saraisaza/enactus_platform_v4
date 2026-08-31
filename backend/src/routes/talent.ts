import { sql } from 'drizzle-orm';
import { Hono } from 'hono';

import { forbidden } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import { currentUser, requireAuth } from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * BuscaTalento: el directorio de talento Enactus para Donantes y Empresas.
 *
 * Es el ÚNICO listado de personas cuyo alcance es deliberadamente más ancho
 * que el de `/users`. Ahí un donante ve solo a quienes apoya y una empresa a
 * su gente; acá los dos ven a **todos los estudiantes Enactus**, porque de eso
 * se trata la pantalla: descubrir a alguien que todavía no conocen.
 *
 * Por eso vive en su propia ruta y no como un filtro de `/users`. Un filtro
 * que ensancha el alcance es exactamente la clase de cosa que después nadie
 * recuerda que existe; una ruta aparte, con su propia lista de roles y su
 * propia forma de respuesta, se lee y se audita sola.
 *
 * Lo que se expone es **el perfil profesional, no los datos de contacto**:
 * nombre, universidad, carrera, ciudad, avance y logros. Ni correo, ni
 * teléfono, ni cédula. Para hablarles está `POST /notifications`, que deja
 * rastro y no entrega el correo de nadie.
 *
 * Los de Open Learning no aparecen: no tienen Ruta de Impacto, así que no
 * tienen objetivos cumplidos que mostrar.
 */
export const talentRoutes = new Hono<AppEnv>();
talentRoutes.use('*', requireAuth);

/** Quién puede mirar el directorio. */
const VIEWERS = ['donor', 'company', 'admin', 'superadmin'];

export function canSeeTalent(user: AuthUser): boolean {
  return VIEWERS.includes(user.role);
}

talentRoutes.get('/', async (c) => {
  const user = currentUser(c);
  if (!canSeeTalent(user)) {
    throw forbidden('BuscaTalento es para Donantes y Empresas.');
  }

  const query = paginationSchema.parse(c.req.query());
  const db = c.get('db');

  // Todo en UNA consulta. La versión con Hive armaba cada tarjeta con seis
  // búsquedas —equipo, proyecto, laboratorios, objetivos, avance,
  // certificados— sobre listas en memoria; contra la red eso serían seis
  // peticiones por estudiante.
  const rows = await db.execute<{
    id: string;
    name: string;
    university: string;
    career: string;
    city: string;
    avatarS3Key: string | null;
    groupId: string | null;
    groupName: string | null;
    projectId: string | null;
    projectName: string | null;
    laboratories: { id: string; name: string }[];
    objectivesEntrepreneurship: number;
    objectivesBusiness: number;
    certificates: number;
    ratio: string;
    coursesTotal: number;
    coursesDone: number;
  }>(sql`
    select u.id, u.name, u.university, u.career, u.city,
           u.avatar_s3_key as "avatarS3Key",
           g.id   as "groupId",   g.name as "groupName",
           pr.id  as "projectId", pr.name as "projectName",
           coalesce((
             select json_agg(json_build_object('id', l.id, 'name', l.name)
                             order by l.name)
               from student_laboratories sl
               join laboratories l
                 on l.id = sl.laboratory_id and l.deleted_at is null
              where sl.student_id = u.id), '[]'::json) as laboratories,
           -- objective_completion no trae la categoría: la tiene el objetivo.
           -- (Sin comillas invertidas: adentro de una plantilla, la cierran.)
           coalesce((
             select count(*) from objective_completion oc
               join objectives o on o.id = oc.objective_id
              where oc.student_id = u.id and oc.is_complete
                and o.category = 'entrepreneurship'), 0)::int
             as "objectivesEntrepreneurship",
           coalesce((
             select count(*) from objective_completion oc
               join objectives o on o.id = oc.objective_id
              where oc.student_id = u.id and oc.is_complete
                and o.category = 'business'), 0)::int
             as "objectivesBusiness",
           coalesce((
             select count(*) from certificates ce
              where ce.student_id = u.id), 0)::int as certificates,
           coalesce((select avg(ratio) from course_progress cp
                      where cp.student_id = u.id), 0)::text as ratio,
           coalesce((select count(*) from course_progress cp
                      where cp.student_id = u.id), 0)::int as "coursesTotal",
           coalesce((select count(*) from course_progress cp
                      where cp.student_id = u.id and cp.is_complete), 0)::int
             as "coursesDone"
      from users u
      left join group_members gm on gm.user_id = u.id
      left join groups g on g.id = gm.group_id and g.deleted_at is null
      left join projects pr on pr.id = g.project_id and pr.deleted_at is null
     where u.deleted_at is null
       and u.student_type = 'enactus'
       and u.role in ('student', 'alumni')
     -- Primero quienes ya cumplieron objetivos EMPRESARIALES: es el orden que
     -- pide la pantalla, y la razón por la que una empresa entra acá.
     order by "objectivesBusiness" desc, "objectivesEntrepreneurship" desc, u.name
     limit ${query.pageSize} offset ${(query.page - 1) * query.pageSize}
  `);

  const [total] = await db.execute<{ value: number }>(sql`
    select count(*)::int as value from users
     where deleted_at is null and student_type = 'enactus'
       and role in ('student', 'alumni')
  `);

  const data = rows.map((r) => ({
    id: r.id,
    name: r.name,
    university: r.university,
    career: r.career,
    city: r.city,
    avatarS3Key: r.avatarS3Key,
    team:
      r.groupId === null
        ? null
        : {
            groupId: r.groupId,
            groupName: r.groupName,
            projectId: r.projectId,
            projectName: r.projectName,
          },
    laboratories: r.laboratories,
    completedObjectives: {
      entrepreneurship: r.objectivesEntrepreneurship,
      business: r.objectivesBusiness,
    },
    certificates: r.certificates,
    overallProgress: {
      ratio: Number(r.ratio),
      coursesTotal: r.coursesTotal,
      coursesDone: r.coursesDone,
    },
  }));

  return c.json(paginated(data, total?.value ?? 0, query));
});
