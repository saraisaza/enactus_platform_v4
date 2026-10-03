import { type SQL, sql } from 'drizzle-orm';
import {
  check,
  foreignKey,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';
import { courseModules, courses, lessons } from './courses';
import { users } from './users';

/**
 * Las letras que se consideran iguales al comparar dos palabras del glosario.
 *
 * «Innovación» e «innovacion» son el mismo término; «año» y «ano» no lo son,
 * por eso la ñ se conserva (solo se pasa a minúscula). Cada letra de
 * [ACENTOS] se cambia por la que está en la misma posición de [SIN_ACENTOS].
 *
 * El cliente tiene una copia de esta tabla (`claveDeTermino` en
 * `lib/models/glossary.dart`) para avisar mientras se escribe; quien decide
 * es la base.
 */
export const ACENTOS = 'ÁÀÂÄÃáàâäãÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÖÕóòôöõÚÙÛÜúùûüÑ';
export const SIN_ACENTOS = 'aaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuñ';

/**
 * Clave de comparación de una palabra: sin tildes ni diéresis, en minúscula
 * y con los espacios repetidos reducidos a uno.
 *
 * `collate "C"` hace que `lower()` toque solo las letras ASCII, igual en
 * cualquier base: con la configuración regional de RDS y con la de un
 * portátil. Las mayúsculas acentuadas ya salieron en minúscula del
 * `translate`, así que no hace falta más.
 *
 * Es la MISMA expresión en la columna generada y en la consulta que avisa del
 * duplicado, para que las dos no puedan opinar distinto.
 */
export const claveDeTerminoSql = (palabra: SQL): SQL =>
  sql`lower(btrim(regexp_replace(translate(${palabra}, ${sql.raw(`'${ACENTOS}'`)}, ${sql.raw(`'${SIN_ACENTOS}'`)}), '\\s+', ' ', 'g')) collate "C")`;

/**
 * Término del glosario de un curso.
 *
 * Pertenece a UN módulo y lleva también el curso, que es donde se exige que
 * no haya dos términos iguales. La clave foránea compuesta
 * `(module_id, course_id) → course_modules(id, course_id)` impide que el
 * curso guardado contradiga al del módulo: sin ella, un error de la API
 * podría dejar un término «en» un curso distinto del suyo y saltarse la
 * regla de duplicados.
 */
export const glossaryTerms = pgTable(
  'glossary_terms',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    moduleId: uuid().notNull(),
    orderIndex: integer().notNull(),
    word: text().notNull(),
    /** La calcula la base; nunca se escribe. Ver [claveDeTerminoSql]. */
    wordKey: text().generatedAlwaysAs((): SQL => claveDeTerminoSql(sql`${glossaryTerms.word}`)),
    /** Una o dos frases: es lo que se ve en la tarjeta cerrada y en el tooltip. */
    shortDefinition: text().notNull(),
    explanation: text().notNull().default(''),
    example: text().notNull().default(''),
    /** Key en S3, bajo `glossary-images/`. */
    imageS3Key: text('image_s3_key'),
    ...timestamps,
  },
  (t) => [
    foreignKey({
      name: 'glossary_terms_module_course_fk',
      columns: [t.moduleId, t.courseId],
      foreignColumns: [courseModules.id, courseModules.courseId],
    }).onDelete('cascade'),
    unique('glossary_terms_course_word_unique').on(t.courseId, t.wordKey),
    unique('glossary_terms_module_order_unique').on(t.moduleId, t.orderIndex),
    index('glossary_terms_course_id_idx').on(t.courseId),
    check('glossary_terms_word_not_blank', sql`btrim(${t.word}) <> ''`),
    check(
      'glossary_terms_short_definition_not_blank',
      sql`btrim(${t.shortDefinition}) <> ''`,
    ),
  ],
);

/**
 * Lecciones donde aparece un término. Solo lecciones del módulo del término:
 * lo valida la API (`routes/glossary.ts`); una lección no cambia de módulo,
 * así que la regla no puede romperse después.
 */
export const glossaryTermLessons = pgTable(
  'glossary_term_lessons',
  {
    termId: uuid()
      .notNull()
      .references(() => glossaryTerms.id, { onDelete: 'cascade' }),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
  },
  (t) => [
    primaryKey({ columns: [t.termId, t.lessonId] }),
    index('glossary_term_lessons_lesson_id_idx').on(t.lessonId),
  ],
);

/**
 * Términos relacionados, en una sola dirección: lo que el LXD eligió para
 * ESTE término. Que «Modelo» lleve a «Datos» no obliga a lo contrario.
 * Ambos del mismo curso (lo valida la API).
 */
export const glossaryTermRelated = pgTable(
  'glossary_term_related',
  {
    termId: uuid()
      .notNull()
      .references(() => glossaryTerms.id, { onDelete: 'cascade' }),
    relatedTermId: uuid()
      .notNull()
      .references(() => glossaryTerms.id, { onDelete: 'cascade' }),
  },
  (t) => [
    primaryKey({ columns: [t.termId, t.relatedTermId] }),
    index('glossary_term_related_related_idx').on(t.relatedTermId),
    check('glossary_term_related_not_self', sql`${t.termId} <> ${t.relatedTermId}`),
  ],
);

/**
 * Modo repaso: lo que cada estudiante marcó de cada término.
 *
 * `known` = «ya lo sé»; `review` = «repasar». Sin fila = todavía no lo vio
 * en modo repaso.
 */
export const glossaryReviews = pgTable(
  'glossary_reviews',
  {
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    termId: uuid()
      .notNull()
      .references(() => glossaryTerms.id, { onDelete: 'cascade' }),
    status: text().notNull(),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.studentId, t.termId] }),
    index('glossary_reviews_term_id_idx').on(t.termId),
    check('glossary_reviews_status_valid', sql`${t.status} in ('known', 'review')`),
  ],
);
