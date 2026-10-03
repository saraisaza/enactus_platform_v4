import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { sql as drizzleSql } from 'drizzle-orm';
import { PgDialect } from 'drizzle-orm/pg-core';
import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { claveDeTerminoSql } from '../src/db/schema';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Glosario de los cursos.
 *
 * Lo que más importa probar acá es lo que la pantalla no puede garantizar:
 * que una palabra no se repita en el curso aunque cambien tildes o
 * mayúsculas, que un término no marque lecciones de otro módulo ni
 * relacionados de otro curso, que un PATCH parcial no borre lo que no mandó,
 * y que el repaso sea de cada estudiante y de nadie más.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let lxdToken = ''; // lxd1 — creó crs_ia_1
let otroLxdToken = ''; // lxd2 — creó crs_agua_1
let adminToken = '';
let est1Token = ''; // lab_ia: ve crs_ia_1
let sinAccesoToken = ''; // est3: lab_agua y lab_agricultura, no ve crs_ia_1
let est1Id = '';

const CURSO = seedId('crs_ia_1');
const OTRO_CURSO = seedId('crs_agua_1');
const MOD1 = seedId('mia1');
const MOD2 = seedId('mia2');
const MOD_AGUA = seedId('mag1');
const LEC1 = seedId('lia1'); // módulo 1
const LEC2 = seedId('lia2'); // módulo 1
const LEC_MOD2 = seedId('lia4'); // módulo 2
const IA = seedId('glo_ia');
const MODELO = seedId('glo_modelo');
const DATOS = seedId('glo_datos');
const SUPERVISADO = seedId('glo_supervisado');
const SESGO = seedId('glo_sesgo');

type Termino = {
  id: string;
  courseId: string;
  moduleId: string;
  orderIndex: number;
  word: string;
  shortDefinition: string;
  explanation: string;
  example: string;
  imageS3Key: string | null;
  lessonIds: string[];
  relatedTermIds: string[];
};
type Glosario = { terms: Termino[]; reviews: Record<string, string> };
type Error = { error: { code: string; message: string; details?: Record<string, unknown> } };

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const post = (path: string, token: string, payload: unknown) =>
  req(path, token, json(payload));
const put = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PUT' });
const patch = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PATCH' });
const del = (path: string, token: string) => req(path, token, { method: 'DELETE' });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

const glosario = async (token: string, courseId = CURSO) =>
  body<Glosario>(await req(`/courses/${courseId}/glossary`, token));

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  otroLxdToken = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  const est1 = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  est1Token = est1.accessToken;
  est1Id = est1.userId;
  sinAccesoToken = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------
// Lectura
// ---------------------------------------------------------------------------

describe('GET /courses/:id/glossary', () => {
  it('devuelve los términos por módulo y en el orden del LXD, con lecciones y relacionados', async () => {
    const res = await req(`/courses/${CURSO}/glossary`, lxdToken);
    expect(res.status).toBe(200);
    const { terms } = await body<Glosario>(res);

    expect(terms.map((t) => t.id)).toEqual([IA, MODELO, DATOS, SUPERVISADO, SESGO]);
    const modelo = terms.find((t) => t.id === MODELO)!;
    expect(modelo).toMatchObject({
      courseId: CURSO,
      moduleId: MOD1,
      orderIndex: 2,
      word: 'Modelo',
      imageS3Key: null,
      lessonIds: [LEC1, LEC2],
      relatedTermIds: [DATOS],
    });
    // La clave de comparación es cosa de la base: no viaja.
    expect(modelo).not.toHaveProperty('wordKey');
  });

  it('a un estudiante le trae SU repaso, y a nadie más el de él', async () => {
    const propio = await glosario(est1Token);
    expect(propio.terms).toHaveLength(5);
    expect(propio.reviews).toEqual({ [IA]: 'known', [SESGO]: 'review' });

    const delLxd = await glosario(lxdToken);
    expect(delLxd.reviews).toEqual({});
  });

  it('un estudiante sin acceso al curso recibe 404, no un glosario vacío', async () => {
    const res = await req(`/courses/${CURSO}/glossary`, sinAccesoToken);
    expect(res.status).toBe(404);
  });

  it('un curso sin términos devuelve listas vacías', async () => {
    const res = await req(`/courses/${OTRO_CURSO}/glossary`, otroLxdToken);
    expect(res.status).toBe(200);
    expect(await body<Glosario>(res)).toEqual({ terms: [], reviews: {} });
  });
});

// ---------------------------------------------------------------------------
// La clave de comparación, igual en la base y en el cliente
// ---------------------------------------------------------------------------

describe('clave de comparación de una palabra', () => {
  // El mismo archivo lo lee `test/glosario_modelo_test.dart` contra
  // `claveDeTermino`. Si un lado cambia la regla y el otro no, el editor
  // avisaría de un duplicado distinto del que la base rechaza.
  const { casos } = JSON.parse(
    readFileSync(resolve(__dirname, '../../test/fixtures/claves_glosario.json'), 'utf8'),
  ) as { casos: [string, string][] };

  it.each(casos)('%j → %j', async (palabra, esperada) => {
    const consulta = new PgDialect().sqlToQuery(
      drizzleSql`select ${claveDeTerminoSql(drizzleSql`${palabra}::text`)} as clave`,
    );
    const [fila] = await sql.unsafe<{ clave: string }[]>(consulta.sql, consulta.params as string[]);
    expect(fila!.clave).toBe(esperada);
  });
});

// ---------------------------------------------------------------------------
// Crear
// ---------------------------------------------------------------------------

describe('POST /modules/:id/glossary-terms', () => {
  it('el LXD del curso crea un término al final de su módulo', async () => {
    const res = await post(`/modules/${MOD2}/glossary-terms`, lxdToken, {
      word: 'Precisión',
      shortDefinition: 'Proporción de predicciones correctas de un modelo.',
      lessonIds: [LEC_MOD2, LEC_MOD2],
      relatedTermIds: [MODELO],
    });
    expect(res.status).toBe(201);
    const creado = await body<Termino>(res);
    expect(creado).toMatchObject({
      courseId: CURSO,
      moduleId: MOD2,
      orderIndex: 2,
      word: 'Precisión',
      explanation: '',
      example: '',
      imageS3Key: null,
      // Repetido en el pedido, una sola vez guardado.
      lessonIds: [LEC_MOD2],
      relatedTermIds: [MODELO],
    });
  });

  it('otro LXD no puede escribir en un curso ajeno', async () => {
    const res = await post(`/modules/${MOD1}/glossary-terms`, otroLxdToken, {
      word: 'Intruso',
      shortDefinition: 'No debería quedar.',
    });
    expect(res.status).toBe(403);
  });

  it('un estudiante no puede crear términos', async () => {
    const res = await post(`/modules/${MOD1}/glossary-terms`, est1Token, {
      word: 'Intruso',
      shortDefinition: 'No debería quedar.',
    });
    expect(res.status).toBe(403);
  });

  it('palabra y definición corta son obligatorias', async () => {
    const res = await post(`/modules/${MOD1}/glossary-terms`, lxdToken, {
      word: '   ',
      shortDefinition: '',
    });
    expect(res.status).toBe(400);
    const { error } = await body<Error>(res);
    const campos = (error.details as unknown as { field: string }[]).map((d) => d.field);
    expect(campos).toEqual(expect.arrayContaining(['word', 'shortDefinition']));
  });

  it('la imagen tiene que ser un archivo subido desde el editor', async () => {
    const res = await post(`/modules/${MOD1}/glossary-terms`, lxdToken, {
      word: 'Con imagen ajena',
      shortDefinition: 'Apunta a un adjunto de otra persona.',
      imageS3Key: 'submissions/de-otra-persona.pdf',
    });
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// Duplicados
// ---------------------------------------------------------------------------

describe('una palabra no se repite dentro del curso', () => {
  it.each([
    ['la misma, en otro módulo', 'Inteligencia artificial'],
    ['en mayúsculas', 'INTELIGENCIA ARTIFICIAL'],
    ['con tildes distintas y espacios de más', '  Intéligencia    artificiál '],
  ])('%s → 409 nombrando dónde está', async (_caso, word) => {
    const res = await post(`/modules/${MOD2}/glossary-terms`, lxdToken, {
      word,
      shortDefinition: 'Repetida.',
    });
    expect(res.status).toBe(409);
    const { error } = await body<Error>(res);
    expect(error.message).toContain('«Inteligencia artificial»');
    expect(error.message).toContain('Módulo 1: Fundamentos');
    expect(error.details).toMatchObject({ field: 'word', existingTermId: IA });
  });

  it('la ñ cuenta: «año» y «ano» son términos distintos', async () => {
    const año = await post(`/modules/${MOD2}/glossary-terms`, lxdToken, {
      word: 'Año base',
      shortDefinition: 'Año contra el que se compara.',
    });
    const ano = await post(`/modules/${MOD2}/glossary-terms`, lxdToken, {
      word: 'Ano base',
      shortDefinition: 'Solo para probar la regla.',
    });
    expect(año.status).toBe(201);
    expect(ano.status).toBe(201);
    await del(`/glossary-terms/${(await body<Termino>(año)).id}`, lxdToken);
    await del(`/glossary-terms/${(await body<Termino>(ano)).id}`, lxdToken);
  });

  it('la misma palabra en OTRO curso sí se puede', async () => {
    const res = await post(`/modules/${MOD_AGUA}/glossary-terms`, otroLxdToken, {
      word: 'Modelo',
      shortDefinition: 'Representación simplificada de un sistema hídrico.',
    });
    expect(res.status).toBe(201);
  });

  it('renombrar a una palabra que ya está → 409; cambiar solo mayúsculas de la propia → 200', async () => {
    const choque = await patch(`/glossary-terms/${MODELO}`, lxdToken, { word: 'sesgo' });
    expect(choque.status).toBe(409);

    const propia = await patch(`/glossary-terms/${MODELO}`, lxdToken, { word: 'MODELO' });
    expect(propia.status).toBe(200);
    await patch(`/glossary-terms/${MODELO}`, lxdToken, { word: 'Modelo' });
  });

  it('la base lo impide aunque la API se equivoque', async () => {
    await expect(sql`
      insert into glossary_terms (course_id, module_id, order_index, word, short_definition)
      values (${CURSO}, ${MOD2}, 99, ${'datos   DE entrenamiento'}, ${'x'})
    `).rejects.toMatchObject({ constraint_name: 'glossary_terms_course_word_unique' });
  });

  it('la base no deja un término «en» un curso que no es el de su módulo', async () => {
    await expect(sql`
      insert into glossary_terms (course_id, module_id, order_index, word, short_definition)
      values (${OTRO_CURSO}, ${MOD1}, 99, ${'Fuera de lugar'}, ${'x'})
    `).rejects.toMatchObject({ constraint_name: 'glossary_terms_module_course_fk' });
  });
});

// ---------------------------------------------------------------------------
// Lecciones y relacionados
// ---------------------------------------------------------------------------

describe('lecciones y relacionados', () => {
  it('una lección de otro módulo → 409 diciendo cuál', async () => {
    const res = await patch(`/glossary-terms/${MODELO}`, lxdToken, {
      lessonIds: [LEC1, LEC_MOD2],
    });
    expect(res.status).toBe(409);
    expect((await body<Error>(res)).error.details).toMatchObject({
      field: 'lessonIds',
      lessons: [LEC_MOD2],
    });
  });

  it('un relacionado de otro curso → 409', async () => {
    const [ajeno] = await sql<{ id: string }[]>`
      select id from glossary_terms where course_id = ${OTRO_CURSO} limit 1
    `;
    const res = await patch(`/glossary-terms/${MODELO}`, lxdToken, {
      relatedTermIds: [ajeno!.id],
    });
    expect(res.status).toBe(409);
    expect((await body<Error>(res)).error.details).toMatchObject({
      field: 'relatedTermIds',
    });
  });

  it('un término no puede ser relacionado de sí mismo', async () => {
    const res = await patch(`/glossary-terms/${MODELO}`, lxdToken, {
      relatedTermIds: [MODELO],
    });
    expect(res.status).toBe(409);
  });

  it('un relacionado de OTRO módulo del mismo curso sí vale', async () => {
    const res = await patch(`/glossary-terms/${MODELO}`, lxdToken, {
      relatedTermIds: [SESGO, DATOS],
    });
    expect(res.status).toBe(200);
    // En el orden del glosario, no en el del pedido.
    expect((await body<Termino>(res)).relatedTermIds).toEqual([DATOS, SESGO]);
    await patch(`/glossary-terms/${MODELO}`, lxdToken, { relatedTermIds: [DATOS] });
  });
});

// ---------------------------------------------------------------------------
// Editar y borrar
// ---------------------------------------------------------------------------

describe('PATCH /glossary-terms/:id', () => {
  it('cambiar un campo NO borra los demás', async () => {
    // En zod 4 `.partial()` sigue aplicando los `.default()`: sin cuidarlo,
    // este PATCH vaciaba la explicación, el ejemplo y las listas.
    const res = await patch(`/glossary-terms/${IA}`, lxdToken, {
      shortDefinition: 'Sistemas que aprenden de datos para hacer tareas humanas.',
    });
    expect(res.status).toBe(200);
    const ia = await body<Termino>(res);
    expect(ia.shortDefinition).toBe('Sistemas que aprenden de datos para hacer tareas humanas.');
    expect(ia.explanation).toContain('No piensa como una persona');
    expect(ia.example).toContain('plagas');
    expect(ia.lessonIds).toEqual([LEC1]);
    expect(ia.relatedTermIds).toEqual([MODELO, DATOS]);
  });

  it('guarda y quita la imagen', async () => {
    const con = await patch(`/glossary-terms/${DATOS}`, lxdToken, {
      imageS3Key: 'glossary-images/datos.png',
    });
    expect((await body<Termino>(con)).imageS3Key).toBe('glossary-images/datos.png');

    const sin = await patch(`/glossary-terms/${DATOS}`, lxdToken, { imageS3Key: null });
    expect((await body<Termino>(sin)).imageS3Key).toBeNull();
  });

  it('otro LXD no puede editarlo', async () => {
    const res = await patch(`/glossary-terms/${IA}`, otroLxdToken, { word: 'Hackeado' });
    expect(res.status).toBe(403);
  });

  it('un id que no existe → 404', async () => {
    const res = await patch(`/glossary-terms/${seedId('no-existe')}`, adminToken, {
      word: 'Nada',
    });
    expect(res.status).toBe(404);
  });
});

describe('PUT /modules/:id/glossary-terms/order', () => {
  it('reordena el módulo entero', async () => {
    const res = await put(`/modules/${MOD1}/glossary-terms/order`, lxdToken, {
      orderedIds: [SUPERVISADO, IA, MODELO, DATOS],
    });
    expect(res.status).toBe(200);
    const terms = await body<Termino[]>(res);
    expect(terms.map((t) => [t.id, t.orderIndex])).toEqual([
      [SUPERVISADO, 1],
      [IA, 2],
      [MODELO, 3],
      [DATOS, 4],
    ]);
    await put(`/modules/${MOD1}/glossary-terms/order`, lxdToken, {
      orderedIds: [IA, MODELO, DATOS, SUPERVISADO],
    });
  });

  it('una lista incompleta, con un término ajeno o con uno repetido → 409', async () => {
    for (const orderedIds of [
      [IA, MODELO, DATOS],
      [IA, MODELO, DATOS, SUPERVISADO, SESGO],
      [IA, MODELO, DATOS, DATOS],
    ]) {
      const res = await put(`/modules/${MOD1}/glossary-terms/order`, lxdToken, { orderedIds });
      expect(res.status).toBe(409);
    }
  });
});

describe('DELETE /glossary-terms/:id', () => {
  it('borra el término, lo saca de los relacionados ajenos y renumera el módulo', async () => {
    const creado = await body<Termino>(
      await post(`/modules/${MOD1}/glossary-terms`, lxdToken, {
        word: 'Algoritmo',
        shortDefinition: 'Secuencia de pasos para resolver un problema.',
      }),
    );
    await patch(`/glossary-terms/${SUPERVISADO}`, lxdToken, {
      relatedTermIds: [DATOS, creado.id],
    });
    // Para que el borrado tenga que renumerar, que no sea el último.
    await put(`/modules/${MOD1}/glossary-terms/order`, lxdToken, {
      orderedIds: [IA, creado.id, MODELO, DATOS, SUPERVISADO],
    });

    const res = await del(`/glossary-terms/${creado.id}`, lxdToken);
    expect(res.status).toBe(204);

    const { terms } = await glosario(lxdToken);
    const mod1 = terms.filter((t) => t.moduleId === MOD1);
    expect(mod1.map((t) => [t.id, t.orderIndex])).toEqual([
      [IA, 1],
      [MODELO, 2],
      [DATOS, 3],
      [SUPERVISADO, 4],
    ]);
    expect(terms.find((t) => t.id === SUPERVISADO)!.relatedTermIds).toEqual([DATOS]);
  });
});

// ---------------------------------------------------------------------------
// Repaso
// ---------------------------------------------------------------------------

describe('PUT /glossary-terms/:id/review', () => {
  it('el estudiante marca y cambia de opinión; se guarda lo último', async () => {
    let res = await put(`/glossary-terms/${MODELO}/review`, est1Token, { status: 'review' });
    expect(res.status).toBe(200);
    expect(await body(res)).toEqual({ termId: MODELO, status: 'review' });

    res = await put(`/glossary-terms/${MODELO}/review`, est1Token, { status: 'known' });
    expect(res.status).toBe(200);

    expect((await glosario(est1Token)).reviews[MODELO]).toBe('known');
    const filas = await sql`
      select 1 from glossary_reviews where student_id = ${est1Id} and term_id = ${MODELO}
    `;
    expect(filas).toHaveLength(1);
  });

  it('un estado que no es «known» ni «review» → 400', async () => {
    const res = await put(`/glossary-terms/${MODELO}/review`, est1Token, { status: 'tal vez' });
    expect(res.status).toBe(400);
  });

  it('quien no es estudiante no guarda repaso', async () => {
    const res = await put(`/glossary-terms/${MODELO}/review`, lxdToken, { status: 'known' });
    expect(res.status).toBe(403);
  });

  it('un estudiante sin acceso al curso → 404', async () => {
    const res = await put(`/glossary-terms/${MODELO}/review`, sinAccesoToken, {
      status: 'known',
    });
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// Imagen
// ---------------------------------------------------------------------------

/**
 * Se comprueba la AUTORIZACIÓN, no la firma, igual que en `files.test.ts`:
 * con bucket configurado es un 200, sin él un 503. Lo que nunca puede ser es
 * 403 o 404 para quien sí puede, ni 200/503 para quien no.
 */
describe('imagen de un término', () => {
  it('el LXD puede pedir URL de subida con propósito glossary_image', async () => {
    const res = await post('/files/upload-url', lxdToken, {
      purpose: 'glossary_image',
      fileName: 'red-neuronal.png',
      contentType: 'image/png',
      sizeBytes: 2048,
    });
    expect([200, 503]).toContain(res.status);
    if (res.status === 503) return; // entorno sin S3
    expect((await body<{ key: string }>(res)).key).toMatch(/^glossary-images\//);
  });

  it('un estudiante no puede subir imágenes de glosario', async () => {
    const res = await post('/files/upload-url', est1Token, {
      purpose: 'glossary_image',
      fileName: 'x.png',
      contentType: 'image/png',
      sizeBytes: 10,
    });
    expect(res.status).toBe(403);
  });

  it('la ve quien ve el curso, y nadie más', async () => {
    const key = 'glossary-images/sesgo.png';
    await patch(`/glossary-terms/${SESGO}`, lxdToken, { imageS3Key: key });

    const propio = await post('/files/download-url', est1Token, { key });
    expect([200, 503]).toContain(propio.status);

    const ajeno = await post('/files/download-url', sinAccesoToken, { key });
    expect(ajeno.status).toBe(404);

    await patch(`/glossary-terms/${SESGO}`, lxdToken, { imageS3Key: null });
  });
});

// ---------------------------------------------------------------------------
// Cascadas
// ---------------------------------------------------------------------------

describe('al borrar el módulo', () => {
  it('sus términos se van con él, y con ellos el repaso', async () => {
    const res = await del(`/modules/${MOD2}`, lxdToken);
    expect(res.status).toBe(204);

    const { terms, reviews } = await glosario(est1Token);
    expect(terms.some((t) => t.moduleId === MOD2)).toBe(false);
    expect(reviews[SESGO]).toBeUndefined();
  });
});
