import { timestamp } from 'drizzle-orm/pg-core';

/**
 * Marcas de tiempo que llevan TODAS las tablas (requisito del esquema).
 * `updatedAt` lo mantiene la aplicación, no un trigger: con Drizzle toda
 * escritura pasa por el repositorio, y un trigger escondería el cambio de
 * quien lee el código.
 */
export const timestamps = {
  createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
};

/**
 * Borrado lógico. Se agrega SOLO a las tablas que hoy tienen un `delete*` en
 * `DataProvider` (users, projects, groups, labs, courses, submissions,
 * evidences, comm_resources, calendar_events, forum_posts) — el resto se
 * borra de verdad o no se borra nunca.
 *
 * `deletedAt IS NULL` es la condición de "vivo" en todas las consultas.
 */
export const softDelete = {
  deletedAt: timestamp({ withTimezone: true }),
};
