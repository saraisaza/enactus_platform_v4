import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Encuestas de verdad.
 *
 * Antes una encuesta eran preguntas abiertas que el estudiante contestaba en
 * un cuadro de texto y se mandaban como una ENTREGA: aparecían en la bandeja
 * de calificar, con nota pendiente, y nadie podía ver cuántos opinaban qué.
 * Ahora:
 *
 * 1. Cada pregunta es de elegir una opción, de calificar de 1 a 5 o de
 *    comentario libre. Ninguna tiene respuesta correcta.
 * 2. La respuesta se guarda aparte (una por persona) y completa la lección.
 * 3. Quien diseña el curso ve los resultados juntos y SIN nombres.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let est1Token = ''; // tiene acceso a crs_ia_1
let est3Token = ''; // no
let lxdToken = ''; // lxd1 — creó crs_ia_1
let otroLxdToken = ''; // lxd2 — no toca crs_ia_1

const ENCUESTA = seedId('lia6');
const QUIZ = seedId('lia4');
const PDF = seedId('lia3');
const CALIFICAR = seedId('q_lia6_1'); // de 1 a 5, «Nada útil» … «Muy útil»
const ELEGIR = seedId('q_lia6_2'); // Video / Lectura / Actividad práctica
const COMENTAR = seedId('q_lia6_3');

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const put = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PUT' });

const responder = (answers: Record<string, number | string>, token = est1Token) =>
  req(`/lessons/${ENCUESTA}/survey-response`, token, json({ answers }));

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

type Problema = { question: number; problem: string };

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
  est3Token = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  otroLxdToken = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('armar una encuesta', () => {
  const problemas = async (res: Response) =>
    (await body<{ error: { details: { problems: Problema[] } } }>(res)).error.details
      .problems;

  it('las tres clases de pregunta se guardan, sin clave de respuestas', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [
        { kind: 'scale', question: '¿Qué tan claro fue?', options: ['Nada claro', 'Muy claro'] },
        { kind: 'multiple', question: '¿Qué prefiere?', options: ['Mañana', 'Tarde'] },
        { kind: 'short', question: '¿Algo más?' },
      ],
    });
    expect(res.status).toBe(200);
    const b = await body<{
      questions: { kind: string; options: string[]; answerIndex: number | null }[];
    }>(res);
    expect(b.questions.map((q) => q.kind)).toEqual(['scale', 'multiple', 'short']);
    expect(b.questions[0]!.options).toEqual(['Nada claro', 'Muy claro']);
    expect(b.questions[1]!.options).toEqual(['Mañana', 'Tarde']);
    expect(b.questions.every((q) => q.answerIndex === null)).toBe(true);
  });

  it('calificar sin etiquetas también vale', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [{ kind: 'scale', question: '¿Qué tan claro fue?', options: ['', ''] }],
    });
    expect(res.status).toBe(200);
    const b = await body<{ questions: { options: string[] }[] }>(res);
    expect(b.questions[0]!.options).toEqual([]);
  });

  it('elegir una opción necesita al menos dos opciones con texto', async () => {
    const una = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [{ kind: 'multiple', question: '¿Qué prefiere?', options: ['Mañana'] }],
    });
    expect(una.status).toBe(409);
    expect((await problemas(una))[0]!.problem).toContain('dos opciones');

    const vacia = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [{ kind: 'multiple', question: '¿Qué prefiere?', options: ['Mañana', ' '] }],
    });
    expect(vacia.status).toBe(409);
    expect((await problemas(vacia))[0]!.problem).toContain('sin texto');
  });

  it('calificar lleva a lo sumo las dos etiquetas', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [{ kind: 'scale', question: '¿Qué tan claro fue?', options: ['a', 'b', 'c'] }],
    });
    expect(res.status).toBe(409);
    expect((await problemas(res))[0]!.problem).toContain('etiquetas');
  });

  it('verdadero/falso u ordenar no son preguntas de encuesta', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [{ kind: 'truefalse', question: '¿Le gustó?' }],
    });
    expect(res.status).toBe(409);
    expect((await problemas(res))[0]!.problem).toContain('calificar de 1 a 5');
  });

  it('calificar de 1 a 5 no va en un quiz: no tiene respuesta correcta', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [{ kind: 'scale', question: '¿Qué tan claro fue?', answerIndex: 0 }],
    });
    expect(res.status).toBe(409);
    expect((await problemas(res))[0]!.problem).toContain('no de quiz');
  });

  it('el estudiante ve las etiquetas de calificar, como opciones', async () => {
    // Vuelve a la encuesta sembrada.
    await seedTestDatabase();
    const res = await req(
      `/courses/${seedId('crs_ia_1')}?include=modules,lessons`,
      est1Token,
    );
    const raw = await res.text();
    expect(raw).toContain('Nada útil');
    expect(raw).toContain('Muy útil');
    expect(raw).toContain('"scale"');
  });
});

describe('responder una encuesta', () => {
  beforeAll(async () => {
    // est1 viene con el curso entero completo; esta encuesta, todavía no.
    await sql`
      delete from progress_lessons
       where lesson_id = ${ENCUESTA}
         and progress_id in (select id from progress where student_id = ${seedId('est1')})
    `;
  });

  it('falta calificar: 400, y dice cuál pregunta', async () => {
    const res = await responder({ [ELEGIR]: 1 });
    expect(res.status).toBe(400);
    const b = await body<{ error: { details: { preguntas: number[] } } }>(res);
    expect(b.error.details.preguntas).toEqual([1]);
  });

  it('una calificación fuera de 1 a 5, o una opción que no existe: 400', async () => {
    expect((await responder({ [CALIFICAR]: 6, [ELEGIR]: 0 })).status).toBe(400);
    expect((await responder({ [CALIFICAR]: 0, [ELEGIR]: 0 })).status).toBe(400);
    expect((await responder({ [CALIFICAR]: 4, [ELEGIR]: 3 })).status).toBe(400);
    expect((await responder({ [CALIFICAR]: 4, [ELEGIR]: 'Video' })).status).toBe(400);
  });

  it('el comentario es opcional, y responder completa la lección', async () => {
    const res = await responder({ [CALIFICAR]: 4, [ELEGIR]: 2 });
    expect(res.status).toBe(200);
    const b = await body<{ answers: Record<string, unknown> }>(res);
    expect(b.answers).toEqual({ [CALIFICAR]: 4, [ELEGIR]: 2 });

    const [hecha] = await sql<{ n: number }[]>`
      select count(*)::int as n from progress_lessons pl
        join progress p on p.id = pl.progress_id
       where p.student_id = ${seedId('est1')} and pl.lesson_id = ${ENCUESTA}
    `;
    expect(hecha!.n).toBe(1);
  });

  it('NO es una entrega ni un intento de quiz: nadie tiene que calificarla', async () => {
    const [entregas] = await sql<{ n: number }[]>`
      select count(*)::int as n from submissions where lesson_id = ${ENCUESTA}
    `;
    const [intentos] = await sql<{ n: number }[]>`
      select count(*)::int as n from quiz_attempts where lesson_id = ${ENCUESTA}
    `;
    expect(entregas!.n).toBe(0);
    expect(intentos!.n).toBe(0);
  });

  it('responder de nuevo reemplaza la respuesta, no la duplica', async () => {
    const res = await responder({ [CALIFICAR]: 5, [ELEGIR]: 0, [COMENTAR]: '  Más ejemplos  ' });
    expect(res.status).toBe(200);
    const filas = await sql<{ answers: Record<string, unknown> }[]>`
      select answers from survey_responses
       where lesson_id = ${ENCUESTA} and student_id = ${seedId('est1')}
    `;
    expect(filas).toHaveLength(1);
    expect(filas[0]!.answers).toEqual({ [CALIFICAR]: 5, [ELEGIR]: 0, [COMENTAR]: 'Más ejemplos' });
  });

  it('la persona ve lo que respondió', async () => {
    const res = await req(`/lessons/${ENCUESTA}/survey-response`, est1Token);
    expect(res.status).toBe(200);
    const b = await body<{ answers: Record<string, unknown> | null }>(res);
    expect(b.answers?.[CALIFICAR]).toBe(5);
  });

  it('quien no cursa el curso no la ve ni la responde: 404', async () => {
    expect((await responder({ [CALIFICAR]: 3, [ELEGIR]: 0 }, est3Token)).status).toBe(404);
    expect((await req(`/lessons/${ENCUESTA}/survey-response`, est3Token)).status).toBe(404);
  });

  it('un LXD no responde encuestas', async () => {
    expect((await responder({ [CALIFICAR]: 3, [ELEGIR]: 0 }, lxdToken)).status).toBe(403);
  });

  it('una lección que no es encuesta: 409', async () => {
    const res = await req(`/lessons/${QUIZ}/survey-response`, est1Token, json({ answers: {} }));
    expect(res.status).toBe(409);
  });
});

describe('ver los resultados', () => {
  type Resultados = {
    responses: number;
    questions: {
      id: string;
      kind: string;
      question: string;
      options: string[];
      counts?: number[];
      average?: number | null;
      comments?: string[];
    }[];
  };

  beforeAll(async () => {
    // Una segunda persona, para que haya algo que sumar.
    await sql`
      insert into survey_responses (lesson_id, student_id, answers)
      values (${ENCUESTA}, ${seedId('est2')},
              ${JSON.stringify({ [CALIFICAR]: 2, [ELEGIR]: 0, [COMENTAR]: 'Que sea más corto' })}::jsonb)
      on conflict do nothing
    `;
  });

  it('suma las opciones, reparte la calificación y junta los comentarios', async () => {
    const res = await req(`/lessons/${ENCUESTA}/survey-results`, lxdToken);
    expect(res.status).toBe(200);
    const b = await body<Resultados>(res);
    expect(b.responses).toBe(2);

    const calificar = b.questions.find((q) => q.id === CALIFICAR)!;
    expect(calificar.kind).toBe('scale');
    expect(calificar.counts).toEqual([0, 1, 0, 0, 1]);
    expect(calificar.average).toBe(3.5);
    expect(calificar.options).toEqual(['Nada útil', 'Muy útil']);

    const elegir = b.questions.find((q) => q.id === ELEGIR)!;
    expect(elegir.counts).toEqual([2, 0, 0]);

    const comentar = b.questions.find((q) => q.id === COMENTAR)!;
    expect(comentar.comments).toEqual(expect.arrayContaining(['Más ejemplos', 'Que sea más corto']));
  });

  it('son anónimos: no dicen quién respondió qué', async () => {
    const raw = await (await req(`/lessons/${ENCUESTA}/survey-results`, lxdToken)).text();
    expect(raw).not.toContain(seedId('est1'));
    expect(raw).not.toContain(seedId('est2'));
    expect(raw).not.toContain('studentId');
  });

  it('un estudiante no los ve, ni un LXD ajeno al curso', async () => {
    expect((await req(`/lessons/${ENCUESTA}/survey-results`, est1Token)).status).toBe(403);
    expect((await req(`/lessons/${ENCUESTA}/survey-results`, otroLxdToken)).status).toBe(403);
  });

  it('una lección que no es encuesta no tiene resultados: 409', async () => {
    expect((await req(`/lessons/${PDF}/survey-results`, lxdToken)).status).toBe(409);
  });
});
