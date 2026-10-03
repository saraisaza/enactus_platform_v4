import { and, eq, inArray, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  claveDeTerminoSql,
  courseModules,
  courses,
  glossaryReviews,
  glossaryTermLessons,
  glossaryTermRelated,
  glossaryTerms,
  lessons,
} from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import {
  CONTENT_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { visibleCoursesFilter } from '../services/course-access';
import { loadEditableCourse } from './courses';

/**
 * Glosario de un curso.
 *
 * Cada término pertenece a un módulo y puede marcar las lecciones de ese
 * módulo donde aparece. La palabra no se repite dentro del curso: lo exige la
 * base (`glossary_terms_course_word_unique`, sobre una clave sin tildes ni
 * mayúsculas) y la API lo dice antes, nombrando el módulo donde ya está.
 *
 * Lectura: quien puede ver el curso. Escritura: quien puede editarlo. Repaso:
 * cada estudiante el suyo.
 */

type Db = AppEnv['Variables']['db'];

// ---------------------------------------------------------------------------
// Validación
// ---------------------------------------------------------------------------

/**
 * Los campos, SIN valores por defecto.
 *
 * Es a propósito: en zod 4 `.partial()` sigue aplicando los `.default()`, así
 * que un PATCH que mandara solo la palabra borraría la explicación y el
 * ejemplo. Los vacíos de la creación se ponen en [termCreate].
 */
const termFields = {
  word: z
    .string()
    .trim()
    .min(1, 'La palabra es obligatoria.')
    .max(120, 'La palabra admite hasta 120 caracteres.'),
  shortDefinition: z
    .string()
    .trim()
    .min(1, 'La definición corta es obligatoria.')
    .max(500, 'La definición corta admite hasta 500 caracteres: una o dos frases.'),
  explanation: z
    .string()
    .trim()
    .max(5000, 'La explicación admite hasta 5000 caracteres.'),
  example: z.string().trim().max(2000, 'El ejemplo admite hasta 2000 caracteres.'),

  /**
   * Solo una key bajo `glossary-images/`, que es donde deja el archivo
   * `POST /files/upload-url` con `purpose: glossary_image`. Misma regla que la
   * portada de un curso: sin ella, quien edita podría apuntar la imagen a un
   * adjunto ajeno y hacer que la API se lo firmara a los estudiantes.
   */
  imageS3Key: z
    .string()
    .trim()
    .regex(/^glossary-images\//, 'La imagen tiene que ser un archivo subido desde el editor.')
    .nullable(),
  lessonIds: z.array(z.uuid()).max(200),
  relatedTermIds: z.array(z.uuid()).max(50, 'Un término admite hasta 50 relacionados.'),
};

const termCreate = z.object({
  ...termFields,
  explanation: termFields.explanation.default(''),
  example: termFields.example.default(''),
  imageS3Key: termFields.imageS3Key.optional(),
  lessonIds: termFields.lessonIds.default([]),
  relatedTermIds: termFields.relatedTermIds.default([]),
});

const termUpdate = z.object(termFields).partial();

const reorderBody = z.object({
  orderedIds: z.array(z.uuid()).min(1, 'Hace falta al menos un id.'),
});

const reviewBody = z.object({
  status: z.enum(['known', 'review'], 'El estado tiene que ser «known» o «review».'),
});

// ---------------------------------------------------------------------------
// Lectura
// ---------------------------------------------------------------------------

export const courseGlossaryRoutes = new Hono<AppEnv>();
courseGlossaryRoutes.use('*', requireAuth);

/**
 * El glosario completo del curso, ordenado por módulo y por el orden que le
 * dio el LXD, más el repaso de quien pregunta.
 *
 * Un solo pedido para todo el curso: la pantalla lo necesita entero para
 * resaltar las palabras en el texto de cualquier lección y para que un
 * término relacionado de otro módulo se pueda abrir.
 */
courseGlossaryRoutes.get('/:id/glossary', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const scope = visibleCoursesFilter(user);
  if (!scope) throw notFound('No se encontró el curso.');

  const [course] = await db
    .select({ id: courses.id })
    .from(courses)
    .where(and(eq(courses.id, c.req.param('id')), scope))
    .limit(1);
  // 404 y no 403, igual que `GET /courses/:id`: un 403 confirmaría que existe.
  if (!course) throw notFound('No se encontró el curso.');

  const [terms, reviews] = await Promise.all([
    loadTerms(db, { courseId: course.id }),
    db
      .select({ termId: glossaryReviews.termId, status: glossaryReviews.status })
      .from(glossaryReviews)
      .innerJoin(glossaryTerms, eq(glossaryTerms.id, glossaryReviews.termId))
      .where(
        and(
          eq(glossaryReviews.studentId, user.id),
          eq(glossaryTerms.courseId, course.id),
        ),
      ),
  ]);

  return c.json({
    terms,
    reviews: Object.fromEntries(reviews.map((r) => [r.termId, r.status])),
  });
});

// ---------------------------------------------------------------------------
// Escritura: crear y reordenar, colgadas del módulo
// ---------------------------------------------------------------------------

export const moduleGlossaryRoutes = new Hono<AppEnv>();
moduleGlossaryRoutes.use('*', requireAuth);

moduleGlossaryRoutes.post(
  '/:id/glossary-terms',
  requireRole(...CONTENT_ROLES),
  async (c) => {
    const user = currentUser(c);
    const body = termCreate.parse(await c.req.json());
    const db = c.get('db');
    const mod = await loadEditableModule(db, c.req.param('id'), user);

    const lessonIds = [...new Set(body.lessonIds)];
    const relatedTermIds = [...new Set(body.relatedTermIds)];

    await assertPalabraLibre(db, mod.courseId, body.word, null);
    await assertLeccionesDelModulo(db, mod.id, lessonIds);
    await assertRelacionadosDelCurso(db, mod.courseId, null, relatedTermIds);

    const id = await conDuplicadoComoConflicto(db, mod.courseId, body.word, null, () =>
      db.transaction(async (tx) => {
        const [{ siguiente } = { siguiente: 1 }] = await tx.execute<{
          siguiente: number;
        }>(sql`
          select coalesce(max(order_index), 0)::int + 1 as siguiente
            from glossary_terms where module_id = ${mod.id}
        `);

        const [created] = await tx
          .insert(glossaryTerms)
          .values({
            courseId: mod.courseId,
            moduleId: mod.id,
            orderIndex: siguiente,
            word: body.word,
            shortDefinition: body.shortDefinition,
            explanation: body.explanation,
            example: body.example,
            imageS3Key: body.imageS3Key ?? null,
          })
          .returning({ id: glossaryTerms.id });
        if (!created) throw new Error('El insert del término no devolvió fila.');

        await replaceLinks(tx, created.id, lessonIds, relatedTermIds);
        return created.id;
      }),
    );

    const [term] = await loadTerms(db, { termId: id });
    return c.json(term, 201);
  },
);

/**
 * Reordena TODOS los términos de un módulo de una vez.
 *
 * Mismo mecanismo que módulos y lecciones: `unique(module_id, order_index)`
 * haría fallar un intercambio de a uno, así que va en una transacción y en
 * dos pasos —primero a índices negativos, después a los definitivos—.
 */
moduleGlossaryRoutes.put(
  '/:id/glossary-terms/order',
  requireRole(...CONTENT_ROLES),
  async (c) => {
    const user = currentUser(c);
    const { orderedIds } = reorderBody.parse(await c.req.json());
    const db = c.get('db');
    const mod = await loadEditableModule(db, c.req.param('id'), user);

    const existing = await db
      .select({ id: glossaryTerms.id })
      .from(glossaryTerms)
      .where(eq(glossaryTerms.moduleId, mod.id));

    const existingIds = new Set(existing.map((t) => t.id));
    const alien = orderedIds.filter((id) => !existingIds.has(id));
    const missing = existing.filter((t) => !orderedIds.includes(t.id));
    const repeated = orderedIds.length !== new Set(orderedIds).size;
    if (alien.length > 0 || missing.length > 0 || repeated) {
      throw conflict(
        'La lista de reordenamiento tiene que incluir exactamente los términos de este módulo, una sola vez cada uno.',
        { alien, missing: missing.map((t) => t.id) },
      );
    }

    await db.transaction(async (tx) => {
      for (const [i, id] of orderedIds.entries()) {
        await tx
          .update(glossaryTerms)
          .set({ orderIndex: -(i + 1) })
          .where(eq(glossaryTerms.id, id));
      }
      for (const [i, id] of orderedIds.entries()) {
        await tx
          .update(glossaryTerms)
          .set({ orderIndex: i + 1, updatedAt: new Date() })
          .where(eq(glossaryTerms.id, id));
      }
    });

    return c.json(await loadTerms(db, { moduleId: mod.id }));
  },
);

// ---------------------------------------------------------------------------
// Escritura: un término
// ---------------------------------------------------------------------------

export const glossaryTermRoutes = new Hono<AppEnv>();
glossaryTermRoutes.use('*', requireAuth);

/**
 * Edita un término. `lessonIds` y `relatedTermIds`, si llegan, REEMPLAZAN la
 * lista entera: el editor manda el formulario completo.
 */
glossaryTermRoutes.patch('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = termUpdate.parse(await c.req.json());
  const db = c.get('db');
  const term = await loadEditableTerm(db, c.req.param('id'), user);

  const lessonIds = body.lessonIds && [...new Set(body.lessonIds)];
  const relatedTermIds = body.relatedTermIds && [...new Set(body.relatedTermIds)];

  if (body.word !== undefined) {
    await assertPalabraLibre(db, term.courseId, body.word, term.id);
  }
  if (lessonIds) await assertLeccionesDelModulo(db, term.moduleId, lessonIds);
  if (relatedTermIds) {
    await assertRelacionadosDelCurso(db, term.courseId, term.id, relatedTermIds);
  }

  const fields = {
    word: body.word,
    shortDefinition: body.shortDefinition,
    explanation: body.explanation,
    example: body.example,
    imageS3Key: body.imageS3Key,
  };

  await conDuplicadoComoConflicto(db, term.courseId, body.word ?? term.word, term.id, () =>
    db.transaction(async (tx) => {
      // Un campo `undefined` Drizzle no lo escribe: queda lo que estaba.
      await tx
        .update(glossaryTerms)
        .set({ ...fields, updatedAt: new Date() })
        .where(eq(glossaryTerms.id, term.id));
      await replaceLinks(tx, term.id, lessonIds, relatedTermIds);
    }),
  );

  const [updated] = await loadTerms(db, { termId: term.id });
  return c.json(updated);
});

glossaryTermRoutes.delete('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const term = await loadEditableTerm(db, c.req.param('id'), user);

  // Sus lecciones, sus relacionados —en las dos direcciones— y el repaso de
  // cada estudiante caen por CASCADE.
  await db.delete(glossaryTerms).where(eq(glossaryTerms.id, term.id));
  await renumberTerms(db, term.moduleId);
  return c.body(null, 204);
});

/**
 * Modo repaso: «ya lo sé» (`known`) o «repasar» (`review`).
 *
 * Solo para estudiantes, y solo de un curso que puede ver. Es lo suyo y nada
 * más: no hay forma de marcar el repaso de otra persona.
 */
glossaryTermRoutes.put('/:id/review', async (c) => {
  const user = currentUser(c);
  const { status } = reviewBody.parse(await c.req.json());
  const db = c.get('db');

  if (!isStudentLike(user.role)) {
    throw forbidden('El modo repaso guarda el avance de un estudiante.');
  }

  const scope = visibleCoursesFilter(user);
  const [term] = scope
    ? await db
        .select({ id: glossaryTerms.id })
        .from(glossaryTerms)
        .innerJoin(courses, eq(courses.id, glossaryTerms.courseId))
        .where(and(eq(glossaryTerms.id, c.req.param('id')), scope))
        .limit(1)
    : [];
  if (!term) throw notFound('No se encontró el término.');

  await db
    .insert(glossaryReviews)
    .values({ studentId: user.id, termId: term.id, status })
    .onConflictDoUpdate({
      target: [glossaryReviews.studentId, glossaryReviews.termId],
      set: { status, updatedAt: new Date() },
    });

  return c.json({ termId: term.id, status });
});

// ---------------------------------------------------------------------------
// Reglas
// ---------------------------------------------------------------------------

/**
 * La palabra no puede estar ya en el curso, contando como iguales las que
 * solo cambian en tildes, mayúsculas o espacios.
 *
 * Compara con la MISMA expresión que calcula la columna `word_key`, así que
 * lo que dice esta consulta es exactamente lo que va a decir la restricción.
 */
async function assertPalabraLibre(
  db: Db,
  courseId: string,
  word: string,
  exceptTermId: string | null,
): Promise<void> {
  const [dup] = await db.execute<{ id: string; word: string; moduleTitle: string }>(sql`
    select t.id, t.word, m.title as "moduleTitle"
      from glossary_terms t
      join course_modules m on m.id = t.module_id
     where t.course_id = ${courseId}
       and t.word_key = ${claveDeTerminoSql(sql`${word}::text`)}
       ${exceptTermId ? sql`and t.id <> ${exceptTermId}` : sql``}
     limit 1
  `);
  if (dup) throw duplicado(dup);
}

const duplicado = (dup: { id: string; word: string; moduleTitle: string }) =>
  conflict(
    `El término «${dup.word}» ya está en el glosario de este curso, en el módulo «${dup.moduleTitle}».`,
    { field: 'word', existingTermId: dup.id, moduleTitle: dup.moduleTitle },
  );

/**
 * Si dos personas guardan la misma palabra a la vez, las dos pasan
 * [assertPalabraLibre] y la restricción frena a la segunda. Acá ese choque se
 * convierte en el mismo 409 que habría recibido, en vez de un 500.
 */
async function conDuplicadoComoConflicto<T>(
  db: Db,
  courseId: string,
  word: string,
  exceptTermId: string | null,
  write: () => Promise<T>,
): Promise<T> {
  try {
    return await write();
  } catch (error) {
    if (!violaRestriccion(error, 'glossary_terms_course_word_unique')) throw error;
    await assertPalabraLibre(db, courseId, word, exceptTermId);
    throw error;
  }
}

/** ¿Es un `23505` (*unique_violation*) de ESA restricción? */
function violaRestriccion(error: unknown, constraint: string): boolean {
  for (let actual: unknown = error, saltos = 0; actual && saltos < 5; saltos++) {
    if (
      typeof actual === 'object' &&
      (actual as { code?: unknown }).code === '23505' &&
      (actual as { constraint_name?: unknown }).constraint_name === constraint
    ) {
      return true;
    }
    actual = (actual as { cause?: unknown }).cause;
  }
  return false;
}

/** Un término marca lecciones de SU módulo, no de otro. */
async function assertLeccionesDelModulo(
  db: Db,
  moduleId: string,
  lessonIds: string[],
): Promise<void> {
  if (lessonIds.length === 0) return;
  const found = await db
    .select({ id: lessons.id })
    .from(lessons)
    .where(and(inArray(lessons.id, lessonIds), eq(lessons.courseModuleId, moduleId)));
  const ok = new Set(found.map((l) => l.id));
  const ajenas = lessonIds.filter((id) => !ok.has(id));
  if (ajenas.length > 0) {
    throw conflict('Un término solo puede marcar lecciones de su mismo módulo.', {
      field: 'lessonIds',
      lessons: ajenas,
    });
  }
}

/** Relacionados: otros términos del mismo curso, nunca él mismo. */
async function assertRelacionadosDelCurso(
  db: Db,
  courseId: string,
  termId: string | null,
  relatedTermIds: string[],
): Promise<void> {
  if (termId && relatedTermIds.includes(termId)) {
    throw conflict('Un término no puede ser relacionado de sí mismo.', {
      field: 'relatedTermIds',
    });
  }
  if (relatedTermIds.length === 0) return;
  const found = await db
    .select({ id: glossaryTerms.id })
    .from(glossaryTerms)
    .where(
      and(inArray(glossaryTerms.id, relatedTermIds), eq(glossaryTerms.courseId, courseId)),
    );
  const ok = new Set(found.map((t) => t.id));
  const ajenos = relatedTermIds.filter((id) => !ok.has(id));
  if (ajenos.length > 0) {
    throw conflict('Los términos relacionados tienen que ser de este mismo curso.', {
      field: 'relatedTermIds',
      terms: ajenos,
    });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];

/** Reemplaza las listas que llegaron; las que no (`undefined`) no se tocan. */
async function replaceLinks(
  tx: Tx,
  termId: string,
  lessonIds: string[] | undefined,
  relatedTermIds: string[] | undefined,
): Promise<void> {
  if (lessonIds) {
    await tx.delete(glossaryTermLessons).where(eq(glossaryTermLessons.termId, termId));
    if (lessonIds.length > 0) {
      await tx
        .insert(glossaryTermLessons)
        .values(lessonIds.map((lessonId) => ({ termId, lessonId })));
    }
  }
  if (relatedTermIds) {
    await tx.delete(glossaryTermRelated).where(eq(glossaryTermRelated.termId, termId));
    if (relatedTermIds.length > 0) {
      await tx
        .insert(glossaryTermRelated)
        .values(relatedTermIds.map((relatedTermId) => ({ termId, relatedTermId })));
    }
  }
}

/**
 * Términos con sus lecciones y relacionados, en la forma que ve el cliente.
 *
 * Lecciones en el orden del módulo; relacionados en el orden del glosario
 * (módulo, después término), que es como aparecen en pantalla.
 */
async function loadTerms(
  db: Db,
  filter: { courseId: string } | { moduleId: string } | { termId: string },
) {
  const where =
    'courseId' in filter
      ? sql`t.course_id = ${filter.courseId}`
      : 'moduleId' in filter
        ? sql`t.module_id = ${filter.moduleId}`
        : sql`t.id = ${filter.termId}`;

  return db.execute<Record<string, unknown>>(sql`
    select t.id, t.course_id as "courseId", t.module_id as "moduleId",
           t.order_index as "orderIndex", t.word,
           t.short_definition as "shortDefinition",
           t.explanation, t.example, t.image_s3_key as "imageS3Key",
           coalesce((
             select json_agg(tl.lesson_id order by l.order_index)
               from glossary_term_lessons tl
               join lessons l on l.id = tl.lesson_id
              where tl.term_id = t.id), '[]'::json) as "lessonIds",
           coalesce((
             select json_agg(r.related_term_id order by rm.order_index, rt.order_index)
               from glossary_term_related r
               join glossary_terms rt on rt.id = r.related_term_id
               join course_modules rm on rm.id = rt.module_id
              where r.term_id = t.id), '[]'::json) as "relatedTermIds"
      from glossary_terms t
      join course_modules m on m.id = t.module_id
     where ${where}
     order by m.order_index, t.order_index
  `);
}

async function loadEditableModule(
  db: Db,
  moduleId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [mod] = await db
    .select()
    .from(courseModules)
    .where(eq(courseModules.id, moduleId))
    .limit(1);
  if (!mod) throw notFound('No se encontró el módulo.');
  await loadEditableCourse(db, mod.courseId, user);
  return mod;
}

async function loadEditableTerm(
  db: Db,
  termId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [term] = await db
    .select()
    .from(glossaryTerms)
    .where(eq(glossaryTerms.id, termId))
    .limit(1);
  if (!term) throw notFound('No se encontró el término.');
  await loadEditableCourse(db, term.courseId, user);
  return term;
}

/** Deja los índices consecutivos (1..n) después de borrar un término. */
async function renumberTerms(db: Db, moduleId: string) {
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo
        from glossary_terms where module_id = ${moduleId}
    )
    update glossary_terms t
       set order_index = -o.nuevo
      from ordenados o where o.id = t.id
  `);
  await db.execute(sql`
    update glossary_terms set order_index = -order_index
     where module_id = ${moduleId} and order_index < 0
  `);
}
