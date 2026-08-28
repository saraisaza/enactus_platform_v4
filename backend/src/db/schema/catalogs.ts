import { integer, pgTable, text } from 'drizzle-orm/pg-core';

/**
 * Catálogos fijos, hoy constantes de Dart (`lib/utils/constants.dart`).
 *
 * Van a tabla en vez de a un enum o a un array de texto porque son claves
 * ajenas de verdad: `hoursByCompetency()` agrupa por competencia y
 * `odsCompletionRate()` agrupa por ODS. Con un `text[]` esos agregados no se
 * pueden indexar ni garantizar que el valor exista.
 */

/** Los 17 Objetivos de Desarrollo Sostenible (ONU). Ver `odsList`. */
export const odsGoals = pgTable('ods_goals', {
  /** Clave estable, ej. 'ods_6'. No usar el número como PK: el texto cambia. */
  code: text().primaryKey(),
  number: integer().notNull(),
  title: text().notNull(),
});

/** Las 12 competencias Enactus. Ver `enactusCompetencies`. */
export const competencies = pgTable('competencies', {
  code: text().primaryKey(),
  name: text().notNull(),
});
