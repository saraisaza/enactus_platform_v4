import type { Sql } from 'postgres';

import type { createApp } from '../../src/app';
import { auth, json } from './app';

/**
 * Completar lecciones en las pruebas, ahora que no se puede marcar a mano.
 *
 * Desde la migración 0020 cada lección pide su prueba —ver el video, aprobar
 * el quiz, entregar— y en orden (`services/avance-de-leccion.ts`). Las
 * pruebas que solo necesitan un punto de partida («el curso ya estaba
 * completo») escriben el hecho en la base con [completarEnLaBase]. Las que
 * recorren el camino de una persona usan [completarComoEstudiante], que hace
 * lo que haría ella.
 */

type App = ReturnType<typeof createApp>;

/** Escribe «completó esta lección» sin pasar por la API. Solo para preparar. */
export async function completarEnLaBase(
  sql: Sql,
  studentId: string,
  lessonId: string,
): Promise<void> {
  const [leccion] = await sql<{ course_id: string | null; laboratory_id: string | null }[]>`
    select cm.course_id, p.laboratory_id
      from lessons l
      left join course_modules cm on cm.id = l.course_module_id
      left join ruta_modules rm on rm.id = l.ruta_module_id
      left join phases p on p.id = rm.phase_id
     where l.id = ${lessonId}
  `;
  if (leccion?.course_id) {
    const [fila] = await sql<{ id: string }[]>`
      insert into progress (student_id, course_id)
      values (${studentId}, ${leccion.course_id})
      on conflict (student_id, course_id) do update set updated_at = now()
      returning id
    `;
    await sql`
      insert into progress_lessons (progress_id, lesson_id)
      values (${fila!.id}, ${lessonId}) on conflict do nothing
    `;
    return;
  }
  const [fila] = await sql<{ id: string }[]>`
    insert into ruta_progress (student_id, laboratory_id)
    values (${studentId}, ${leccion!.laboratory_id})
    on conflict (student_id, laboratory_id) do update set updated_at = now()
    returning id
  `;
  await sql`
    insert into ruta_progress_lessons (ruta_progress_id, lesson_id)
    values (${fila!.id}, ${lessonId}) on conflict do nothing
  `;
}

/**
 * Ve un video entero como lo vería una persona: el reproductor guarda un
 * punto de partida y después un tramo cada poco. El tiempo real que exige el
 * servidor se simula corriendo hacia atrás `updated_at` entre guardado y
 * guardado, para no esperar de verdad.
 *
 * Devuelve la última respuesta del guardado (con `completion`).
 */
export async function verVideoEntero(
  app: App,
  sql: Sql,
  token: string,
  studentId: string,
  lessonId: string,
  durationSec: number,
): Promise<Record<string, unknown>> {
  const guardar = async (cuerpo: Record<string, number>) => {
    const res = await app.request(`/progress/lessons/${lessonId}/video`, {
      ...json(cuerpo),
      method: 'PUT',
      headers: { 'content-type': 'application/json', ...auth(token) },
    });
    if (res.status !== 200) {
      throw new Error(`Guardar el video falló: ${res.status} ${await res.text()}`);
    }
    return (await res.json()) as Record<string, unknown>;
  };

  let ultima = await guardar({ positionSec: 0, durationSec, watchedFromSec: 0, watchedToSec: 0 });
  const paso = 60;
  for (let desde = 0; desde < durationSec; desde += paso) {
    const hasta = Math.min(desde + paso, durationSec);
    await pasaElTiempo(sql, studentId, lessonId, hasta - desde);
    ultima = await guardar({
      positionSec: hasta,
      durationSec,
      watchedFromSec: desde,
      watchedToSec: hasta,
    });
  }
  return ultima;
}

/** Corre hacia atrás el último guardado del video, como si pasaran [segundos]. */
export async function pasaElTiempo(
  sql: Sql,
  studentId: string,
  lessonId: string,
  segundos: number,
): Promise<void> {
  await sql`
    update lesson_video_progress
       set updated_at = updated_at - make_interval(secs => ${segundos})
     where student_id = ${studentId} and lesson_id = ${lessonId}
  `;
}

/**
 * Hace lo que la lección pide, por la API, como la persona: ver el video,
 * recorrer la lectura, aprobar el quiz con la clave, responder la encuesta o
 * entregar. Una actividad de curso queda entregada, no completa: esa la
 * completa quien califica.
 */
export async function completarComoEstudiante(
  app: App,
  sql: Sql,
  token: string,
  studentId: string,
  lessonId: string,
): Promise<Response> {
  const [l] = await sql<{
    type: string;
    video_type: string | null;
    video_duration_sec: number | null;
    course_id: string | null;
    ruta_module_id: string | null;
    title: string;
  }[]>`
    select l.type, l.video_type, l.video_duration_sec, cm.course_id, l.ruta_module_id, l.title
      from lessons l
      left join course_modules cm on cm.id = l.course_module_id
     where l.id = ${lessonId}
  `;
  const pedir = (path: string, init: RequestInit) =>
    app.request(path, { ...init, headers: { ...(init.headers ?? {}), ...auth(token) } });

  switch (l!.type) {
    case 'video':
      if (l!.video_type === 'youtube' || l!.video_type === 'uploaded') {
        await verVideoEntero(app, sql, token, studentId, lessonId, l!.video_duration_sec ?? 300);
      }
      return pedir(`/progress/lessons/${lessonId}/complete`, { method: 'POST' });
    case 'quiz': {
      const respuestas = await respuestasCorrectas(sql, lessonId);
      return pedir(`/lessons/${lessonId}/quiz-attempt`, json({ answers: respuestas }));
    }
    case 'survey': {
      const preguntas = await sql<{ id: string; kind: string }[]>`
        select id, kind::text from quiz_questions where lesson_id = ${lessonId}
      `;
      const respuestas = Object.fromEntries(
        preguntas.map((p) => [p.id, p.kind === 'scale' ? 4 : p.kind === 'multiple' ? 0 : 'Bien']),
      );
      return pedir(`/lessons/${lessonId}/survey-response`, json({ answers: respuestas }));
    }
    case 'activity':
      return pedir(
        '/submissions',
        json({
          ...(l!.course_id ? { courseId: l!.course_id } : { rutaModuleId: l!.ruta_module_id }),
          lessonId,
          taskName: l!.title,
          comment: 'Mi entrega.',
          files: [
            {
              s3Key: `submissions/${studentId}/${lessonId}-${Date.now()}.pdf`,
              fileName: 'entrega.pdf',
              contentType: 'application/pdf',
              sizeBytes: 1024,
            },
          ],
        }),
      );
    default:
      return pedir(`/progress/lessons/${lessonId}/complete`, { method: 'POST' });
  }
}

/** Las respuestas correctas de un quiz, leídas de la clave en la base. */
export async function respuestasCorrectas(
  sql: Sql,
  lessonId: string,
): Promise<Record<string, number | string>> {
  const preguntas = await sql<{
    id: string;
    kind: string;
    answer_index: number | null;
    answer_text: string | null;
  }[]>`
    select id, kind::text, answer_index, answer_text from quiz_questions
     where lesson_id = ${lessonId} order by order_index
  `;
  const respuestas: Record<string, number | string> = {};
  for (const p of preguntas) {
    if (p.kind === 'order') {
      const opciones = await sql<{ text: string }[]>`
        select text from quiz_question_options
         where quiz_question_id = ${p.id} order by order_index
      `;
      respuestas[p.id] = opciones.map((o) => o.text).join('|');
    } else if (p.kind === 'short' || p.kind === 'fill') {
      respuestas[p.id] = p.answer_text ?? '';
    } else {
      respuestas[p.id] = p.answer_index ?? 0;
    }
  }
  return respuestas;
}
