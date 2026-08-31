import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Corrección del quiz en el SERVIDOR.
 *
 * Antes el curso viajaba entero al navegador con la clave de respuestas
 * dentro, y la nota que el cliente reportaba se guardaba sin verificar. Esta
 * suite prueba las dos mitades del arreglo:
 *
 * 1. Que la clave **no salga** en ninguna respuesta de la API.
 * 2. Que la nota la calcule el servidor a partir de las respuestas enviadas.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let est1Token = '';
let est3Token = '';
let lxdToken = '';

const QUIZ = seedId('lia4');
const Q1 = seedId('q_lia4_1'); // multiple, correcta: índice 0
const Q2 = seedId('q_lia4_2'); // truefalse, correcta: índice 0
const Q3 = seedId('q_lia4_3'); // short, correcta: "datos de entrenamiento"
const Q4 = seedId('q_lia4_4'); // order — la clave es el orden de sus opciones

/** El orden correcto de Q4, tal como el cliente lo manda: unido por `|`. */
const ORDEN_CORRECTO = [
  'Recolectar datos',
  'Entrenar el modelo',
  'Evaluar resultados',
  'Desplegar la solución',
].join('|');

/** Las cuatro respuestas correctas del quiz sembrado. */
const TODO_BIEN = {
  [Q1]: 0,
  [Q2]: 0,
  [Q3]: 'datos de entrenamiento',
  [Q4]: ORDEN_CORRECTO,
};

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

const attempt = (answers: Record<string, number | string>, token: string) =>
  req(`/lessons/${QUIZ}/quiz-attempt`, token, json({ answers }));

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
  est3Token = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('la clave de respuestas nunca sale de la base', () => {
  it('el detalle del curso trae las preguntas SIN answerIndex ni answerText', async () => {
    const res = await req(
      `/courses/${seedId('crs_ia_1')}?include=modules,lessons`,
      est1Token,
    );
    expect(res.status).toBe(200);
    const raw = await res.text();

    // Las preguntas sí llegan: la pantalla tiene que poder mostrarlas.
    expect(raw).toContain('¿Qué es el aprendizaje supervisado?');
    expect(raw).toContain('Modelos entrenados con datos etiquetados');

    // La clave, no.
    expect(raw).not.toContain('answerIndex');
    expect(raw).not.toContain('answerText');
    expect(raw).not.toContain('answer_index');
    expect(raw).not.toContain('datos de entrenamiento');
  });

  it('tampoco para el LXD que puede editar el curso', async () => {
    // Un LXD edita la clave desde el editor de lecciones, no leyéndola del
    // mismo endpoint por el que la ve un estudiante.
    const res = await req(
      `/courses/${seedId('crs_ia_1')}?include=modules,lessons`,
      lxdToken,
    );
    const raw = await res.text();
    expect(raw).not.toContain('answerIndex');
  });
});

describe('POST /lessons/:id/quiz-attempt', () => {
  it('todo correcto → 100 y aprobado', async () => {
    const res = await attempt(TODO_BIEN, est1Token);
    expect(res.status).toBe(200);
    const b = await body<{
      score: number;
      passed: boolean;
      correctCount: number;
      totalQuestions: number;
    }>(res);

    // Las 4 se corrigen, la de ordenar incluida.
    expect(b.totalQuestions).toBe(4);
    expect(b.correctCount).toBe(4);
    expect(b.score).toBe(100);
    expect(b.passed).toBe(true);
  });

  it('todo incorrecto → 0 y reprobado', async () => {
    const res = await attempt({ [Q1]: 2, [Q2]: 1, [Q3]: 'cualquier cosa' }, est1Token);
    const b = await body<{ score: number; passed: boolean }>(res);
    expect(b.score).toBe(0);
    expect(b.passed).toBe(false);
  });

  it('la respuesta de texto tolera tildes, mayúsculas y espacios de más', async () => {
    // Quien escribe "Datos De Entrenamiento" no está equivocado.
    const res = await attempt(
      { ...TODO_BIEN, [Q3]: '  Datos De Entrenamíento  ' },
      est1Token,
    );
    const b = await body<{ correctness: Record<string, boolean> }>(res);
    expect(b.correctness[Q3]).toBe(true);
  });

  it('dice QUÉ preguntas estuvieron mal, pero no cuál era la respuesta', async () => {
    const res = await attempt({ [Q1]: 2, [Q2]: 0 }, est1Token);
    const raw = await res.text();
    const b = JSON.parse(raw) as { correctness: Record<string, boolean> };

    // Retroalimentación legítima.
    expect(b.correctness[Q1]).toBe(false);
    expect(b.correctness[Q2]).toBe(true);

    // Pero sin la clave: si la devolviera, bastaría mandar un intento en
    // blanco para obtener todas las respuestas correctas.
    expect(raw).not.toContain('datos de entrenamiento');
    expect(raw).not.toContain('answerIndex');
  });

  it('una pregunta sin responder cuenta como incorrecta, no rompe', async () => {
    const res = await attempt({ [Q1]: 0 }, est1Token);
    expect(res.status).toBe(200);
    const b = await body<{ correctCount: number }>(res);
    expect(b.correctCount).toBe(1);
  });

  it('guarda el intento con la nota que calculó el servidor', async () => {
    await attempt(TODO_BIEN, est1Token);
    const [row] = await sql<{ score: number; passed: boolean }[]>`
      select score, passed from quiz_attempts
       where lesson_id = ${QUIZ} order by attempted_at desc limit 1
    `;
    expect(row!.score).toBe(100);
    expect(row!.passed).toBe(true);
  });

  it('un estudiante SIN acceso al curso recibe 404', async () => {
    const res = await attempt({ [Q1]: 0 }, est3Token);
    expect(res.status).toBe(404);
  });

  it('un LXD no resuelve quizzes', async () => {
    const res = await attempt({ [Q1]: 0 }, lxdToken);
    expect(res.status).toBe(403);
  });

  it('sin sesión, tampoco', async () => {
    const res = await app.request(
      `/lessons/${QUIZ}/quiz-attempt`,
      json({ answers: { [Q1]: 0 } }),
    );
    expect(res.status).toBe(401);
  });

  it('el tipo de respuesta tiene que corresponder a la pregunta', async () => {
    // Un texto donde va un índice no es "casi correcto": es incorrecto.
    const res = await attempt({ [Q1]: '0', [Q2]: 0 }, est1Token);
    const b = await body<{ correctness: Record<string, boolean> }>(res);
    expect(b.correctness[Q1]).toBe(false);
  });

  it('una lección que no es quiz responde 409, no una nota de 0', async () => {
    // Un 0 haría parecer que la persona falló todo, cuando el problema es que
    // esa lección no se califica. `lia3` es un PDF.
    const res = await req(
      `/lessons/${seedId('lia3')}/quiz-attempt`,
      est1Token,
      json({ answers: {} }),
    );
    expect(res.status).toBe(409);
  });

  it('una ENCUESTA no se califica: 409, no un intento reprobado', async () => {
    // Una encuesta no tiene respuesta correcta. Calificarla dejaría un intento
    // con 0 y `passed: false` en el historial de quien solo dio su opinión.
    const res = await req(
      `/lessons/${seedId('lia6')}/quiz-attempt`,
      est1Token,
      json({ answers: {} }),
    );
    expect(res.status).toBe(409);

    const [row] = await sql<{ n: string }[]>`
      select count(*) as n from quiz_attempts where lesson_id = ${seedId('lia6')}
    `;
    expect(Number(row!.n)).toBe(0);
  });

  describe('preguntas de ordenar', () => {
    // Su clave es el orden en que están guardadas las opciones, y el cliente
    // manda los elementos unidos por `|`. Antes devolvía siempre `false`, así
    // que quien ordenaba bien igual perdía la pregunta.
    it('el orden correcto cuenta como correcta', async () => {
      const res = await attempt({ [Q4]: ORDEN_CORRECTO }, est1Token);
      const b = await body<{ correctness: Record<string, boolean> }>(res);
      expect(b.correctness[Q4]).toBe(true);
    });

    it('un orden distinto cuenta como incorrecta', async () => {
      const invertido = ORDEN_CORRECTO.split('|').reverse().join('|');
      const res = await attempt({ [Q4]: invertido }, est1Token);
      const b = await body<{ correctness: Record<string, boolean> }>(res);
      expect(b.correctness[Q4]).toBe(false);
    });

    it('otro separador no cuela como respuesta', async () => {
      const res = await attempt({ [Q4]: ORDEN_CORRECTO.replaceAll('|', ',') }, est1Token);
      const b = await body<{ correctness: Record<string, boolean> }>(res);
      expect(b.correctness[Q4]).toBe(false);
    });

    it('la respuesta correcta tampoco sale en el resultado', async () => {
      const res = await attempt({ [Q4]: 'cualquier cosa' }, est1Token);
      const raw = await res.text();
      expect(raw).not.toContain('Recolectar datos');
    });
  });
});
