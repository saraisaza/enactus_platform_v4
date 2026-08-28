import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  date,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { objectiveCategory } from './enums';
import { users } from './users';

/**
 * Laboratorio. Sus 3 fases dejan de estar anidadas en el registro y pasan a
 * `phases` (requisito del esquema).
 */
export const laboratories = pgTable(
  'laboratories',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),
    description: text().notNull().default(''),
    objectives: text().notNull().default(''),
    sponsorCompanyId: uuid().references(() => users.id, {
      onDelete: 'set null',
    }),
    /**
     * Sube con cada cambio estructural de la Ruta (agregar/quitar un módulo,
     * vincular un curso). El certificado guarda contra qué versión se emitió,
     * para que agregar contenido después no lo invalide — ver decisión B.1 de
     * AUDITORIA_BACKEND.md.
     */
    contentVersion: integer().notNull().default(1),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('laboratories_sponsor_company_id_idx').on(t.sponsorCompanyId),
    index('laboratories_deleted_at_idx').on(t.deletedAt),
  ],
);

/**
 * Mentores de un laboratorio. Varios mentores pueden compartir el mismo
 * laboratorio y sus estudiantes. Reemplaza `Laboratory.mentorIds`.
 */
export const laboratoryMentors = pgTable(
  'laboratory_mentors',
  {
    laboratoryId: uuid()
      .notNull()
      .references(() => laboratories.id, { onDelete: 'cascade' }),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.laboratoryId, t.userId] }),
    index('laboratory_mentors_user_id_idx').on(t.userId),
  ],
);

/**
 * Fase de la Ruta de Impacto. Siempre 3 por laboratorio (`orderIndex` 1..3).
 * La fase 1 está siempre desbloqueada; cada siguiente exige la anterior
 * completa — eso se calcula, no se guarda (ver `src/db/completeness.sql`).
 */
export const phases = pgTable(
  'phases',
  {
    id: uuid().primaryKey().defaultRandom(),
    laboratoryId: uuid()
      .notNull()
      .references(() => laboratories.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull(),
    title: text().notNull().default(''),
    description: text().notNull().default(''),
    /** Lo pone el Admin. Alimenta las alertas de fase próxima a vencer. */
    deadline: date(),
    ...timestamps,
  },
  (t) => [
    unique('phases_lab_order_unique').on(t.laboratoryId, t.orderIndex),
    index('phases_laboratory_id_idx').on(t.laboratoryId),
    check('phases_order_positive', sql`${t.orderIndex} > 0`),
  ],
);

/**
 * Objetivo de una fase. Se completa cuando el estudiante terminó el 100% de
 * TODOS los cursos de `objective_courses` — un objetivo sin cursos vinculados
 * nunca se completa (no se puede marcar a mano).
 */
export const objectives = pgTable(
  'objectives',
  {
    id: uuid().primaryKey().defaultRandom(),
    phaseId: uuid()
      .notNull()
      .references(() => phases.id, { onDelete: 'cascade' }),
    category: objectiveCategory().notNull().default('entrepreneurship'),
    text: text().notNull().default(''),
    orderIndex: integer().notNull().default(0),
    ...timestamps,
  },
  (t) => [index('objectives_phase_id_idx').on(t.phaseId)],
);

/**
 * Módulo dentro de una fase. No confundir con `course_modules` (que agrupa
 * lecciones DENTRO de un curso): un módulo de Ruta agrupa entregas y lecturas
 * propias MÁS varios cursos completos asignados.
 *
 * El último módulo de cada fase es siempre el de mentoría; el flag se
 * recalcula tras cualquier cambio, no lo marca nadie a mano.
 */
export const rutaModules = pgTable(
  'ruta_modules',
  {
    id: uuid().primaryKey().defaultRandom(),
    phaseId: uuid()
      .notNull()
      .references(() => phases.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull(),
    title: text().notNull().default(''),
    isMentorshipModule: boolean().notNull().default(false),
    ...timestamps,
  },
  (t) => [
    unique('ruta_modules_phase_order_unique').on(t.phaseId, t.orderIndex),
    index('ruta_modules_phase_id_idx').on(t.phaseId),
    check('ruta_modules_order_positive', sql`${t.orderIndex} > 0`),
  ],
);
