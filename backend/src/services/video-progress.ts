import { and, asc, eq, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { courseModules, lessonVideoProgress, lessons } from '../db/schema';
import { conflict } from '../lib/errors';
import {
  type LessonImpact,
  alcanzaLoVisto,
  cargarLeccion,
  duracionDeReferencia,
  estaCompleta,
  exigirDisponible,
  impactoDeLeccion,
  lugarDeLeccion,
  registrarCompleta,
  videoConAvance,
} from './avance-de-leccion';

/**
 * Hasta dónde vio un estudiante el video de una lección, y qué vio de verdad.
 *
 * Cada guardado trae la posición (dónde retomar) y el tramo que se reprodujo
 * desde el guardado anterior (`watchedFromSec` → `watchedToSec`). Los tramos
 * se unen en `watched_segments`; su suma, `watched_sec`, es lo que completa
 * la lección al llegar al 90% (`UMBRAL_VIDEO_VISTO`).
 *
 * **Adelantar no suma.** El reproductor informa un salto como el cierre del
 * tramo anterior, no como un tramo nuevo. Y aunque un cliente mintiera, un
 * tramo nunca vale más que el tiempo real que pasó desde el guardado anterior
 * (al doble de velocidad, que es lo más rápido que deja YouTube): ver un
 * video de diez minutos lleva, como mínimo, más de cuatro.
 *
 * Completar lo hace este guardado, en el servidor, y no el cliente al ver el
 * 90%: así no hay carrera entre «terminó» y el último tramo que todavía no
 * llegó.
 */

export interface VideoProgress {
  lessonId: string;
  positionSec: number;
  furthestSec: number;
  durationSec: number | null;
  /** Los segundos distintos que vio de verdad. */
  watchedSec: number;
  updatedAt: string;
}

export interface VideoProgressInput {
  positionSec: number;
  durationSec?: number | undefined;
  /** El tramo reproducido desde el guardado anterior. */
  watchedFromSec?: number | undefined;
  watchedToSec?: number | undefined;
}

export interface VideoSaveResult extends VideoProgress {
  /** Si la lección quedó completa con ESTE guardado; si no, `null`. */
  completion: LessonImpact | null;
}

/**
 * El reproductor más rápido que se acepta: YouTube llega a 2×. El 10% de
 * más cubre los segundos redondeados con que llegan los eventos. Es una
 * proporción y no unos segundos fijos por guardado: con segundos fijos, mil
 * guardados seguidos sumarían minutos sin ver nada.
 */
const VELOCIDAD_MAXIMA = 2 * 1.1;
/**
 * Lo más que puede valer un tramo, por largo que haya sido el silencio. El
 * reproductor guarda cada 15 segundos, al pausar y al saltar; con la pestaña
 * en segundo plano los avisos se espacian, y dos minutos lo cubren de sobra.
 */
const TRAMO_MAXIMO_SEC = 120;

export async function saveVideoProgress(
  db: Database,
  studentId: string,
  lessonId: string,
  input: VideoProgressInput,
): Promise<VideoSaveResult> {
  const lesson = await cargarLeccion(db, lessonId);

  // Mismo alcance que completar, y ANTES de mirar el tipo: un 409 «no es de
  // video» le confirmaría a alguien sin acceso que la lección existe.
  const lugar = await lugarDeLeccion(db, studentId, lesson);

  if (lesson.type !== 'video') {
    throw conflict('Esta lección no es de video: no hay posición que guardar.', {
      type: lesson.type,
    });
  }

  const yaCompleta = await estaCompleta(db, studentId, lesson, lugar);
  // Un video que todavía no le toca no se ve (ni se guarda): la pantalla lo
  // muestra con candado. Lo ya completado se repasa sin restricción.
  if (!yaCompleta) await exigirDisponible(db, studentId, lesson, lugar);

  const [previo] = await db
    .select()
    .from(lessonVideoProgress)
    .where(
      and(
        eq(lessonVideoProgress.studentId, studentId),
        eq(lessonVideoProgress.lessonId, lesson.id),
      ),
    )
    .limit(1);

  // Una posición más allá del final es un reporte desprolijo del reproductor
  // (el último evento llega con unos milisegundos de más), no un dato: se
  // recorta en vez de rechazar la escritura entera.
  const duration = input.durationSec ?? null;
  const conocida = duracionDeReferencia(
    lesson,
    Math.max(duration ?? 0, previo?.durationSec ?? 0) || null,
  );
  const position =
    conocida === null ? input.positionSec : Math.min(input.positionSec, conocida);

  const tramo = tramoAcreditable(input, previo ?? null, conocida, new Date());
  const tramos = unirTramos(previo?.watchedSegments ?? [], tramo);
  const visto = sumarTramos(tramos);

  const [row] = await db
    .insert(lessonVideoProgress)
    .values({
      studentId,
      lessonId: lesson.id,
      positionSec: position,
      furthestSec: position,
      durationSec: duration,
      watchedSegments: tramos,
      watchedSec: visto,
    })
    .onConflictDoUpdate({
      target: [lessonVideoProgress.studentId, lessonVideoProgress.lessonId],
      set: {
        positionSec: sql`excluded.position_sec`,
        // Solo crece: volver a ver un tramo no le resta lo que ya vio.
        furthestSec: sql`greatest(${lessonVideoProgress.furthestSec}, excluded.position_sec)`,
        // Un guardado sin duración (el reproductor todavía no la sabía) no
        // borra la que ya se tenía, y una duración más corta tampoco: con ella
        // se mide el 90%, y achicarla sería la forma de completar sin ver.
        durationSec: sql`greatest(excluded.duration_sec, ${lessonVideoProgress.durationSec})`,
        watchedSegments: sql`excluded.watched_segments`,
        watchedSec: sql`excluded.watched_sec`,
        updatedAt: new Date(),
      },
    })
    .returning();

  let completion: LessonImpact | null = null;
  if (
    !yaCompleta &&
    videoConAvance(lesson) &&
    alcanzaLoVisto(row!.watchedSec, duracionDeReferencia(lesson, row!.durationSec))
  ) {
    await registrarCompleta(db, studentId, lesson, lugar);
    completion = await impactoDeLeccion(db, studentId, lesson);
  }

  return { ...toVideoProgress(row!), completion };
}

/**
 * El tramo que se acredita con este guardado, o `null`.
 *
 * Lo pide el cliente (`watchedFromSec` → `watchedToSec`); un cliente viejo
 * que no lo manda acredita desde la posición anterior hasta la nueva. En los
 * dos casos se recorta al tiempo real que pasó desde el guardado anterior:
 * sin guardado anterior no hay contra qué medir, y el primero de cada sesión
 * —el que el reproductor manda al arrancar— solo fija ese punto de partida.
 */
export function tramoAcreditable(
  input: VideoProgressInput,
  previo: { positionSec: number; updatedAt: Date } | null,
  duracion: number | null,
  ahora: Date,
): [number, number] | null {
  if (!previo) return null;

  let desde: number;
  let hasta: number;
  if (input.watchedFromSec !== undefined && input.watchedToSec !== undefined) {
    desde = input.watchedFromSec;
    hasta = input.watchedToSec;
  } else {
    desde = previo.positionSec;
    hasta = input.positionSec;
  }
  if (duracion !== null) hasta = Math.min(hasta, duracion);
  if (hasta <= desde) return null;

  const segundos = Math.max(0, (ahora.getTime() - previo.updatedAt.getTime()) / 1000);
  const permitido = Math.min(Math.floor(segundos * VELOCIDAD_MAXIMA), TRAMO_MAXIMO_SEC);
  if (permitido <= 0) return null;
  // Lo más reciente del tramo es lo que se acaba de ver.
  return [Math.max(desde, hasta - permitido), hasta];
}

/** Agrega [tramo] a los ya vistos y los deja ordenados y sin solaparse. */
export function unirTramos(
  tramos: [number, number][],
  tramo: [number, number] | null,
): [number, number][] {
  const todos = tramo ? [...tramos, tramo] : [...tramos];
  todos.sort((a, b) => a[0] - b[0]);
  const unidos: [number, number][] = [];
  for (const [desde, hasta] of todos) {
    const ultimo = unidos[unidos.length - 1];
    if (ultimo && desde <= ultimo[1]) {
      ultimo[1] = Math.max(ultimo[1], hasta);
    } else {
      unidos.push([desde, hasta]);
    }
  }
  return unidos;
}

export function sumarTramos(tramos: [number, number][]): number {
  return tramos.reduce((total, [desde, hasta]) => total + (hasta - desde), 0);
}

/** Las posiciones de UN estudiante en las lecciones de UN curso. */
export async function videoProgressForCourse(
  db: Database,
  studentId: string,
  courseId: string,
): Promise<VideoProgress[]> {
  const rows = await db
    .select({
      lessonId: lessonVideoProgress.lessonId,
      positionSec: lessonVideoProgress.positionSec,
      furthestSec: lessonVideoProgress.furthestSec,
      durationSec: lessonVideoProgress.durationSec,
      watchedSec: lessonVideoProgress.watchedSec,
      updatedAt: lessonVideoProgress.updatedAt,
    })
    .from(lessonVideoProgress)
    .innerJoin(lessons, eq(lessons.id, lessonVideoProgress.lessonId))
    .innerJoin(courseModules, eq(courseModules.id, lessons.courseModuleId))
    .where(
      and(
        eq(lessonVideoProgress.studentId, studentId),
        eq(courseModules.courseId, courseId),
      ),
    )
    .orderBy(asc(courseModules.orderIndex), asc(lessons.orderIndex));
  return rows.map(toVideoProgress);
}

function toVideoProgress(row: {
  lessonId: string;
  positionSec: number;
  furthestSec: number;
  durationSec: number | null;
  watchedSec: number;
  updatedAt: Date;
}): VideoProgress {
  return {
    lessonId: row.lessonId,
    positionSec: row.positionSec,
    furthestSec: row.furthestSec,
    durationSec: row.durationSec,
    watchedSec: row.watchedSec,
    updatedAt: row.updatedAt.toISOString(),
  };
}
