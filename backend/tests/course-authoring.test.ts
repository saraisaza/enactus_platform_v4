import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Autoría de contenido: lo que el constructor de cursos escribe.
 *
 * Son los endpoints que le faltaban al portal LXD para poder migrarse —quiz,
 * actividad, categorización, portada y recurso descargable— y todos comparten
 * la misma forma: reemplazan un conjunto entero en vez de parchear elemento por
 * elemento, porque el editor manda el formulario completo.
 *
 * Lo que más se prueba acá no es el camino feliz sino el borde: que una clave
 * de respuestas mal armada NO se guarde a medias, que la clave solo salga por
 * el endpoint de autoría, y que un código de catálogo inexistente responda con
 * cuál está mal en vez de reventar contra una clave foránea.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let lxdToken = ''; // lxd1 — creó crs_ia_1
let otroLxdToken = ''; // lxd2 — creó crs_agua_1, no toca crs_ia_1
let adminToken = '';
let est1Token = '';

const CURSO = seedId('crs_ia_1');
const QUIZ = seedId('lia4'); // type: quiz
const ACTIVIDAD = seedId('lia5'); // type: activity
const ENCUESTA = seedId('lia6'); // type: survey
const PDF = seedId('lia3'); // type: pdf

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const put = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PUT' });

const patch = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PATCH' });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

type Problema = { question: number; problem: string };
type Pregunta = {
  id: string;
  kind: string;
  question: string;
  options: string[];
  answerIndex: number | null;
  answerText: string | null;
};

/** Restaura el quiz sembrado para que cada bloque parta de lo mismo. */
const QUIZ_ORIGINAL = [
  {
    kind: 'multiple',
    question: '¿Qué es el aprendizaje supervisado?',
    options: [
      'Modelos entrenados con datos etiquetados',
      'Modelos sin datos',
      'Un tipo de hardware',
    ],
    answerIndex: 0,
  },
  {
    kind: 'truefalse',
    question: 'La IA puede funcionar sin datos.',
    answerIndex: 0,
  },
  {
    kind: 'short',
    question: '¿Cómo se llaman los datos usados para entrenar un modelo?',
    answerText: 'datos de entrenamiento',
  },
  {
    kind: 'order',
    question: 'Ordena las etapas de un proyecto de IA:',
    options: [
      'Recolectar datos',
      'Entrenar el modelo',
      'Evaluar resultados',
      'Desplegar la solución',
    ],
  },
];

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  otroLxdToken = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

describe('GET /lessons/:id/quiz — la única lectura con clave', () => {
  it('el LXD que puede editar el curso ve answerIndex y answerText', async () => {
    // Sin esto, abrir una lección hecha en el constructor mostraría las
    // respuestas en blanco y el primer guardado borraría la clave.
    const res = await req(`/lessons/${QUIZ}/quiz`, lxdToken);
    expect(res.status).toBe(200);
    const b = await body<{ questions: Pregunta[] }>(res);

    expect(b.questions).toHaveLength(4);
    expect(b.questions[0]!.answerIndex).toBe(0);
    expect(b.questions[2]!.answerText).toBe('datos de entrenamiento');
    // El orden correcto de la pregunta `order` viaja en sus opciones.
    expect(b.questions[3]!.options[0]).toBe('Recolectar datos');
  });

  it('un administrador también', async () => {
    const res = await req(`/lessons/${QUIZ}/quiz`, adminToken);
    expect(res.status).toBe(200);
  });

  it('un estudiante NO: la clave no es suya', async () => {
    const res = await req(`/lessons/${QUIZ}/quiz`, est1Token);
    expect(res.status).toBe(403);
    expect(await res.text()).not.toContain('datos de entrenamiento');
  });

  it('un LXD ajeno al curso tampoco', async () => {
    const res = await req(`/lessons/${QUIZ}/quiz`, otroLxdToken);
    expect(res.status).toBe(403);
  });

  it('sin sesión, 401', async () => {
    const res = await app.request(`/lessons/${QUIZ}/quiz`);
    expect(res.status).toBe(401);
  });
});

describe('PUT /lessons/:id/quiz — validación antes de escribir', () => {
  afterAll(async () => {
    // Deja el quiz como estaba: las otras suites leen este mismo curso.
    await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions: QUIZ_ORIGINAL });
  });

  const rechaza = async (questions: unknown[]): Promise<Problema[]> => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { problems: Problema[] } } }>(res);
    return b.error.details.problems;
  };

  it('una de selección múltiple sin marcar la correcta no se guarda', async () => {
    const problems = await rechaza([
      { kind: 'multiple', question: '¿Cuál?', options: ['A', 'B'] },
    ]);
    expect(problems).toHaveLength(1);
    expect(problems[0]!.question).toBe(1);
    expect(problems[0]!.problem).toContain('correcta');
  });

  it('un índice de respuesta fuera de las opciones tampoco', async () => {
    const problems = await rechaza([
      { kind: 'multiple', question: '¿Cuál?', options: ['A', 'B'], answerIndex: 5 },
    ]);
    expect(problems).toHaveLength(1);
  });

  it('las opciones vacías se RECHAZAN, no se filtran', async () => {
    // Filtrarlas correría los índices: la respuesta correcta pasaría a ser
    // otra opción sin que nadie lo viera.
    const problems = await rechaza([
      {
        kind: 'multiple',
        question: '¿Cuál?',
        options: ['A', '', 'C'],
        answerIndex: 2,
      },
    ]);
    expect(problems[0]!.problem).toContain('sin texto');
  });

  it('verdadero/falso solo acepta 0 o 1', async () => {
    const problems = await rechaza([
      { kind: 'truefalse', question: '¿Sí o no?', answerIndex: 7 },
    ]);
    expect(problems[0]!.problem).toContain('Verdadero');
  });

  it('respuesta corta sin clave, no', async () => {
    const problems = await rechaza([{ kind: 'short', question: '¿Cómo se llama?' }]);
    expect(problems[0]!.problem).toContain('respuesta correcta');
  });

  it('ordenar con un solo elemento, tampoco', async () => {
    const problems = await rechaza([
      { kind: 'order', question: 'Ordená:', options: ['Único'] },
    ]);
    expect(problems[0]!.problem).toContain('dos elementos');
  });

  it('devuelve TODOS los problemas, no solo el primero', async () => {
    // Quien arma un quiz de diez preguntas prefiere verlos juntos.
    const problems = await rechaza([
      { kind: 'short', question: 'Una' },
      { kind: 'multiple', question: 'Dos', options: ['A', 'B'] },
      { kind: 'truefalse', question: 'Tres' },
    ]);
    expect(problems.map((p) => p.question)).toEqual([1, 2, 3]);
  });

  it('un enunciado vacío es 400 del esquema, no 409', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [{ kind: 'short', question: '   ', answerText: 'x' }],
    });
    expect(res.status).toBe(400);
  });

  it('cuando rechaza, el quiz anterior sigue intacto', async () => {
    await rechaza([{ kind: 'short', question: 'Sin clave' }]);
    const res = await req(`/lessons/${QUIZ}/quiz`, lxdToken);
    const b = await body<{ questions: Pregunta[] }>(res);
    expect(b.questions).toHaveLength(4);
  });
});

describe('PUT /lessons/:id/quiz — reemplazo', () => {
  afterAll(async () => {
    await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions: QUIZ_ORIGINAL });
  });

  it('reemplaza el conjunto entero, no agrega', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [
        {
          kind: 'multiple',
          question: '¿Cuál es la capital de Colombia?',
          options: ['Bogotá', 'Medellín'],
          answerIndex: 0,
        },
      ],
    });
    expect(res.status).toBe(200);
    const b = await body<{ questions: Pregunta[] }>(res);
    expect(b.questions).toHaveLength(1);
    expect(b.questions[0]!.question).toContain('capital');
  });

  it('lo que guarda es lo que después se corrige', async () => {
    // El ciclo completo: se escribe la clave y el servidor califica con ella.
    await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [
        {
          kind: 'multiple',
          question: '¿Cuál es la capital de Colombia?',
          options: ['Medellín', 'Bogotá'],
          answerIndex: 1,
        },
      ],
    });
    const guardadas = await body<{ questions: Pregunta[] }>(
      await req(`/lessons/${QUIZ}/quiz`, lxdToken),
    );
    const id = guardadas.questions[0]!.id;

    const bien = await body<{ score: number }>(
      await req(`/lessons/${QUIZ}/quiz-attempt`, est1Token, json({ answers: { [id]: 1 } })),
    );
    expect(bien.score).toBe(100);

    const mal = await body<{ score: number }>(
      await req(`/lessons/${QUIZ}/quiz-attempt`, est1Token, json({ answers: { [id]: 0 } })),
    );
    expect(mal.score).toBe(0);
  });

  it('verdadero/falso no guarda opciones: las dibuja el cliente', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [
        {
          kind: 'truefalse',
          question: 'Colombia tiene dos océanos.',
          options: ['esto', 'se ignora'],
          answerIndex: 0,
        },
      ],
    });
    const b = await body<{ questions: Pregunta[] }>(res);
    expect(b.questions[0]!.options).toEqual([]);
    expect(b.questions[0]!.answerIndex).toBe(0);
  });

  it('cada tipo guarda UNA sola clave, no las dos', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, {
      questions: [
        {
          kind: 'short',
          question: '¿Cómo se llama?',
          answerText: 'respuesta',
          answerIndex: 3,
        },
      ],
    });
    const b = await body<{ questions: Pregunta[] }>(res);
    expect(b.questions[0]!.answerText).toBe('respuesta');
    expect(b.questions[0]!.answerIndex).toBeNull();
  });

  it('un quiz vacío se guarda, pero resolverlo responde 409', async () => {
    // Una lección de quiz a medio construir es válida; darle 0 a quien la
    // abre, no.
    const res = await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions: [] });
    expect(res.status).toBe(200);

    const intento = await req(
      `/lessons/${QUIZ}/quiz-attempt`,
      est1Token,
      json({ answers: {} }),
    );
    expect(intento.status).toBe(409);
  });

  it('los intentos ya resueltos sobreviven al reemplazo', async () => {
    // Guardan su nota calculada en el servidor: siguen siendo un registro
    // válido de lo que pasó, aunque el quiz cambie después.
    const [antes] = await sql<{ n: string }[]>`
      select count(*) as n from quiz_attempts where lesson_id = ${QUIZ}
    `;
    await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions: QUIZ_ORIGINAL });
    const [despues] = await sql<{ n: string }[]>`
      select count(*) as n from quiz_attempts where lesson_id = ${QUIZ}
    `;
    expect(Number(despues!.n)).toBe(Number(antes!.n));
  });

  it('la clave sigue sin salir por la lectura del curso', async () => {
    await put(`/lessons/${QUIZ}/quiz`, lxdToken, { questions: QUIZ_ORIGINAL });
    const res = await req(`/courses/${CURSO}?include=modules,lessons`, est1Token);
    const raw = await res.text();
    expect(raw).toContain('¿Qué es el aprendizaje supervisado?');
    expect(raw).not.toContain('answerIndex');
    expect(raw).not.toContain('datos de entrenamiento');
  });
});

describe('PUT /lessons/:id/quiz — tipo de lección y permisos', () => {
  it('una lección PDF no tiene preguntas: 409', async () => {
    const res = await put(`/lessons/${PDF}/quiz`, lxdToken, { questions: [] });
    expect(res.status).toBe(409);
  });

  it('una encuesta NO acepta clave de respuestas', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [
        { kind: 'short', question: '¿Qué te pareció?', answerText: 'bueno' },
      ],
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { problems: Problema[] } } }>(res);
    expect(b.error.details.problems[0]!.problem).toContain('encuesta');
  });

  it('una encuesta sin clave sí se guarda', async () => {
    const res = await put(`/lessons/${ENCUESTA}/quiz`, lxdToken, {
      questions: [
        { kind: 'short', question: '¿Qué fue lo que más te gustó del curso?' },
        { kind: 'short', question: '¿Qué mejorarías?' },
      ],
    });
    expect(res.status).toBe(200);
    const b = await body<{ questions: Pregunta[] }>(res);
    expect(b.questions).toHaveLength(2);
    expect(b.questions[0]!.answerText).toBeNull();
  });

  it('un LXD ajeno no reescribe el quiz de otro', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, otroLxdToken, { questions: [] });
    expect(res.status).toBe(403);
  });

  it('un estudiante tampoco', async () => {
    const res = await put(`/lessons/${QUIZ}/quiz`, est1Token, { questions: [] });
    expect(res.status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// Actividad
// ---------------------------------------------------------------------------

describe('PUT /lessons/:id/activity', () => {
  const base = {
    description: 'Entregá una propuesta de IA para tu comunidad.',
    deadline: '2026-11-30',
    requiresFile: true,
    requiresText: true,
    maxFiles: 3,
    gradingMode: 'points100',
    allowedTypes: ['pdf', 'document'],
    rubric: [
      { criterion: 'Claridad del problema', points: 30 },
      { criterion: 'Viabilidad técnica', points: 40 },
      { criterion: 'Impacto esperado', points: 30 },
    ],
  };

  it('guarda la configuración y la devuelve completa', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, base);
    expect(res.status).toBe(200);
    const b = await body<typeof base>(res);
    expect(b.maxFiles).toBe(3);
    expect(b.deadline).toBe('2026-11-30');
    expect(b.allowedTypes).toEqual(['pdf', 'document']);
    expect(b.rubric).toHaveLength(3);
  });

  it('el detalle del curso trae la actividad con sus tipos y rúbrica', async () => {
    const res = await req(`/courses/${CURSO}?include=modules,lessons`, est1Token);
    const raw = await res.text();
    expect(raw).toContain('Viabilidad técnica');
    expect(raw).toContain('allowedTypes');
  });

  it('reemplaza la rúbrica entera, no la agrega', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      rubric: [{ criterion: 'Único criterio', points: 100 }],
    });
    const b = await body<{ rubric: { criterion: string }[] }>(res);
    expect(b.rubric).toHaveLength(1);
    expect(b.rubric[0]!.criterion).toBe('Único criterio');
  });

  it('una rúbrica vacía deja la actividad sin criterios', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      rubric: [],
    });
    const b = await body<{ rubric: unknown[] }>(res);
    expect(b.rubric).toEqual([]);
  });

  it('sin fecha límite también vale', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      deadline: null,
    });
    const b = await body<{ deadline: string | null }>(res);
    expect(b.deadline).toBeNull();
  });

  it('tipos repetidos no revientan la clave primaria', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      allowedTypes: ['pdf', 'pdf', 'image'],
    });
    expect(res.status).toBe(200);
    const b = await body<{ allowedTypes: string[] }>(res);
    expect(b.allowedTypes).toEqual(['pdf', 'image']);
  });

  it('sin texto ni archivo no hay nada que entregar: 409', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      requiresFile: false,
      requiresText: false,
    });
    expect(res.status).toBe(409);
  });

  it('maxFiles en 0 es 400 del esquema', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      maxFiles: 0,
    });
    expect(res.status).toBe(400);
  });

  it('una fecha mal formada es 400, no una fila corrupta', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, lxdToken, {
      ...base,
      deadline: '30/11/2026',
    });
    expect(res.status).toBe(400);
  });

  it('una lección de quiz no tiene entregable: 409', async () => {
    const res = await put(`/lessons/${QUIZ}/activity`, lxdToken, base);
    expect(res.status).toBe(409);
  });

  it('un LXD ajeno no la configura', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, otroLxdToken, base);
    expect(res.status).toBe(403);
  });

  it('un estudiante tampoco', async () => {
    const res = await put(`/lessons/${ACTIVIDAD}/activity`, est1Token, base);
    expect(res.status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// Catálogos
// ---------------------------------------------------------------------------

describe('GET /catalogs', () => {
  type Catalogos = {
    competencies: { code: string; name: string }[];
    ods: { code: string; number: number; title: string }[];
  };

  it('devuelve las competencias y los ODS de la base', async () => {
    const res = await req('/catalogs', lxdToken);
    expect(res.status).toBe(200);
    const b = await body<Catalogos>(res);

    expect(b.competencies).toHaveLength(12);
    expect(b.ods).toHaveLength(17);
    expect(b.competencies.map((x) => x.code)).toContain('artificial_intelligence');
    expect(b.ods[5]!.code).toBe('ods_6');
    expect(b.ods[5]!.title).toContain('Agua');
  });

  it('los ODS vienen en su orden numérico, no alfabético', async () => {
    // `ods_10` va después de `ods_9`, no entre `ods_1` y `ods_2`.
    const b = await body<Catalogos>(await req('/catalogs', lxdToken));
    expect(b.ods.map((o) => o.number)).toEqual(
      Array.from({ length: 17 }, (_, i) => i + 1),
    );
  });

  it('los códigos que devuelve son los que acepta PUT /courses/:id/meta', async () => {
    // Si estas dos listas se separaran, el editor ofrecería fichas que el
    // guardado rechaza. Se prueba juntas a propósito.
    const catalogos = await body<Catalogos>(await req('/catalogs', lxdToken));
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      tags: [],
      objectives: [],
      competencies: catalogos.competencies.map((x) => x.code),
      ods: catalogos.ods.map((x) => x.code),
      learningOutcomes: [],
      prerequisiteCourseIds: [],
    });
    expect(res.status).toBe(200);
  });

  it('cualquier rol con sesión los puede leer', async () => {
    expect((await req('/catalogs', est1Token)).status).toBe(200);
  });

  it('sin sesión, no', async () => {
    expect((await app.request('/catalogs')).status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// Categorización del curso
// ---------------------------------------------------------------------------

describe('PUT /courses/:id/meta', () => {
  type Meta = {
    tags: string[];
    objectives: { id: string; category: string | null; text: string }[];
    competencies: string[];
    ods: string[];
    learningOutcomes: string[];
    prerequisiteCourseIds: string[];
  };

  const completo = {
    tags: ['IA', 'Datos'],
    objectives: [
      { category: null, text: 'Comprender los fundamentos de la IA aplicada' },
      { category: 'entrepreneurship', text: 'Identificar oportunidades de IA' },
      { category: 'business', text: 'Estimar el costo de un modelo' },
    ],
    competencies: ['artificial_intelligence', 'innovation'],
    ods: ['ods_4', 'ods_9'],
    learningOutcomes: ['Construye un prototipo con datos reales'],
    prerequisiteCourseIds: [seedId('crs_emprend_1')],
  };

  it('guarda las seis listas y las devuelve', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, completo);
    expect(res.status).toBe(200);
    const b = await body<Meta>(res);

    expect(b.tags).toEqual(['Datos', 'IA']);
    expect(b.objectives).toHaveLength(3);
    expect(b.objectives[1]!.category).toBe('entrepreneurship');
    expect(b.competencies).toEqual(['artificial_intelligence', 'innovation']);
    expect(b.ods).toEqual(['ods_4', 'ods_9']);
    expect(b.learningOutcomes).toEqual(['Construye un prototipo con datos reales']);
    expect(b.prerequisiteCourseIds).toEqual([seedId('crs_emprend_1')]);
  });

  it('el detalle del curso las trae de vuelta', async () => {
    const res = await req(`/courses/${CURSO}`, lxdToken);
    const b = await body<Meta>(res);
    expect(b.tags).toContain('IA');
    expect(b.learningOutcomes).toHaveLength(1);
    expect(b.prerequisiteCourseIds).toHaveLength(1);
  });

  it('conserva el orden en que se escribieron los objetivos', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      objectives: [
        { category: null, text: 'Primero' },
        { category: null, text: 'Segundo' },
        { category: null, text: 'Tercero' },
      ],
    });
    const b = await body<Meta>(res);
    expect(b.objectives.map((o) => o.text)).toEqual(['Primero', 'Segundo', 'Tercero']);
  });

  it('mandar listas vacías borra la categorización', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      tags: [],
      objectives: [],
      competencies: [],
      ods: [],
      learningOutcomes: [],
      prerequisiteCourseIds: [],
    });
    const b = await body<Meta>(res);
    expect(b.tags).toEqual([]);
    expect(b.objectives).toEqual([]);
    expect(b.competencies).toEqual([]);
  });

  it('etiquetas repetidas se deduplican en vez de reventar', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      tags: ['IA', 'IA', 'Datos'],
    });
    expect(res.status).toBe(200);
    const b = await body<Meta>(res);
    expect(b.tags).toEqual(['Datos', 'IA']);
  });

  it('una competencia fuera del catálogo dice CUÁL está mal', async () => {
    // La clave foránea también lo impediría, pero saldría como un 500 sin
    // explicación en vez de nombrar el código.
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      competencies: ['artificial_intelligence', 'telepatia'],
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { competencies: string[] } } }>(res);
    expect(b.error.details.competencies).toEqual(['telepatia']);
  });

  it('un ODS inexistente, igual', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      ods: ['ods_99'],
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { ods: string[] } } }>(res);
    expect(b.error.details.ods).toEqual(['ods_99']);
  });

  it('un curso no puede ser prerrequisito de sí mismo', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      prerequisiteCourseIds: [CURSO],
    });
    expect(res.status).toBe(409);
  });

  it('un prerrequisito que no existe, 409', async () => {
    const res = await put(`/courses/${CURSO}/meta`, lxdToken, {
      ...completo,
      prerequisiteCourseIds: ['11111111-1111-4111-8111-111111111111'],
    });
    expect(res.status).toBe(409);
  });

  it('cuando rechaza, no escribe nada', async () => {
    await put(`/courses/${CURSO}/meta`, lxdToken, completo);
    await put(`/courses/${CURSO}/meta`, lxdToken, {
      tags: ['Solo esta'],
      objectives: [],
      competencies: ['inventada'],
      ods: [],
      learningOutcomes: [],
      prerequisiteCourseIds: [],
    });
    const b = await body<Meta>(await req(`/courses/${CURSO}`, lxdToken));
    expect(b.tags).toEqual(['Datos', 'IA']);
  });

  it('un LXD ajeno no categoriza el curso de otro', async () => {
    const res = await put(`/courses/${CURSO}/meta`, otroLxdToken, completo);
    expect(res.status).toBe(403);
  });

  it('un estudiante tampoco', async () => {
    const res = await put(`/courses/${CURSO}/meta`, est1Token, completo);
    expect(res.status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// Portada, fechas y patrocinio
// ---------------------------------------------------------------------------

describe('PATCH /courses/:id — portada, ventana y patrocinador', () => {
  afterAll(async () => {
    await patch(`/courses/${CURSO}`, lxdToken, {
      openDate: null,
      closeDate: null,
      sponsorCompanyId: null,
      coverS3Key: null,
    });
  });

  it('acepta una portada bajo covers/', async () => {
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      coverS3Key: 'covers/abc-123.png',
    });
    expect(res.status).toBe(200);
    const b = await body<{ coverS3Key: string }>(res);
    expect(b.coverS3Key).toBe('covers/abc-123.png');
  });

  it('rechaza una key de otra carpeta', async () => {
    // Si no, quien edita un curso podría apuntar la portada al adjunto de una
    // entrega ajena y hacer que la API se la firmara.
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      coverS3Key: 'submissions/secreto.pdf',
    });
    expect(res.status).toBe(400);
  });

  it('guarda la ventana de disponibilidad', async () => {
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      openDate: '2026-09-01',
      closeDate: '2026-12-15',
    });
    expect(res.status).toBe(200);
    const b = await body<{ openDate: string; closeDate: string }>(res);
    expect(b.openDate).toBe('2026-09-01');
    expect(b.closeDate).toBe('2026-12-15');
  });

  it('un curso no puede cerrar antes de abrir', async () => {
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      openDate: '2026-12-01',
      closeDate: '2026-09-01',
    });
    expect(res.status).toBe(409);
  });

  it('el parcheo de una sola fecha se valida contra la guardada', async () => {
    // Con apertura en septiembre ya guardada, mandar solo un cierre de agosto
    // tiene que fallar igual.
    await patch(`/courses/${CURSO}`, lxdToken, {
      openDate: '2026-09-01',
      closeDate: '2026-12-15',
    });
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      closeDate: '2026-08-01',
    });
    expect(res.status).toBe(409);
  });

  it('el patrocinador tiene que ser una cuenta de empresa', async () => {
    // La clave foránea apunta a `users`: aceptaría el id de un estudiante y el
    // curso quedaría "patrocinado" por alguien que no patrocina nada.
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      sponsorCompanyId: seedId('est1'),
    });
    expect(res.status).toBe(409);
  });

  it('una empresa real sí', async () => {
    const [empresa] = await sql<{ id: string }[]>`
      select id from users where role = 'company' and deleted_at is null limit 1
    `;
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      sponsorCompanyId: empresa!.id,
    });
    expect(res.status).toBe(200);
    const b = await body<{ sponsorCompanyId: string }>(res);
    expect(b.sponsorCompanyId).toBe(empresa!.id);
  });

  it('quitar el patrocinio también', async () => {
    const res = await patch(`/courses/${CURSO}`, lxdToken, {
      sponsorCompanyId: null,
    });
    expect(res.status).toBe(200);
    const b = await body<{ sponsorCompanyId: string | null }>(res);
    expect(b.sponsorCompanyId).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Recurso descargable y URLs de subida
// ---------------------------------------------------------------------------

describe('POST /lessons/:id/resource', () => {
  const archivo = {
    key: 'lesson-resources/abc-123.pdf',
    fileName: 'material.pdf',
    contentType: 'application/pdf',
    sizeBytes: 120_000,
  };

  it('deja la lección apuntando al archivo subido', async () => {
    const res = await req(`/lessons/${PDF}/resource`, lxdToken, json(archivo));
    expect(res.status).toBe(200);
    const b = await body<{ resourceS3Key: string; resourceFileName: string }>(res);
    expect(b.resourceS3Key).toBe(archivo.key);
    expect(b.resourceFileName).toBe('material.pdf');
  });

  it('rechaza una key de otra carpeta', async () => {
    const res = await req(
      `/lessons/${PDF}/resource`,
      lxdToken,
      json({ ...archivo, key: 'submissions/ajeno.pdf' }),
    );
    expect(res.status).toBe(409);
  });

  it('rechaza un tipo de archivo no permitido', async () => {
    const res = await req(
      `/lessons/${PDF}/resource`,
      lxdToken,
      json({ ...archivo, contentType: 'application/x-msdownload' }),
    );
    expect(res.status).toBe(400);
  });

  it('rechaza un archivo de más de 25 MB', async () => {
    const res = await req(
      `/lessons/${PDF}/resource`,
      lxdToken,
      json({ ...archivo, sizeBytes: 30 * 1024 * 1024 }),
    );
    expect(res.status).toBe(413);
  });

  it('un estudiante no cambia el material de una lección', async () => {
    const res = await req(`/lessons/${PDF}/resource`, est1Token, json(archivo));
    expect(res.status).toBe(403);
  });
});

describe('POST /files/upload-url — propósitos de autoría', () => {
  /**
   * Se comprueba la AUTORIZACIÓN, no la firma: con bucket configurado es un
   * 200, sin credenciales un 503. Lo que nunca puede ser es 403 para quien sí
   * puede subir, ni 200 para quien no.
   */
  const pedir = (purpose: string, token: string) =>
    req(
      '/files/upload-url',
      token,
      json({
        purpose,
        fileName: 'portada.png',
        contentType: 'image/png',
        sizeBytes: 50_000,
      }),
    );

  it('el LXD puede pedir URL para una portada', async () => {
    const res = await pedir('course_cover', lxdToken);
    expect([200, 503]).toContain(res.status);
  });

  it('y para un recurso de lección', async () => {
    const res = await pedir('lesson_resource', lxdToken);
    expect([200, 503]).toContain(res.status);
  });

  it('la key queda bajo covers/', async () => {
    const res = await pedir('course_cover', lxdToken);
    if (res.status === 503) return; // entorno sin S3
    const b = await body<{ key: string }>(res);
    expect(b.key).toMatch(/^covers\//);
  });

  it('un estudiante no sube material de curso', async () => {
    const res = await pedir('course_cover', est1Token);
    expect(res.status).toBe(403);
  });

  it('un propósito inventado es 400', async () => {
    const res = await pedir('lo_que_sea', lxdToken);
    expect(res.status).toBe(400);
  });
});
