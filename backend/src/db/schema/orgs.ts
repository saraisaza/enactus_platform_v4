import {
  boolean,
  index,
  pgTable,
  primaryKey,
  text,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { odsGoals } from './catalogs';
import { projectMemberRole, projectStage } from './enums';
import { users } from './users';

export const projects = pgTable(
  'projects',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),
    description: text().notNull().default(''),
    problem: text().notNull().default(''),
    solution: text().notNull().default(''),
    community: text().notNull().default(''),
    stage: projectStage().notNull().default('ideation'),
    impactIndicators: text().notNull().default(''),
    /** Habilitado para RUTA NATIONAL EXPO. */
    expoEnabled: boolean().notNull().default(false),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('projects_stage_idx').on(t.stage),
    index('projects_deleted_at_idx').on(t.deletedAt),
  ],
);

/** ODS de un proyecto. Reemplaza `Project.ods` (`List<String>`). */
export const projectOds = pgTable(
  'project_ods',
  {
    projectId: uuid()
      .notNull()
      .references(() => projects.id, { onDelete: 'cascade' }),
    odsCode: text()
      .notNull()
      .references(() => odsGoals.code, { onDelete: 'restrict' }),
  },
  (t) => [
    primaryKey({ columns: [t.projectId, t.odsCode] }),
    index('project_ods_ods_code_idx').on(t.odsCode),
  ],
);

/** Equipo de estudiantes que trabaja un proyecto. */
export const groups = pgTable(
  'groups',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),
    projectId: uuid()
      .notNull()
      .references(() => projects.id, { onDelete: 'restrict' }),
    university: text().notNull().default(''),
    advisorId: uuid().references(() => users.id, { onDelete: 'set null' }),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('groups_project_id_idx').on(t.projectId),
    index('groups_advisor_id_idx').on(t.advisorId),
    index('groups_deleted_at_idx').on(t.deletedAt),
  ],
);

/**
 * Integrantes de un equipo. Reemplaza a la vez `Group.studentIds` y
 * `AppUser.groupId`, que hoy son la misma relación guardada dos veces y en
 * direcciones opuestas (se pueden desincronizar).
 *
 * `roleInProject` es la brecha de modelo que detectó la auditoría de frontend
 * (BLOQUEOS.md § 2): la pantalla de detalle de proyecto necesita el rol de
 * cada persona dentro del proyecto, y hoy `studentIds` es solo una lista de
 * ids sin rol.
 */
export const groupMembers = pgTable(
  'group_members',
  {
    groupId: uuid()
      .notNull()
      .references(() => groups.id, { onDelete: 'cascade' }),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    roleInProject: projectMemberRole().notNull().default('member'),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.groupId, t.userId] }),
    // "¿en qué equipo está esta persona?" es la consulta más frecuente.
    index('group_members_user_id_idx').on(t.userId),
  ],
);
