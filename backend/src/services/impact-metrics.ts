import { sql } from 'drizzle-orm';

import type { Database } from '../db/client';

/**
 * Métricas de impacto formativo.
 *
 * Las tres las calculaba el cliente recorriendo TODA la base en memoria
 * (`hoursByCompetency`, `odsCompletionRate`, `sponsoredHoursByCompany` del
 * `DataProvider` con Hive). Contra una base remota eso sería descargar cada
 * curso, cada estudiante y cada progreso para sumar tres números.
 *
 * Acá son tres agregaciones en PostgreSQL sobre las vistas que ya existen —
 * `student_course_access` y `course_progress`— así que además usan la MISMA
 * definición de "sus cursos" y "cuánto lleva" que el resto de la API. Antes
 * podían discrepar del avance que veía el estudiante y nadie lo habría notado.
 */

export type ImpactMetrics = {
  counts: PlatformCounts;
  hoursByCompetency: { code: string; name: string; hours: number }[];
  odsCompletionRate: {
    code: string;
    number: number;
    title: string;
    rate: number;
    completed: number;
    total: number;
  }[];
  sponsoredHoursByCompany: {
    companyId: string;
    companyName: string;
    hours: number;
  }[];
};

export type PlatformCounts = {
  students: number;
  alumni: number;
  mentors: number;
  lxds: number;
  advisors: number;
  companies: number;
  donors: number;
  projects: number;
  groups: number;
  courses: number;
  laboratories: number;
  certificates: number;
  universities: number;
  submissionsPending: number;
};

/**
 * Los totales de la plataforma que muestra el panel Admin.
 *
 * Van en el servidor y no contando listas en el cliente por una razón
 * concreta: los listados vienen paginados de a 100, así que `courses.length`
 * dejaría de crecer al llegar a cien y el panel mostraría un número que parece
 * bien y está mal. Un `count(*)` no tiene ese techo.
 *
 * Todo excluye lo borrado lógicamente: un curso archivado sigue contando —
 * existe— pero uno borrado, no.
 */
async function platformCounts(db: Database): Promise<PlatformCounts> {
  const [row] = await db.execute<PlatformCounts>(sql`
    select
      (select count(*)::int from users
        where role = 'student' and deleted_at is null) as students,
      (select count(*)::int from users
        where role = 'alumni' and deleted_at is null) as alumni,
      (select count(*)::int from users
        where role = 'mentor' and deleted_at is null) as mentors,
      (select count(*)::int from users
        where role = 'lxd' and deleted_at is null) as lxds,
      (select count(*)::int from users
        where role = 'advisor' and deleted_at is null) as advisors,
      (select count(*)::int from users
        where role = 'company' and deleted_at is null) as companies,
      (select count(*)::int from users
        where role = 'donor' and deleted_at is null) as donors,
      (select count(*)::int from projects where deleted_at is null) as projects,
      (select count(*)::int from groups where deleted_at is null) as groups,
      (select count(*)::int from courses where deleted_at is null) as courses,
      (select count(*)::int from laboratories where deleted_at is null) as laboratories,
      (select count(*)::int from certificates) as certificates,
      -- Universidades distintas con alguien dentro: es la cifra de alcance
      -- que muestra el panel, no un catálogo.
      (select count(distinct university)::int from users
        where university <> '' and deleted_at is null) as universities,
      (select count(*)::int from submissions
        where graded_at is null and reviewed_at is null
          and deleted_at is null) as "submissionsPending"
  `);
  return row!;
}

/**
 * Horas de formación acumuladas por competencia.
 *
 * Se cuentan las horas de cada curso **ponderadas por el avance real** de cada
 * estudiante: un curso de 10 horas que alguien lleva al 40% aporta 4, no 10 ni
 * 0. Las horas del curso son las certificadas si las tiene, si no las
 * estimadas — la misma regla que el getter `Course.hours` del cliente.
 */
async function hoursByCompetency(db: Database) {
  return db.execute<{ code: string; name: string; hours: number }>(sql`
    select cc.competency_code as code,
           comp.name,
           round(sum(
             (case when c.certified_hours > 0
                   then c.certified_hours else c.estimated_hours end) * cp.ratio
           ), 1)::float8 as hours
      from course_progress cp
      join courses c on c.id = cp.course_id and c.deleted_at is null
      join course_competencies cc on cc.course_id = c.id
      join competencies comp on comp.code = cc.competency_code
     group by cc.competency_code, comp.name
    having sum(cp.ratio) > 0
     order by hours desc
  `);
}

/**
 * Cobertura de cada ODS: qué proporción de quienes tienen acceso a sus cursos
 * los completó.
 *
 * `total` cuenta pares (estudiante, curso) con acceso, no estudiantes: un ODS
 * cubierto por tres cursos exige los tres. Se devuelven también los crudos
 * —`completed` y `total`— porque una tasa del 100% sobre dos personas y otra
 * sobre doscientas no son la misma noticia, y la barra sola no lo distingue.
 */
async function odsCompletionRate(db: Database) {
  return db.execute<{
    code: string;
    number: number;
    title: string;
    rate: number;
    completed: number;
    total: number;
  }>(sql`
    select co.ods_code as code,
           g.number,
           g.title,
           count(*)::int as total,
           count(*) filter (where cp.is_complete)::int as completed,
           round(
             count(*) filter (where cp.is_complete)::numeric / count(*), 4
           )::float8 as rate
      from course_progress cp
      join courses c on c.id = cp.course_id and c.deleted_at is null
      join course_ods co on co.course_id = c.id
      join ods_goals g on g.code = co.ods_code
     group by co.ods_code, g.number, g.title
     order by rate desc, g.number
  `);
}

/**
 * Horas patrocinadas por empresa.
 *
 * Una empresa patrocina de dos formas y las dos cuentan: el curso directamente
 * (`courses.sponsor_company_id`) o el laboratorio al que pertenece
 * (`laboratories.sponsor_company_id`). `coalesce` se queda con la primera —el
 * patrocinio directo del curso manda sobre el del laboratorio— para que un
 * curso patrocinado por dos empresas no sume sus horas dos veces.
 */
async function sponsoredHoursByCompany(db: Database) {
  return db.execute<{
    companyId: string;
    companyName: string;
    hours: number;
  }>(sql`
    select patrocinador as "companyId",
           coalesce(nullif(u.company_name, ''), u.name) as "companyName",
           round(sum(horas), 1)::float8 as hours
      from (
        select coalesce(c.sponsor_company_id, l.sponsor_company_id) as patrocinador,
               (case when c.certified_hours > 0
                     then c.certified_hours else c.estimated_hours end) * cp.ratio as horas
          from course_progress cp
          join courses c on c.id = cp.course_id and c.deleted_at is null
          left join laboratories l
                 on l.id = c.laboratory_id and l.deleted_at is null
      ) t
      join users u on u.id = t.patrocinador and u.deleted_at is null
     where t.patrocinador is not null
     group by t.patrocinador, u.company_name, u.name
    having sum(horas) > 0
     order by hours desc
  `);
}

export async function impactMetrics(db: Database): Promise<ImpactMetrics> {
  const [counts, competencies, ods, sponsored] = await Promise.all([
    platformCounts(db),
    hoursByCompetency(db),
    odsCompletionRate(db),
    sponsoredHoursByCompany(db),
  ]);

  return {
    counts,
    hoursByCompetency: competencies,
    odsCompletionRate: ods,
    sponsoredHoursByCompany: sponsored,
  };
}
