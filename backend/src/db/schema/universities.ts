import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  pgTable,
  text,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';

/**
 * Universidad: la unidad de visibilidad del Asesor Académico.
 *
 * Existe porque hasta hoy la universidad era **texto libre** en
 * `users.university` y `groups.university`, y de comparar esas cadenas
 * dependía qué estudiantes veía cada asesor. Un espacio de más, una tilde o
 * «U. de los Andes» frente a «Universidad de los Andes» y el asesor dejaba de
 * ver a su gente — sin error, sin log, sin nada que mirar.
 *
 * Lo que lo volvía difícil de sospechar es que esa comparación estaba
 * **indexada** (`users_university_idx`): la consulta respondía rápido y
 * devolvía cero filas, que es exactamente como se ve «este asesor todavía no
 * tiene estudiantes».
 *
 * Vive en su propio archivo y **no importa `users`** a propósito: el puente
 * `university_advisors` está en `links.ts`, que es donde viven todas las
 * tablas puente. Así no hay import circular con `users.ts`, que sí necesita
 * apuntar acá.
 */
export const universities = pgTable(
  'universities',
  {
    id: uuid().primaryKey().defaultRandom(),
    /** Nombre oficial, tal como se escribe y se muestra. */
    name: text().notNull(),

    /**
     * El nombre normalizado: minúsculas, sin tildes, espacios colapsados.
     *
     * Es lo único que impide que «Universidad de los Andes» y «universidad de
     * los andes » vuelvan a entrar como dos filas distintas. Se calcula al
     * escribir, en la aplicación, y NO con la extensión `unaccent` de
     * Postgres: `unaccent` no está instalada en esta RDS y depender de una
     * extensión para una regla de integridad la vuelve un requisito de
     * infraestructura escondido.
     */
    slug: text().notNull(),

    /** Para chips y tablas, donde el nombre completo no cabe. */
    shortName: text().notNull().default(''),
    city: text().notNull().default(''),
    country: text().notNull().default('Colombia'),

    /**
     * `false` = no admite asignaciones nuevas, pero lo existente sigue
     * funcionando. Es la salida para «esta universidad ya no participa» sin
     * borrar a nadie: borrarla está bloqueado si tiene gente adentro.
     */
    active: boolean().notNull().default(true),

    ...timestamps,
    ...softDelete,
  },
  (t) => [
    // Único entre las vivas. Una universidad borrada no debe impedir volver a
    // crear otra con el mismo nombre más adelante.
    uniqueIndex('universities_slug_unique')
      .on(t.slug)
      .where(sql`${t.deletedAt} is null`),
    index('universities_active_idx').on(t.active),
    index('universities_deleted_at_idx').on(t.deletedAt),
  ],
);
