import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { notaAprobatoria } from '../src/services/avance-de-leccion';
import { sumarTramos, tramoAcreditable, unirTramos } from '../src/services/video-progress';
import { auth, login, makeTestApp } from './helpers/app';
import {
  completarEnLaBase,
  pasaElTiempo,
  respuestasCorrectas,
  verVideoEntero,
} from './helpers/avance';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Avance en orden y sin marcar a mano (pedido de Sara, 2026-10-14).
 *
 * En la prueba beta de Open Learning, una estudiante marcaba lecciones como
 * completas tocando el círculo —en el teléfono desde la primera parte del
 * módulo, en el computador desde la segunda—, sin ver el video ni leer el
 * material, y pasaba a las siguientes. Estas pruebas fijan las dos reglas
 * que ahora hace cumplir el servidor:
 *
 * 1. Ninguna lección se completa a mano: cada una con su prueba (ver el
 *    video de verdad, aprobar el quiz, responder la encuesta, una entrega
 *    calificada aprobada…).
 * 2. En orden: no se hace una lección —ni de un módulo siguiente— sin haber
 *    completado las anteriores.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let admin = '';

const pedir = (ruta: string, metodo: string, token?: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...(token ? auth(token) : {}) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

const leer = async <T>(res: Response): Promise<T> => (await res.json()) as T;

type Error409 = { error: { code: string; message: string; details?: Record<string, unknown> } };

async function crear<T = { id: string }>(ruta: string, cuerpo: unknown, token = admin): Promise<T> {
  const res = await pedir(ruta, 'POST', token, cuerpo);
  expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(201);
  return (await res.json()) as T;
}

/**
 * El curso de la prueba beta, con lo demás que puede tener un curso:
 *
 * - Módulo «Visualización video»: un video de YouTube y su quiz.
 * - Módulo «Lectura PDF»: una lectura.
 * - Módulo «Cierre»: una encuesta, una actividad y otro video.
 */
async function cursoBeta(nombre: string) {
  const curso = await crear('/courses', { name: nombre, isOpenLearning: true });
  const leccion = async (moduloId: string, title: string, type: string) =>
    (await crear(`/modules/${moduloId}/lessons`, { title, type })).id;

  const m1 = await crear(`/courses/${curso.id}/modules`, { title: 'Visualización video' });
  const video = await leccion(m1.id, 'Conformar equipo', 'video');
  await pedir(`/lessons/${video}/video-youtube`, 'POST', admin, { videoId: 'dQw4w9WgXcQ' });
  const quiz = await leccion(m1.id, 'Preguntas del video', 'quiz');
  expect(
    (await pedir(`/lessons/${quiz}/quiz`, 'PUT', admin, {
      questions: [
        { kind: 'truefalse', question: '¿Un equipo necesita roles?', answerIndex: 0 },
        { kind: 'multiple', question: '¿Cuántos?', options: ['Uno', 'Varios'], answerIndex: 1 },
      ],
    })).status,
  ).toBe(200);

  const m2 = await crear(`/courses/${curso.id}/modules`, { title: 'Lectura PDF' });
  const pdf = await leccion(m2.id, 'Lectura pdf', 'pdf');

  const m3 = await crear(`/courses/${curso.id}/modules`, { title: 'Cierre' });
  const encuesta = await leccion(m3.id, 'Su opinión', 'survey');
  expect(
    (await pedir(`/lessons/${encuesta}/quiz`, 'PUT', admin, {
      questions: [{ kind: 'scale', question: '¿Le sirvió?', options: [] }],
    })).status,
  ).toBe(200);
  const actividad = await leccion(m3.id, 'Plan del equipo', 'activity');
  const videoFinal = await leccion(m3.id, 'Cierre en video', 'video');
  await pedir(`/lessons/${videoFinal}/video-youtube`, 'POST', admin, { videoId: 'aaaaaaaaaaa' });

  await sql`update courses set status = 'published' where id = ${curso.id}`;
  const correo = `${nombre.toLowerCase().replace(/\W+/g, '')}@beta.co`;
  const persona = await crear('/users', {
    name: `Estudiante de ${nombre}`, email: correo, password: 'Clave123',
    role: 'student', studentType: 'open_learning',
  });
  expect((await pedir(`/users/${persona.id}/courses`, 'PUT', admin, { ids: [curso.id] })).status)
    .toBe(200);
  const token = (await login(t.app, correo, 'Clave123')).accessToken;
  return {
    cursoId: curso.id, personaId: persona.id, token,
    video, quiz, pdf, encuesta, actividad, videoFinal,
  };
}

async function completadas(personaId: string, cursoId: string): Promise<string[]> {
  const filas = await sql<{ lesson_id: string }[]>`
    select pl.lesson_id from progress_lessons pl
      join progress p on p.id = pl.progress_id
     where p.student_id = ${personaId} and p.course_id = ${cursoId}`;
  return filas.map((f) => f.lesson_id);
}

async function siguiente(c: { personaId: string; cursoId: string; token: string }) {
  const res = await pedir(`/students/${c.personaId}/course-progress/${c.cursoId}`, 'GET', c.token);
  expect(res.status).toBe(200);
  return (await leer<{ nextLessonId: string | null }>(res)).nextLessonId;
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('el círculo ya no marca nada', () => {
  it('completar el video sin verlo responde 409, con el nombre viejo y el nuevo', async () => {
    const c = await cursoBeta('Círculo');
    for (const ruta of ['complete', 'toggle']) {
      const res = await pedir(`/progress/lessons/${c.video}/${ruta}`, 'POST', c.token);
      expect(res.status).toBe(409);
      const b = await leer<Error409>(res);
      expect(b.error.message).toBe(
        'Vea el video completo para completar esta lección: adelantarlo no cuenta.',
      );
    }
    expect(await completadas(c.personaId, c.cursoId)).toEqual([]);
  });

  it('el quiz no se completa a mano: hay que aprobarlo', async () => {
    const c = await cursoBeta('Quiz a mano');
    await completarEnLaBase(sql, c.personaId, c.video);
    const res = await pedir(`/progress/lessons/${c.quiz}/complete`, 'POST', c.token);
    expect(res.status).toBe(409);
    expect((await leer<Error409>(res)).error.message).toBe(
      'Apruebe el quiz para completar esta lección.',
    );
  });

  it('tampoco la encuesta ni la actividad', async () => {
    const c = await cursoBeta('Sin prueba');
    for (const l of [c.video, c.quiz, c.pdf]) await completarEnLaBase(sql, c.personaId, l);

    const encuesta = await pedir(`/progress/lessons/${c.encuesta}/complete`, 'POST', c.token);
    expect(encuesta.status).toBe(409);
    expect((await leer<Error409>(encuesta)).error.message).toBe(
      'Responda la encuesta para completar esta lección.',
    );

    await completarEnLaBase(sql, c.personaId, c.encuesta);
    const actividad = await pedir(`/progress/lessons/${c.actividad}/complete`, 'POST', c.token);
    expect(actividad.status).toBe(409);
    expect((await leer<Error409>(actividad)).error.message).toBe(
      'Esta actividad se completa cuando su entrega sea calificada como aprobada.',
    );
  });

  it('lo completado ya no se desmarca', async () => {
    const c = await cursoBeta('Sin desmarcar');
    await pedir(`/progress/lessons/${c.video}/complete`, 'POST', c.token);
    await completarEnLaBase(sql, c.personaId, c.video);
    for (const ruta of ['toggle', 'toggle', 'complete']) {
      const res = await pedir(`/progress/lessons/${c.video}/${ruta}`, 'POST', c.token);
      expect(res.status).toBe(200);
      expect((await leer<{ completed: boolean }>(res)).completed).toBe(true);
    }
    expect(await completadas(c.personaId, c.cursoId)).toEqual([c.video]);
  });
});

describe('en orden', () => {
  it('la lectura del módulo 2 no se completa antes que el módulo 1', async () => {
    const c = await cursoBeta('Orden lectura');
    const res = await pedir(`/progress/lessons/${c.pdf}/complete`, 'POST', c.token);
    expect(res.status).toBe(409);
    const b = await leer<Error409>(res);
    expect(b.error.message).toBe('Primero complete «Conformar equipo».');
    expect(b.error.details?.pendiente).toEqual({ id: c.video, title: 'Conformar equipo' });
    expect(await completadas(c.personaId, c.cursoId)).toEqual([]);
  });

  it('el quiz no se responde antes de ver su video', async () => {
    const c = await cursoBeta('Orden quiz');
    const res = await pedir(`/lessons/${c.quiz}/quiz-attempt`, 'POST', c.token, {
      answers: await respuestasCorrectas(sql, c.quiz),
    });
    expect(res.status).toBe(409);
    expect((await leer<Error409>(res)).error.message).toBe('Primero complete «Conformar equipo».');
    const [intentos] = await sql<{ n: number }[]>`
      select count(*)::int as n from quiz_attempts where lesson_id = ${c.quiz}`;
    expect(intentos!.n).toBe(0);
  });

  it('ni la encuesta, ni la entrega, ni el video de un módulo siguiente', async () => {
    const c = await cursoBeta('Orden cierre');
    await completarEnLaBase(sql, c.personaId, c.video);

    const encuesta = await pedir(`/lessons/${c.encuesta}/survey-response`, 'POST', c.token, {
      answers: {},
    });
    expect(encuesta.status).toBe(409);
    expect((await leer<Error409>(encuesta)).error.message).toBe(
      'Primero complete «Preguntas del video».',
    );

    const entrega = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan', comment: 'Listo',
    });
    expect(entrega.status).toBe(409);

    const video = await pedir(`/progress/lessons/${c.videoFinal}/video`, 'PUT', c.token, {
      positionSec: 0, durationSec: 300,
    });
    expect(video.status).toBe(409);
  });

  it('el progreso dice cuál le toca, y avanza con cada lección', async () => {
    const c = await cursoBeta('Siguiente');
    expect(await siguiente(c)).toBe(c.video);
    await completarEnLaBase(sql, c.personaId, c.video);
    expect(await siguiente(c)).toBe(c.quiz);
    await completarEnLaBase(sql, c.personaId, c.quiz);
    expect(await siguiente(c)).toBe(c.pdf);
  });

  it('una lección hecha se puede repasar aunque falte una anterior', async () => {
    // Avances de antes del cambio: alguien marcó el quiz a mano y desmarcó el
    // video (las capturas de la beta). El quiz se puede volver a intentar;
    // lo que sigue al video, no.
    const c = await cursoBeta('Repaso');
    await completarEnLaBase(sql, c.personaId, c.quiz);
    const repaso = await pedir(`/lessons/${c.quiz}/quiz-attempt`, 'POST', c.token, {
      answers: await respuestasCorrectas(sql, c.quiz),
    });
    expect(repaso.status).toBe(200);
    const lectura = await pedir(`/progress/lessons/${c.pdf}/complete`, 'POST', c.token);
    expect(lectura.status).toBe(409);
    expect(await siguiente(c)).toBe(c.video);
  });
});

describe('el video se completa viéndolo', () => {
  it('saltar al final no suma: lo visto queda en cero', async () => {
    const c = await cursoBeta('Saltar');
    await pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, {
      positionSec: 0, durationSec: 300, watchedFromSec: 0, watchedToSec: 0,
    });
    // Un cliente que dijera haber visto todo, un segundo después.
    await pasaElTiempo(sql, c.personaId, c.video, 1);
    const res = await pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, {
      positionSec: 300, durationSec: 300, watchedFromSec: 0, watchedToSec: 300,
    });
    const p = await leer<{ furthestSec: number; watchedSec: number; completion: unknown }>(res);
    expect(p.furthestSec).toBe(300);
    expect(p.watchedSec).toBeLessThanOrEqual(2);
    expect(p.completion).toBeNull();

    const completar = await pedir(`/progress/lessons/${c.video}/complete`, 'POST', c.token);
    expect(completar.status).toBe(409);
  });

  it('un cliente viejo, sin tramos, tampoco suma al saltar', async () => {
    const c = await cursoBeta('Cliente viejo');
    await pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, { positionSec: 10 });
    const res = await pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, {
      positionSec: 300, durationSec: 300,
    });
    expect((await leer<{ watchedSec: number }>(res)).watchedSec).toBe(0);
  });

  it('ver el mismo tramo dos veces no cuenta doble', async () => {
    const c = await cursoBeta('Dos veces');
    const guardar = (cuerpo: Record<string, number>) =>
      pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, { durationSec: 300, ...cuerpo });
    await guardar({ positionSec: 0, watchedFromSec: 0, watchedToSec: 0 });
    for (let vez = 0; vez < 2; vez++) {
      await pasaElTiempo(sql, c.personaId, c.video, 60);
      await guardar({ positionSec: 60, watchedFromSec: 0, watchedToSec: 60 });
    }
    const [fila] = await sql<{ watched_sec: number }[]>`
      select watched_sec from lesson_video_progress
       where student_id = ${c.personaId} and lesson_id = ${c.video}`;
    expect(fila!.watched_sec).toBe(60);
  });

  it('verlo entero lo completa en el servidor, y abre el quiz', async () => {
    const c = await cursoBeta('Verlo entero');
    const ultima = await verVideoEntero(t.app, sql, c.token, c.personaId, c.video, 300);
    expect(ultima.watchedSec).toBe(300);
    const completion = ultima.completion as { completed: boolean; course: { completedLessons: number } };
    expect(completion.completed).toBe(true);
    expect(completion.course.completedLessons).toBe(1);
    expect(await completadas(c.personaId, c.cursoId)).toEqual([c.video]);
    expect(await siguiente(c)).toBe(c.quiz);
  });

  it('con el 90% alcanza: los créditos del final no cuentan', async () => {
    const c = await cursoBeta('Noventa');
    const guardar = (cuerpo: Record<string, number>) =>
      pedir(`/progress/lessons/${c.video}/video`, 'PUT', c.token, { durationSec: 300, ...cuerpo });
    await guardar({ positionSec: 0, watchedFromSec: 0, watchedToSec: 0 });
    let respuesta: { completion: unknown } | undefined;
    for (let desde = 0; desde < 270; desde += 90) {
      await pasaElTiempo(sql, c.personaId, c.video, 90);
      respuesta = await leer(await guardar({
        positionSec: desde + 90, watchedFromSec: desde, watchedToSec: desde + 90,
      }));
    }
    expect(respuesta?.completion).not.toBeNull();
  });
});

describe('el teléfono y el computador de la misma persona', () => {
  // Un estudiante reportó que el avance no coincidía entre el teléfono y el
  // computador. El avance vive en el servidor: estas pruebas fijan que lo
  // hecho en una sesión es lo que lee la otra, y que dos sesiones guardando
  // el mismo video a la vez no se pisan.
  async function dosSesiones(nombre: string) {
    const c = await cursoBeta(nombre);
    const correo = `${nombre.toLowerCase().replace(/\W+/g, '')}@beta.co`;
    const telefono = (await login(t.app, correo, 'Clave123')).accessToken;
    return { ...c, computador: c.token, telefono };
  }

  const guardarVideo = (leccion: string, token: string, cuerpo: Record<string, number>) =>
    pedir(`/progress/lessons/${leccion}/video`, 'PUT', token, { durationSec: 300, ...cuerpo });

  it('lo completado en el computador es lo que lee el teléfono', async () => {
    const c = await dosSesiones('Completa en uno');
    await verVideoEntero(t.app, sql, c.computador, c.personaId, c.video, 300);
    expect(await siguiente({ ...c, token: c.telefono })).toBe(c.quiz);
  });

  it('el navegador no guarda el avance: cada lectura va al servidor', async () => {
    const c = await dosSesiones('Sin guardar');
    const res = await pedir(`/students/${c.personaId}/course-progress/${c.cursoId}`, 'GET', c.telefono);
    expect(res.headers.get('cache-control')).toBe('no-store');
  });

  it('el video sigue en el teléfono donde quedó en el computador, y suma', async () => {
    const c = await dosSesiones('Sigue en otro');
    await guardarVideo(c.video, c.computador, { positionSec: 0, watchedFromSec: 0, watchedToSec: 0 });
    await pasaElTiempo(sql, c.personaId, c.video, 120);
    await guardarVideo(c.video, c.computador, {
      positionSec: 120, watchedFromSec: 0, watchedToSec: 120,
    });

    const res = await pedir(`/students/${c.personaId}/course-progress/${c.cursoId}`, 'GET', c.telefono);
    const progreso = await leer<{ videoProgress: { lessonId: string; positionSec: number; watchedSec: number }[] }>(res);
    const video = progreso.videoProgress.find((v) => v.lessonId === c.video);
    expect(video?.positionSec).toBe(120);
    expect(video?.watchedSec).toBe(120);

    // El teléfono arranca donde quedó y sigue: lo visto se suma, no empieza de cero.
    await guardarVideo(c.video, c.telefono, { positionSec: 120, watchedFromSec: 120, watchedToSec: 120 });
    await pasaElTiempo(sql, c.personaId, c.video, 60);
    const sigue = await leer<{ watchedSec: number }>(await guardarVideo(c.video, c.telefono, {
      positionSec: 180, watchedFromSec: 120, watchedToSec: 180,
    }));
    expect(sigue.watchedSec).toBe(180);
  });

  it('dos sesiones a la vez: ninguna falla, y lo visto no supera el tiempo real', async () => {
    const c = await dosSesiones('A la vez');
    await guardarVideo(c.video, c.computador, { positionSec: 0, watchedFromSec: 0, watchedToSec: 0 });
    await pasaElTiempo(sql, c.personaId, c.video, 60);
    // La fila se toma al guardar: el segundo guardado lee lo que dejó el
    // primero. Una persona no ve dos tramos a la vez, así que pasados 60
    // segundos no se acreditan 120 por tener dos pantallas abiertas.
    const respuestas = await Promise.all([
      guardarVideo(c.video, c.computador, { positionSec: 60, watchedFromSec: 0, watchedToSec: 60 }),
      guardarVideo(c.video, c.telefono, { positionSec: 260, watchedFromSec: 200, watchedToSec: 260 }),
    ]);
    expect(respuestas.map((r) => r.status)).toEqual([200, 200]);
    const [fila] = await sql<{ watched_sec: number }[]>`
      select watched_sec from lesson_video_progress
       where student_id = ${c.personaId} and lesson_id = ${c.video}`;
    expect(fila!.watched_sec).toBe(60);
  });
});

describe('el quiz se completa aprobándolo', () => {
  it('reprobar no completa; aprobar sí, y lo dice la respuesta', async () => {
    const c = await cursoBeta('Aprobar');
    await completarEnLaBase(sql, c.personaId, c.video);
    const correctas = await respuestasCorrectas(sql, c.quiz);
    const malas = Object.fromEntries(
      Object.entries(correctas).map(([id, v]) => [id, typeof v === 'number' ? v + 1 : 'x']),
    );

    const reprobado = await pedir(`/lessons/${c.quiz}/quiz-attempt`, 'POST', c.token, { answers: malas });
    const r = await leer<{ passed: boolean; lessonCompleted: boolean; impact: unknown }>(reprobado);
    expect(r.passed).toBe(false);
    expect(r.lessonCompleted).toBe(false);
    expect(r.impact).toBeNull();
    expect(await siguiente(c)).toBe(c.quiz);

    const aprobado = await pedir(`/lessons/${c.quiz}/quiz-attempt`, 'POST', c.token, { answers: correctas });
    const a = await leer<{
      passed: boolean;
      lessonCompleted: boolean;
      impact: { course: { completedLessons: number } };
    }>(aprobado);
    expect(a.passed).toBe(true);
    expect(a.lessonCompleted).toBe(true);
    expect(a.impact.course.completedLessons).toBe(2);
    expect(await siguiente(c)).toBe(c.pdf);
    expect((a.impact.course as { nextLessonId?: string }).nextLessonId).toBe(c.pdf);

    // Reprobar después de aprobar no lo des-completa.
    await pedir(`/lessons/${c.quiz}/quiz-attempt`, 'POST', c.token, { answers: malas });
    expect(await completadas(c.personaId, c.cursoId)).toContain(c.quiz);
  });
});

describe('la actividad se completa calificada aprobada', () => {
  it('entregar no la completa; reprobada tampoco; aprobada sí', async () => {
    const c = await cursoBeta('Actividad');
    for (const l of [c.video, c.quiz, c.pdf, c.encuesta]) {
      await completarEnLaBase(sql, c.personaId, l);
    }

    const vacia = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan',
    });
    expect(vacia.status).toBe(400);
    expect((await leer<Error409>(vacia)).error.message).toBe(
      'La entrega está vacía: escriba su respuesta o adjunte un archivo.',
    );

    const entrega = await crear('/submissions', {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan', comment: 'Nuestro plan.',
    }, c.token);
    expect(await siguiente(c)).toBe(c.actividad);

    const reprobada = await pedir(`/submissions/${entrega.id}/grade`, 'POST', admin, {
      gradingMode: 'points100', grade: 40, feedback: 'Falta el presupuesto.',
    });
    expect(reprobada.status).toBe(200);
    expect(await siguiente(c)).toBe(c.actividad);
    expect((await pedir(`/progress/lessons/${c.actividad}/complete`, 'POST', c.token)).status)
      .toBe(409);

    const aprobada = await pedir(`/submissions/${entrega.id}/grade`, 'POST', admin, {
      gradingMode: 'points100', grade: 85, feedback: 'Bien.',
    });
    expect(aprobada.status).toBe(200);
    expect(await siguiente(c)).toBe(c.videoFinal);
  });

  it('pide lo que la actividad configura', async () => {
    const c = await cursoBeta('Configurada');
    for (const l of [c.video, c.quiz, c.pdf, c.encuesta]) {
      await completarEnLaBase(sql, c.personaId, l);
    }
    expect((await pedir(`/lessons/${c.actividad}/activity`, 'PUT', admin, {
      description: 'Suba su plan', requiresFile: true, requiresText: true, maxFiles: 1,
      allowedTypes: ['pdf'], rubric: [], gradingMode: 'points100',
    })).status).toBe(200);

    const sinArchivo = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan', comment: 'Texto',
    });
    expect(sinArchivo.status).toBe(400);
    expect((await leer<Error409>(sinArchivo)).error.message).toBe(
      'Esta actividad pide adjuntar al menos un archivo.',
    );

    const archivo = (n: number) => ({
      s3Key: `submissions/${c.personaId}/plan-${n}.pdf`, fileName: `plan-${n}.pdf`,
      contentType: 'application/pdf', sizeBytes: 10,
    });
    const sinTexto = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan', files: [archivo(1)],
    });
    expect(sinTexto.status).toBe(400);

    const demasiados = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.actividad, taskName: 'Plan', comment: 'Texto',
      files: [archivo(2), archivo(3)],
    });
    expect(demasiados.status).toBe(400);
  });

  it('una entrega solo va a una actividad de ese mismo curso', async () => {
    const c = await cursoBeta('Ajena');
    const otra = await cursoBeta('Otra');
    const ajena = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: otra.actividad, taskName: 'X', comment: 'X',
    });
    expect(ajena.status).toBe(403);

    const noEsActividad = await pedir('/submissions', 'POST', c.token, {
      courseId: c.cursoId, lessonId: c.video, taskName: 'X', comment: 'X',
    });
    expect(noEsActividad.status).toBe(409);
  });
});

describe('la encuesta se completa respondiéndola', () => {
  it('respondida en su turno, completa la lección', async () => {
    const c = await cursoBeta('Encuesta');
    for (const l of [c.video, c.quiz, c.pdf]) await completarEnLaBase(sql, c.personaId, l);
    const [pregunta] = await sql<{ id: string }[]>`
      select id from quiz_questions where lesson_id = ${c.encuesta}`;
    const res = await pedir(`/lessons/${c.encuesta}/survey-response`, 'POST', c.token, {
      answers: { [pregunta!.id]: 5 },
    });
    expect(res.status).toBe(200);
    expect(await siguiente(c)).toBe(c.actividad);
  });
});

describe('la Ruta, en orden', () => {
  // alum1 está en lab_ia, con «Introducción a la IA» a medias (2 de 6) y
  // ninguna lectura de la Ruta hecha.
  const alum1 = seedId('alum1');
  let token = '';

  beforeAll(async () => {
    token = (await login(t.app, 'alumni1@uniandes.edu.co', 'Alumni123')).accessToken;
  });

  it('una lección propia no se hace antes que la anterior del módulo', async () => {
    const [segunda] = await sql<{ id: string }[]>`
      insert into lessons (ruta_module_id, order_index, title, type)
      values (${seedId('lab_ia_fase1_mod1')}, 2, 'Lectura dos', 'pdf') returning id`;
    const antes = await pedir(`/progress/lessons/${segunda!.id}/complete`, 'POST', token);
    expect(antes.status).toBe(409);
    expect((await leer<Error409>(antes)).error.message).toBe('Primero complete «Guía de la Fase 1».');

    const primera = await pedir(
      `/progress/lessons/${seedId('lab_ia_fase1_mod1_lect1')}/complete`, 'POST', token,
    );
    expect(primera.status).toBe(200);
    expect((await pedir(`/progress/lessons/${segunda!.id}/complete`, 'POST', token)).status)
      .toBe(200);
  });

  it('el módulo siguiente espera al anterior completo, curso incluido', async () => {
    const asistencia = seedId('lab_ia_fase1_mod2_asistencia');
    const entrega = () => pedir('/submissions', 'POST', token, {
      rutaModuleId: seedId('lab_ia_fase1_mod2'), lessonId: asistencia,
      taskName: 'Asistencia', comment: 'Asistí a la reunión.',
    });
    const bloqueada = await entrega();
    expect(bloqueada.status).toBe(409);
    expect((await leer<Error409>(bloqueada)).error.message).toBe(
      'Primero complete el módulo «Módulo 1: Introducción a la IA».',
    );

    // La pantalla lo dibuja con candado.
    const ruta = await leer<{
      laboratories: { laboratoryId: string; phases: { modules: { ownLessons: { id: string; isUnlocked: boolean }[] }[] }[] }[];
    }>(await pedir(`/students/${alum1}/ruta-progress`, 'GET', token));
    const propias = ruta.laboratories
      .find((l) => l.laboratoryId === seedId('lab_ia'))!
      .phases[0]!.modules.flatMap((m) => m.ownLessons);
    expect(propias.find((l) => l.id === asistencia)?.isUnlocked).toBe(false);
    expect(propias.find((l) => l.id === seedId('lab_ia_fase1_mod1_lect1'))?.isUnlocked).toBe(true);

    // Con el curso del módulo 1 completo, se abre; y entregar la completa.
    for (const l of ['lia3', 'lia4', 'lia5', 'lia6']) await completarEnLaBase(sql, alum1, seedId(l));
    const vacia = await pedir('/submissions', 'POST', token, {
      rutaModuleId: seedId('lab_ia_fase1_mod2'), lessonId: asistencia, taskName: 'Asistencia',
    });
    expect(vacia.status).toBe(400);
    const hecha = await entrega();
    expect(hecha.status).toBe(201);
    const b = await leer<{ impact: { completed: boolean; rutaImpact: { phaseComplete: boolean }[] } }>(hecha);
    expect(b.impact.completed).toBe(true);
    expect(b.impact.rutaImpact[0]?.phaseComplete).toBe(true);
  });

  it('una fase bloqueada no deja hacer nada', async () => {
    const [mod] = await sql<{ id: string }[]>`
      insert into ruta_modules (phase_id, order_index, title, is_mentorship_module)
      values (${seedId('lab_ia_fase3')}, 1, 'Módulo de la fase 3', false) returning id`;
    const [lec] = await sql<{ id: string }[]>`
      insert into lessons (ruta_module_id, order_index, title, type)
      values (${mod!.id}, 1, 'Lectura de la fase 3', 'pdf') returning id`;
    const res = await pedir(`/progress/lessons/${lec!.id}/complete`, 'POST', token);
    expect(res.status).toBe(409);
    expect((await leer<Error409>(res)).error.message).toBe(
      'Esta fase de la Ruta todavía está bloqueada: complete primero la fase anterior.',
    );
  });
});

describe('las cuentas de lo visto', () => {
  const ahora = new Date('2026-10-14T12:00:00Z');
  const hace = (s: number) => ({ positionSec: 0, updatedAt: new Date(ahora.getTime() - s * 1000) });

  it('sin un guardado anterior no se acredita nada: el primero es el punto de partida', () => {
    expect(tramoAcreditable({ positionSec: 300, watchedFromSec: 0, watchedToSec: 300 }, null, 300, ahora))
      .toBeNull();
  });

  it('un tramo vale, como mucho, el tiempo real que pasó a 2×', () => {
    expect(tramoAcreditable({ positionSec: 15, watchedFromSec: 0, watchedToSec: 15 }, hace(15), 300, ahora))
      .toEqual([0, 15]);
    expect(tramoAcreditable({ positionSec: 300, watchedFromSec: 0, watchedToSec: 300 }, hace(10), 300, ahora))
      .toEqual([278, 300]);
    // Y nunca más de dos minutos, por largo que haya sido el silencio.
    expect(tramoAcreditable({ positionSec: 900, watchedFromSec: 0, watchedToSec: 900 }, hace(86400), 900, ahora))
      .toEqual([780, 900]);
  });

  it('un tramo al revés o vacío no suma', () => {
    expect(tramoAcreditable({ positionSec: 10, watchedFromSec: 50, watchedToSec: 10 }, hace(60), 300, ahora))
      .toBeNull();
    expect(tramoAcreditable({ positionSec: 50, watchedFromSec: 50, watchedToSec: 50 }, hace(60), 300, ahora))
      .toBeNull();
  });

  it('los tramos se unen sin contar dos veces lo mismo', () => {
    const tramos = unirTramos(unirTramos([[0, 60]], [120, 180]), [50, 130]);
    expect(tramos).toEqual([[0, 180]]);
    expect(sumarTramos(tramos)).toBe(180);
    expect(unirTramos([[0, 10]], null)).toEqual([[0, 10]]);
  });

  it('qué nota aprueba, en cada escala', () => {
    expect(notaAprobatoria('points100', 60)).toBe(true);
    expect(notaAprobatoria('points100', 59)).toBe(false);
    expect(notaAprobatoria('scale5', 3)).toBe(true);
    expect(notaAprobatoria('scale5', 2.5)).toBe(false);
    expect(notaAprobatoria('passfail', 1)).toBe(true);
    expect(notaAprobatoria('passfail', 0)).toBe(false);
    expect(notaAprobatoria('review', null)).toBe(true);
    expect(notaAprobatoria('points100', null)).toBe(false);
  });
});
