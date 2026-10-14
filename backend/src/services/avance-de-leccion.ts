import { eq, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { lessons, rutaProgress, rutaProgressLessons } from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import { marcarLeccionCompleta } from './leccion-completa';

/**
 * Completar una lección: el único camino por el que un estudiante suma avance.
 *
 * Antes existía `POST /progress/lessons/:id/toggle`, que alternaba la lección
 * sin pedir nada más que acceso al curso. En la prueba beta de Open Learning
 * una estudiante marcaba lecciones tocando el círculo, sin ver el video ni
 * leer el material, y pasaba a las siguientes. Desde la migración 0020 hay
 * dos reglas, y las hace cumplir el servidor:
 *
 * 1. **En orden.** Una lección se abre cuando todas las anteriores del curso
 *    —las de los módulos anteriores incluidas— están completas. En la Ruta,
 *    además, el módulo tiene que estar desbloqueado. Lo ya completado se
 *    puede repasar siempre.
 * 2. **Con su prueba.** Cada tipo se completa con lo suyo, nunca a mano:
 *    - video (YouTube o subido): haberlo VISTO, el 90% en tramos
 *      reproducidos. Adelantar no suma (`services/video-progress.ts`);
 *    - quiz: aprobarlo. La nota la pone el servidor;
 *    - encuesta: responderla;
 *    - actividad de un curso: que su entrega quede calificada como aprobada;
 *      entrega de la Ruta: entregarla (el Mentor revisa, pero no califica);
 *    - PDF, recurso, enlace o video de Vimeo: recorrerlo. Eso lo comprueba la
 *      app —llegar a la última página del PDF, abrir el enlace—, porque el
 *      servidor no ve el material; acá se exige el orden.
 *
 * Completar nunca se deshace: no hay «desmarcar».
 */

export interface LessonImpact {
  lessonId: string;
  completed: boolean;
  course: {
    courseId: string;
    totalLessons: number;
    completedLessons: number;
    ratio: number;
    isComplete: boolean;
    /** La que se abre ahora (ver [siguienteLeccionDelCurso]). */
    nextLessonId: string | null;
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

export type Leccion = typeof lessons.$inferSelect;

/** Dónde vive la lección para ESTE estudiante: su curso o su laboratorio. */
export type Lugar =
  | { kind: 'curso'; courseId: string }
  | { kind: 'ruta'; laboratoryId: string; rutaModuleId: string };

/** La fracción del video que hay que ver para completarlo. */
export const UMBRAL_VIDEO_VISTO = 0.9;

/**
 * `POST /progress/lessons/:id/complete`: completa la lección si ya se puede.
 *
 * Si ya estaba completa no hace nada (y responde igual): volver a abrir una
 * lectura o terminar otra vez un video no es un error. Si no se puede, 409 con
 * el motivo en palabras de la persona: qué le falta, no un código.
 */
export async function completarLeccion(
  db: Database,
  studentId: string,
  lessonId: string,
): Promise<LessonImpact> {
  const lesson = await cargarLeccion(db, lessonId);
  const lugar = await lugarDeLeccion(db, studentId, lesson);

  if (!(await estaCompleta(db, studentId, lesson, lugar))) {
    await exigirDisponible(db, studentId, lesson, lugar);
    await exigirSuPrueba(db, studentId, lesson, lugar);
    await registrarCompleta(db, studentId, lesson, lugar);
  }
  return impactoDeLeccion(db, studentId, lesson);
}

/** La lección, o 404. */
export async function cargarLeccion(db: Database, lessonId: string): Promise<Leccion> {
  const [lesson] = await db
    .select()
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!lesson) throw notFound('No se encontró la lección.');
  return lesson;
}

/** Su curso o su laboratorio, si el estudiante tiene acceso; si no, 403. */
export async function lugarDeLeccion(
  db: Database,
  studentId: string,
  lesson: Leccion,
): Promise<Lugar> {
  if (lesson.courseModuleId) {
    return {
      kind: 'curso',
      courseId: await courseAccessForModule(db, studentId, lesson.courseModuleId),
    };
  }
  return {
    kind: 'ruta',
    laboratoryId: await labAccessForRutaModule(db, studentId, lesson.rutaModuleId!),
    rutaModuleId: lesson.rutaModuleId!,
  };
}

/**
 * El curso de ese módulo, si el estudiante tiene acceso a él; si no, 403.
 *
 * Es la regla de «puede escribir avance en esta lección de curso». La usan
 * completar, la posición del video (`services/video-progress.ts`) y las
 * entregas: una sola definición, para que no puedan discrepar en quién puede.
 */
export async function courseAccessForModule(
  db: Database,
  studentId: string,
  courseModuleId: string,
): Promise<string> {
  const [access] = await db.execute<{ course_id: string }>(sql`
    select a.course_id
      from student_course_access a
      join course_modules cm on cm.course_id = a.course_id
     where a.student_id = ${studentId} and cm.id = ${courseModuleId}
  `);
  if (!access) {
    throw forbidden('No tiene acceso a este curso.');
  }
  return access.course_id;
}

/** El laboratorio de ese módulo de la Ruta, si el estudiante está en él; si no, 403. */
export async function labAccessForRutaModule(
  db: Database,
  studentId: string,
  rutaModuleId: string,
): Promise<string> {
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
  return lab.laboratory_id;
}

export async function estaCompleta(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<boolean> {
  const [fila] =
    lugar.kind === 'curso'
      ? await db.execute<{ ok: number }>(sql`
          select 1 as ok from progress_lessons pl
            join progress p on p.id = pl.progress_id
           where p.student_id = ${studentId} and p.course_id = ${lugar.courseId}
             and pl.lesson_id = ${lesson.id}
        `)
      : await db.execute<{ ok: number }>(sql`
          select 1 as ok from ruta_progress_lessons rpl
            join ruta_progress rp on rp.id = rpl.ruta_progress_id
           where rp.student_id = ${studentId}
             and rp.laboratory_id = ${lugar.laboratoryId}
             and rpl.lesson_id = ${lesson.id}
        `);
  return fila !== undefined;
}

/**
 * 409 si todavía no le toca esta lección: falta una anterior, o en la Ruta,
 * el módulo sigue bloqueado. Lo ya completado no pasa por acá (se repasa).
 *
 * Lo usan completar y todo lo que deja una prueba —responder un quiz o una
 * encuesta, entregar, guardar el avance de un video—: sin esto, se podría
 * aprobar el quiz del módulo 3 sin haber visto el 1.
 */
export async function exigirDisponible(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<void> {
  if (lugar.kind === 'ruta') {
    await exigirModuloAbierto(db, studentId, lugar.rutaModuleId);
  }
  const anterior = await leccionAnteriorPendiente(db, studentId, lesson, lugar);
  if (anterior) {
    throw conflict(`Primero complete «${anterior.title}».`, {
      pendiente: { id: anterior.id, title: anterior.title },
    });
  }
}

/** Igual que [exigirDisponible], pero salta si ya estaba completa. */
export async function exigirDisponibleSiPendiente(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<void> {
  if (await estaCompleta(db, studentId, lesson, lugar)) return;
  await exigirDisponible(db, studentId, lesson, lugar);
}

/**
 * El orden de las lecciones de un curso: módulo por módulo, y dentro de cada
 * módulo por `order_index`. El `id` desempata para que el orden sea siempre
 * el mismo, también en el listado que ve el estudiante (`routes/courses.ts`).
 */
const ORDEN_DEL_CURSO = sql`cm.order_index, l.order_index, l.id`;

/** La primera lección anterior a [lesson] que el estudiante no completó. */
async function leccionAnteriorPendiente(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<{ id: string; title: string } | null> {
  if (lugar.kind === 'curso') {
    const [fila] = await db.execute<{ id: string; title: string }>(sql`
      with orden as (
        select l.id, l.title, row_number() over (order by ${ORDEN_DEL_CURSO}) as pos
          from lessons l
          join course_modules cm on cm.id = l.course_module_id
         where cm.course_id = ${lugar.courseId}
      )
      select o.id, o.title
        from orden o
       where o.pos < (select pos from orden where id = ${lesson.id})
         and not exists (
           select 1 from progress_lessons pl
             join progress p on p.id = pl.progress_id
            where p.student_id = ${studentId} and p.course_id = ${lugar.courseId}
              and pl.lesson_id = o.id)
       order by o.pos
       limit 1
    `);
    return fila ?? null;
  }

  const [fila] = await db.execute<{ id: string; title: string }>(sql`
    with orden as (
      select l.id, l.title, row_number() over (order by l.order_index, l.id) as pos
        from lessons l
       where l.ruta_module_id = ${lugar.rutaModuleId}
    )
    select o.id, o.title
      from orden o
     where o.pos < (select pos from orden where id = ${lesson.id})
       and not exists (
         select 1 from ruta_progress_lessons rpl
           join ruta_progress rp on rp.id = rpl.ruta_progress_id
          where rp.student_id = ${studentId}
            and rp.laboratory_id = ${lugar.laboratoryId}
            and rpl.lesson_id = o.id)
     order by o.pos
     limit 1
  `);
  return fila ?? null;
}

/**
 * La siguiente lección que le toca en un curso: la primera sin completar, en
 * el orden del curso. `null` si ya completó todas (o el curso está vacío).
 *
 * Es lo que la pantalla del curso necesita para dibujar los candados: una
 * lección está abierta si ya la completó o si es esta.
 */
export async function siguienteLeccionDelCurso(
  db: Database,
  studentId: string,
  courseId: string,
): Promise<string | null> {
  const [fila] = await db.execute<{ id: string }>(sql`
    select l.id
      from lessons l
      join course_modules cm on cm.id = l.course_module_id
     where cm.course_id = ${courseId}
       and not exists (
         select 1 from progress_lessons pl
           join progress p on p.id = pl.progress_id
          where p.student_id = ${studentId} and p.course_id = ${courseId}
            and pl.lesson_id = l.id)
     order by ${ORDEN_DEL_CURSO}
     limit 1
  `);
  return fila?.id ?? null;
}

/**
 * En la Ruta, el módulo se abre con la fase desbloqueada y el módulo anterior
 * de la fase completo: la misma regla que `isUnlocked` en
 * `services/progress.ts`, que es la que ya dibujaba la pantalla.
 */
async function exigirModuloAbierto(
  db: Database,
  studentId: string,
  rutaModuleId: string,
): Promise<void> {
  const [fila] = await db.execute<{
    fase_abierta: boolean | null;
    anterior_titulo: string | null;
    anterior_completo: boolean | null;
  }>(sql`
    select pu.is_unlocked as fase_abierta,
           prev.title as anterior_titulo,
           prev_c.is_complete as anterior_completo
      from ruta_modules rm
      left join phase_unlocked pu
             on pu.phase_id = rm.phase_id and pu.student_id = ${studentId}
      left join lateral (
             select p.id, p.title from ruta_modules p
              where p.phase_id = rm.phase_id and p.order_index < rm.order_index
              order by p.order_index desc
              limit 1) prev on true
      left join ruta_module_completion prev_c
             on prev_c.ruta_module_id = prev.id and prev_c.student_id = ${studentId}
     where rm.id = ${rutaModuleId}
  `);
  if (!fila?.fase_abierta) {
    throw conflict(
      'Esta fase de la Ruta todavía está bloqueada: complete primero la fase anterior.',
    );
  }
  if (fila.anterior_titulo !== null && !fila.anterior_completo) {
    throw conflict(`Primero complete el módulo «${fila.anterior_titulo}».`);
  }
}

/**
 * 409 si todavía no hizo lo que esta lección pide, con el motivo en palabras
 * de la persona. `details.requisito` es el tipo de lección.
 */
async function exigirSuPrueba(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<void> {
  const detalle = { requisito: lesson.type };
  switch (lesson.type) {
    case 'video':
      if (videoConAvance(lesson) && !(await videoVisto(db, studentId, lesson))) {
        throw conflict(
          'Vea el video completo para completar esta lección: adelantarlo no cuenta.',
          detalle,
        );
      }
      return;
    case 'quiz': {
      const [aprobado] = await db.execute<{ ok: number }>(sql`
        select 1 as ok from quiz_attempts
         where lesson_id = ${lesson.id} and student_id = ${studentId} and passed
         limit 1
      `);
      if (!aprobado) throw conflict('Apruebe el quiz para completar esta lección.', detalle);
      return;
    }
    case 'survey': {
      const [respondida] = await db.execute<{ ok: number }>(sql`
        select 1 as ok from survey_responses
         where lesson_id = ${lesson.id} and student_id = ${studentId}
      `);
      if (!respondida) {
        throw conflict('Responda la encuesta para completar esta lección.', detalle);
      }
      return;
    }
    case 'activity':
      if (lugar.kind === 'ruta') {
        if (!(await tieneEntrega(db, studentId, lesson.id))) {
          throw conflict('Haga su entrega para completar esta lección.', detalle);
        }
        return;
      }
      if (!(await entregaAprobada(db, studentId, lesson.id))) {
        throw conflict(
          'Esta actividad se completa cuando su entrega sea calificada como aprobada.',
          detalle,
        );
      }
      return;
    default:
      // pdf, resource, link: el recorrido lo comprueba la app.
      return;
  }
}

/**
 * Si la app sigue lo que se ve de este video. YouTube y los subidos, sí. Un
 * enlace `external` (Vimeo, o un YouTube viejo guardado como enlace) se
 * completa al abrirlo: exigirle tramos dejaría la lección imposible de
 * completar si el reproductor no los informa.
 */
export function videoConAvance(lesson: Pick<Leccion, 'videoType'>): boolean {
  return lesson.videoType === 'youtube' || lesson.videoType === 'uploaded';
}

/**
 * La duración contra la que se mide lo visto: la que guardó el LXD al
 * configurar el video, si la hay; si no, la que informó el reproductor.
 */
export function duracionDeReferencia(
  lesson: Pick<Leccion, 'videoDurationSec'>,
  reportada: number | null,
): number | null {
  const propia = lesson.videoDurationSec;
  if (propia !== null && propia > 0) return propia;
  return reportada !== null && reportada > 0 ? reportada : null;
}

/** ¿Vio el [UMBRAL_VIDEO_VISTO] del video? */
export function alcanzaLoVisto(watchedSec: number, duracion: number | null): boolean {
  return duracion !== null && watchedSec >= duracion * UMBRAL_VIDEO_VISTO;
}

async function videoVisto(db: Database, studentId: string, lesson: Leccion): Promise<boolean> {
  const [fila] = await db.execute<{ watched_sec: number; duration_sec: number | null }>(sql`
    select watched_sec, duration_sec from lesson_video_progress
     where student_id = ${studentId} and lesson_id = ${lesson.id}
  `);
  if (!fila) return false;
  return alcanzaLoVisto(fila.watched_sec, duracionDeReferencia(lesson, fila.duration_sec));
}

async function tieneEntrega(db: Database, studentId: string, lessonId: string): Promise<boolean> {
  const [fila] = await db.execute<{ ok: number }>(sql`
    select 1 as ok from submissions
     where student_id = ${studentId} and lesson_id = ${lessonId} and deleted_at is null
     limit 1
  `);
  return fila !== undefined;
}

async function entregaAprobada(
  db: Database,
  studentId: string,
  lessonId: string,
): Promise<boolean> {
  const filas = await db.execute<{ grade: string | null; grading_mode: string | null }>(sql`
    select grade::text, grading_mode::text from submissions
     where student_id = ${studentId} and lesson_id = ${lessonId} and deleted_at is null
  `);
  return filas.some((f) =>
    notaAprobatoria(f.grading_mode, f.grade === null ? null : Number(f.grade)),
  );
}

/**
 * Si una calificación aprueba, en su escala. Las mismas reglas que
 * `GradingMode.isPassing` en la app: 60/100, 3/5, «aprobado» en
 * aprobado/reprobado. En «solo revisión» no hay nota: revisarla la aprueba.
 */
export function notaAprobatoria(mode: string | null, grade: number | null): boolean {
  if (mode === 'review') return true;
  if (grade === null) return false;
  switch (mode) {
    case 'passfail':
      return grade > 0;
    case 'scale5':
      return grade >= 3;
    default:
      return grade >= 60;
  }
}

/**
 * Escribe el hecho «completó esta lección». No valida nada: quien la llama ya
 * comprobó el orden y la prueba. Si con esto terminó un curso, se emite su
 * certificado (`marcarLeccionCompleta`).
 */
export async function registrarCompleta(
  db: Database,
  studentId: string,
  lesson: Leccion,
  lugar: Lugar,
): Promise<void> {
  if (lugar.kind === 'curso') {
    await marcarLeccionCompleta(db, studentId, lugar.courseId, lesson.id);
    return;
  }
  const [fila] = await db
    .insert(rutaProgress)
    .values({ studentId, laboratoryId: lugar.laboratoryId })
    .onConflictDoUpdate({
      target: [rutaProgress.studentId, rutaProgress.laboratoryId],
      set: { updatedAt: new Date() },
    })
    .returning({ id: rutaProgress.id });
  await db
    .insert(rutaProgressLessons)
    .values({ rutaProgressId: fila!.id, lessonId: lesson.id })
    .onConflictDoNothing();
}

/**
 * Cómo quedó todo después de completar: curso, módulo, fase y Ruta. La
 * respuesta lo trae para que el cliente no tenga que volver a preguntar.
 */
export async function impactoDeLeccion(
  db: Database,
  studentId: string,
  lesson: Leccion,
): Promise<LessonImpact> {
  return {
    lessonId: lesson.id,
    completed: true,
    course: lesson.courseModuleId
      ? await courseImpact(db, studentId, lesson.courseModuleId)
      : null,
    rutaImpact: await rutaImpact(db, studentId, lesson),
  };
}

async function courseImpact(
  db: Database,
  studentId: string,
  courseModuleId: string,
): Promise<LessonImpact['course']> {
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
    nextLessonId: await siguienteLeccionDelCurso(db, studentId, row.course_id),
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
  lesson: Leccion,
): Promise<LessonImpact['rutaImpact']> {
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
