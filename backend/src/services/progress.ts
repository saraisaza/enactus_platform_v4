import { sql } from 'drizzle-orm';

import type { Database } from '../db/client';

/**
 * Lectura de la completitud. Todo sale de las vistas de `0001_completeness.sql`
 * — acá no se recalcula ninguna regla, solo se arma la forma que el cliente
 * necesita.
 *
 * Es el punto del proyecto donde la lógica deja de vivir en el navegador: hoy
 * `data_provider.dart` recalcula `isModuleComplete`/`isPhaseComplete`/
 * `isRutaComplete` en cada `build()` a partir de datos que el navegador ya
 * tiene, y por eso son falsificables.
 */

export interface CourseProgress {
  courseId: string;
  courseName: string;
  totalLessons: number;
  completedLessons: number;
  ratio: number;
  isComplete: boolean;
}

export interface ModuleProgress {
  moduleId: string;
  title: string;
  orderIndex: number;
  isMentorshipModule: boolean;
  ownLessonsTotal: number;
  ownLessonsDone: number;
  coursesTotal: number;
  coursesDone: number;
  isComplete: boolean;
  isUnlocked: boolean;
  courses: CourseProgress[];
}

export interface ObjectiveProgress {
  objectiveId: string;
  category: string;
  text: string;
  isComplete: boolean;
}

export interface PhaseProgress {
  phaseId: string;
  orderIndex: number;
  title: string;
  deadline: string | null;
  deadlineStatus: 'none' | 'on_track' | 'approaching' | 'overdue';
  modulesTotal: number;
  modulesDone: number;
  isComplete: boolean;
  isUnlocked: boolean;
  objectives: ObjectiveProgress[];
  modules: ModuleProgress[];
}

export interface LabProgress {
  laboratoryId: string;
  laboratoryName: string;
  phasesTotal: number;
  phasesDone: number;
  isComplete: boolean;
  certificateIssued: boolean;
  phases: PhaseProgress[];
}

/** Ventana de aviso de deadline: 3 días, igual que `deadlineWarningWindow`. */
const DEADLINE_WARNING_DAYS = 3;

/**
 * Estado del deadline de una fase para un estudiante puntual.
 * Una fase ya completada NUNCA aparece atrasada, sin importar la fecha —
 * misma regla que `DataProvider.phaseDeadlineStatus`.
 */
function deadlineStatus(
  deadline: string | null,
  isComplete: boolean,
): PhaseProgress['deadlineStatus'] {
  if (!deadline || isComplete) return 'none';
  const due = new Date(`${deadline}T23:59:59Z`).getTime();
  const now = Date.now();
  if (now > due) return 'overdue';
  if (due - now <= DEADLINE_WARNING_DAYS * 86_400_000) return 'approaching';
  return 'on_track';
}

/** Ruta de Impacto completa de un estudiante, en todos sus laboratorios. */
export async function rutaProgressFor(
  db: Database,
  studentId: string,
): Promise<LabProgress[]> {
  const labs = await db.execute<{
    laboratory_id: string;
    laboratory_name: string;
    phases_total: number;
    phases_done: number;
    is_complete: boolean;
    certificate_issued: boolean;
  }>(sql`
    select rc.laboratory_id,
           l.name as laboratory_name,
           rc.phases_total::int,
           rc.phases_done::int,
           rc.is_complete,
           exists (select 1 from certificates ce
                    where ce.student_id = ${studentId}
                      and ce.laboratory_id = rc.laboratory_id) as certificate_issued
      from ruta_completion rc
      join laboratories l on l.id = rc.laboratory_id
     where rc.student_id = ${studentId}
     order by l.name
  `);

  if (labs.length === 0) return [];

  const phases = await db.execute<{
    phase_id: string;
    laboratory_id: string;
    order_index: number;
    title: string;
    deadline: string | null;
    modules_total: number;
    modules_done: number;
    is_complete: boolean;
    is_unlocked: boolean;
  }>(sql`
    select pc.phase_id, pc.laboratory_id, pc.order_index, p.title,
           p.deadline::text,
           pc.modules_total::int, pc.modules_done::int,
           pc.is_complete, pu.is_unlocked
      from phase_completion pc
      join phases p on p.id = pc.phase_id
      join phase_unlocked pu
        on pu.phase_id = pc.phase_id and pu.student_id = pc.student_id
     where pc.student_id = ${studentId}
     order by pc.laboratory_id, pc.order_index
  `);

  const objectives = await db.execute<{
    objective_id: string;
    phase_id: string;
    category: string;
    text: string;
    is_complete: boolean;
  }>(sql`
    select oc.objective_id, o.phase_id, o.category, o.text, oc.is_complete
      from objective_completion oc
      join objectives o on o.id = oc.objective_id
     where oc.student_id = ${studentId}
     order by o.order_index
  `);

  const modules = await db.execute<{
    module_id: string;
    phase_id: string;
    title: string;
    order_index: number;
    is_mentorship_module: boolean;
    own_lessons_total: number;
    own_lessons_done: number;
    courses_total: number;
    courses_done: number;
    is_complete: boolean;
  }>(sql`
    select rmc.ruta_module_id as module_id, rm.phase_id, rm.title,
           rm.order_index, rm.is_mentorship_module,
           rmc.own_lessons_total::int, rmc.own_lessons_done::int,
           rmc.courses_total::int, rmc.courses_done::int, rmc.is_complete
      from ruta_module_completion rmc
      join ruta_modules rm on rm.id = rmc.ruta_module_id
     where rmc.student_id = ${studentId}
     order by rm.phase_id, rm.order_index
  `);

  const moduleCourses = await db.execute<{
    module_id: string;
    course_id: string;
    course_name: string;
    total_lessons: number;
    completed_lessons: number;
    ratio: string;
    is_complete: boolean;
  }>(sql`
    select rmc.ruta_module_id as module_id, c.id as course_id, c.name as course_name,
           coalesce(cp.total_lessons, 0)::int as total_lessons,
           coalesce(cp.completed_lessons, 0)::int as completed_lessons,
           coalesce(cp.ratio, 0)::text as ratio,
           coalesce(cp.is_complete, false) as is_complete
      from ruta_module_courses rmc
      join courses c on c.id = rmc.course_id
      left join course_progress cp
             on cp.course_id = c.id and cp.student_id = ${studentId}
     where c.deleted_at is null
     order by c.name
  `);

  const objectivesByPhase = groupBy(objectives, (o) => o.phase_id);
  const modulesByPhase = groupBy(modules, (m) => m.phase_id);
  const coursesByModule = groupBy(moduleCourses, (c) => c.module_id);
  const phasesByLab = groupBy(phases, (p) => p.laboratory_id);

  return labs.map((lab) => ({
    laboratoryId: lab.laboratory_id,
    laboratoryName: lab.laboratory_name,
    phasesTotal: lab.phases_total,
    phasesDone: lab.phases_done,
    isComplete: lab.is_complete,
    certificateIssued: lab.certificate_issued,
    phases: (phasesByLab.get(lab.laboratory_id) ?? []).map((p) => {
      const mods = modulesByPhase.get(p.phase_id) ?? [];
      return {
        phaseId: p.phase_id,
        orderIndex: p.order_index,
        title: p.title,
        deadline: p.deadline,
        deadlineStatus: deadlineStatus(p.deadline, p.is_complete),
        modulesTotal: p.modules_total,
        modulesDone: p.modules_done,
        isComplete: p.is_complete,
        isUnlocked: p.is_unlocked,
        objectives: (objectivesByPhase.get(p.phase_id) ?? []).map((o) => ({
          objectiveId: o.objective_id,
          category: o.category,
          text: o.text,
          isComplete: o.is_complete,
        })),
        modules: mods.map((m, index) => ({
          moduleId: m.module_id,
          title: m.title,
          orderIndex: m.order_index,
          isMentorshipModule: m.is_mentorship_module,
          ownLessonsTotal: m.own_lessons_total,
          ownLessonsDone: m.own_lessons_done,
          coursesTotal: m.courses_total,
          coursesDone: m.courses_done,
          isComplete: m.is_complete,
          // El primer módulo de una fase desbloqueada siempre está abierto;
          // los siguientes exigen el anterior completo (`isModuleUnlocked`).
          isUnlocked: p.is_unlocked && (index === 0 || (mods[index - 1]?.is_complete ?? false)),
          courses: (coursesByModule.get(m.module_id) ?? []).map((c) => ({
            courseId: c.course_id,
            courseName: c.course_name,
            totalLessons: c.total_lessons,
            completedLessons: c.completed_lessons,
            ratio: Number(c.ratio),
            isComplete: c.is_complete,
          })),
        })),
      };
    }),
  }));
}

/** Progreso de un estudiante en UN curso. */
export async function courseProgressFor(
  db: Database,
  studentId: string,
  courseId: string,
): Promise<CourseProgress | null> {
  const [row] = await db.execute<{
    course_id: string;
    course_name: string;
    total_lessons: number;
    completed_lessons: number;
    ratio: string;
    is_complete: boolean;
  }>(sql`
    select cp.course_id, c.name as course_name,
           cp.total_lessons::int, cp.completed_lessons::int,
           cp.ratio::text, cp.is_complete
      from course_progress cp
      join courses c on c.id = cp.course_id
     where cp.student_id = ${studentId} and cp.course_id = ${courseId}
  `);
  if (!row) return null;
  return {
    courseId: row.course_id,
    courseName: row.course_name,
    totalLessons: row.total_lessons,
    completedLessons: row.completed_lessons,
    ratio: Number(row.ratio),
    isComplete: row.is_complete,
  };
}

/**
 * Lecciones completadas de un curso, para que el cliente sepa cuál marcar.
 * Reemplaza `Progress.completedLessonIds`.
 */
export async function completedLessonIds(
  db: Database,
  studentId: string,
  courseId: string,
): Promise<string[]> {
  const rows = await db.execute<{ lesson_id: string }>(sql`
    select pl.lesson_id from progress_lessons pl
      join progress p on p.id = pl.progress_id
     where p.student_id = ${studentId} and p.course_id = ${courseId}
  `);
  return rows.map((r) => r.lesson_id);
}

function groupBy<T, K>(items: T[], key: (item: T) => K): Map<K, T[]> {
  const map = new Map<K, T[]>();
  for (const item of items) {
    const k = key(item);
    const list = map.get(k);
    if (list) list.push(item);
    else map.set(k, [item]);
  }
  return map;
}
