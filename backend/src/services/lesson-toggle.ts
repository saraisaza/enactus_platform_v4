import { and, eq, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import {
  lessons,
  progress,
  progressLessons,
  rutaProgress,
  rutaProgressLessons,
} from '../db/schema';
import { forbidden, notFound } from '../lib/errors';

/**
 * Alternar una lección: el único punto donde un estudiante escribe progreso.
 *
 * Hoy `DataProvider.toggleLesson` alterna sin validar NADA — ni que el
 * estudiante tenga acceso al curso, ni que la lección exista, ni de quién es
 * el progreso (AUDITORIA_BACKEND.md § A.8.3). Acá se valida todo antes de
 * escribir, y la respuesta trae el progreso recalculado de curso, módulo,
 * fase y Ruta para que el cliente no tenga que volver a preguntar.
 */

export interface ToggleImpact {
  lessonId: string;
  completed: boolean;
  course: {
    courseId: string;
    totalLessons: number;
    completedLessons: number;
    ratio: number;
    isComplete: boolean;
  } | null;
  /** Un mismo curso puede estar en la Ruta de varios laboratorios. */
  rutaImpact: {
    laboratoryId: string;
    moduleId: string;
    moduleTitle: string;
    moduleComplete: boolean;
    phaseId: string;
    phaseOrder: number;
    phaseModulesDone: number;
    phaseModulesTotal: number;
    phaseComplete: boolean;
    rutaPhasesDone: number;
    rutaPhasesTotal: number;
    rutaComplete: boolean;
    /** La Ruta está completa y todavía no se emitió el certificado. */
    certificateAvailable: boolean;
  }[];
}

export async function toggleLesson(
  db: Database,
  studentId: string,
  lessonId: string,
): Promise<ToggleImpact> {
  const [lesson] = await db
    .select()
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!lesson) throw notFound('No se encontró la lección.');

  const completed = lesson.courseModuleId
    ? await toggleCourseLesson(db, studentId, lesson.courseModuleId, lesson.id)
    : await toggleOwnLesson(db, studentId, lesson.rutaModuleId!, lesson.id);

  return {
    lessonId: lesson.id,
    completed,
    course: lesson.courseModuleId
      ? await courseImpact(db, studentId, lesson.courseModuleId)
      : null,
    rutaImpact: await rutaImpact(db, studentId, lesson),
  };
}

/** Lección de curso: exige que el estudiante tenga acceso a ese curso. */
async function toggleCourseLesson(
  db: Database,
  studentId: string,
  courseModuleId: string,
  lessonId: string,
): Promise<boolean> {
  const [access] = await db.execute<{ course_id: string }>(sql`
    select a.course_id
      from student_course_access a
      join course_modules cm on cm.course_id = a.course_id
     where a.student_id = ${studentId} and cm.id = ${courseModuleId}
  `);
  if (!access) {
    throw forbidden('No tiene acceso a este curso.');
  }

  const [row] = await db
    .insert(progress)
    .values({ studentId, courseId: access.course_id })
    .onConflictDoUpdate({
      target: [progress.studentId, progress.courseId],
      set: { updatedAt: new Date() },
    })
    .returning({ id: progress.id });

  const progressId = row!.id;
  const existing = await db
    .select()
    .from(progressLessons)
    .where(
      and(
        eq(progressLessons.progressId, progressId),
        eq(progressLessons.lessonId, lessonId),
      ),
    )
    .limit(1);

  if (existing.length > 0) {
    await db
      .delete(progressLessons)
      .where(
        and(
          eq(progressLessons.progressId, progressId),
          eq(progressLessons.lessonId, lessonId),
        ),
      );
    return false;
  }

  await db.insert(progressLessons).values({ progressId, lessonId });
  return true;
}

/** Lectura/entrega propia de un módulo: exige estar en ese laboratorio. */
async function toggleOwnLesson(
  db: Database,
  studentId: string,
  rutaModuleId: string,
  lessonId: string,
): Promise<boolean> {
  const [lab] = await db.execute<{ laboratory_id: string }>(sql`
    select p.laboratory_id
      from ruta_modules rm
      join phases p on p.id = rm.phase_id
      join student_laboratories sl
        on sl.laboratory_id = p.laboratory_id and sl.student_id = ${studentId}
     where rm.id = ${rutaModuleId}
  `);
  if (!lab) {
    throw forbidden('No está asignado a este laboratorio.');
  }

  const [row] = await db
    .insert(rutaProgress)
    .values({ studentId, laboratoryId: lab.laboratory_id })
    .onConflictDoUpdate({
      target: [rutaProgress.studentId, rutaProgress.laboratoryId],
      set: { updatedAt: new Date() },
    })
    .returning({ id: rutaProgress.id });

  const rutaProgressId = row!.id;
  const existing = await db
    .select()
    .from(rutaProgressLessons)
    .where(
      and(
        eq(rutaProgressLessons.rutaProgressId, rutaProgressId),
        eq(rutaProgressLessons.lessonId, lessonId),
      ),
    )
    .limit(1);

  if (existing.length > 0) {
    await db
      .delete(rutaProgressLessons)
      .where(
        and(
          eq(rutaProgressLessons.rutaProgressId, rutaProgressId),
          eq(rutaProgressLessons.lessonId, lessonId),
        ),
      );
    return false;
  }

  await db.insert(rutaProgressLessons).values({ rutaProgressId, lessonId });
  return true;
}

async function courseImpact(
  db: Database,
  studentId: string,
  courseModuleId: string,
): Promise<ToggleImpact['course']> {
  const [row] = await db.execute<{
    course_id: string;
    total_lessons: number;
    completed_lessons: number;
    ratio: string;
    is_complete: boolean;
  }>(sql`
    select cp.course_id, cp.total_lessons::int, cp.completed_lessons::int,
           cp.ratio::text, cp.is_complete
      from course_progress cp
      join course_modules cm on cm.course_id = cp.course_id
     where cp.student_id = ${studentId} and cm.id = ${courseModuleId}
  `);
  if (!row) return null;
  return {
    courseId: row.course_id,
    totalLessons: row.total_lessons,
    completedLessons: row.completed_lessons,
    ratio: Number(row.ratio),
    isComplete: row.is_complete,
  };
}

/**
 * Recalcula hacia arriba: módulo → fase → Ruta.
 *
 * Para una lección de curso hay que mirar TODOS los módulos de Ruta donde ese
 * curso esté vinculado, en los laboratorios del estudiante — un mismo curso
 * puede estar en la Ruta de varios.
 */
async function rutaImpact(
  db: Database,
  studentId: string,
  lesson: typeof lessons.$inferSelect,
): Promise<ToggleImpact['rutaImpact']> {
  const rows = await db.execute<{
    laboratory_id: string;
    module_id: string;
    module_title: string;
    module_complete: boolean;
    phase_id: string;
    phase_order: number;
    phase_modules_done: number;
    phase_modules_total: number;
    phase_complete: boolean;
    ruta_phases_done: number;
    ruta_phases_total: number;
    ruta_complete: boolean;
    certificate_issued: boolean;
  }>(sql`
    with afectados as (
      ${
        lesson.courseModuleId
          ? sql`select rm.id as module_id
                  from course_modules cm
                  join ruta_module_courses rmc on rmc.course_id = cm.course_id
                  join ruta_modules rm on rm.id = rmc.ruta_module_id
                 where cm.id = ${lesson.courseModuleId}`
          : sql`select ${lesson.rutaModuleId}::uuid as module_id`
      }
    )
    select p.laboratory_id,
           rm.id as module_id, rm.title as module_title, rmc.is_complete as module_complete,
           p.id as phase_id, p.order_index as phase_order,
           pc.modules_done::int as phase_modules_done,
           pc.modules_total::int as phase_modules_total,
           pc.is_complete as phase_complete,
           rc.phases_done::int as ruta_phases_done,
           rc.phases_total::int as ruta_phases_total,
           rc.is_complete as ruta_complete,
           exists (select 1 from certificates ce
                    where ce.student_id = ${studentId}
                      and ce.laboratory_id = p.laboratory_id) as certificate_issued
      from afectados a
      join ruta_modules rm on rm.id = a.module_id
      join phases p on p.id = rm.phase_id
      join ruta_module_completion rmc
        on rmc.ruta_module_id = rm.id and rmc.student_id = ${studentId}
      join phase_completion pc
        on pc.phase_id = p.id and pc.student_id = ${studentId}
      join ruta_completion rc
        on rc.laboratory_id = p.laboratory_id and rc.student_id = ${studentId}
     order by p.order_index, rm.order_index
  `);

  return rows.map((r) => ({
    laboratoryId: r.laboratory_id,
    moduleId: r.module_id,
    moduleTitle: r.module_title,
    moduleComplete: r.module_complete,
    phaseId: r.phase_id,
    phaseOrder: r.phase_order,
    phaseModulesDone: r.phase_modules_done,
    phaseModulesTotal: r.phase_modules_total,
    phaseComplete: r.phase_complete,
    rutaPhasesDone: r.ruta_phases_done,
    rutaPhasesTotal: r.ruta_phases_total,
    rutaComplete: r.ruta_complete,
    certificateAvailable: r.ruta_complete && !r.certificate_issued,
  }));
}
