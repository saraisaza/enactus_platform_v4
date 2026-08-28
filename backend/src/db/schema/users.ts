import { sql } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';
import {
  boolean,
  check,
  index,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { studentType, userRole } from './enums';

/**
 * Usuarios. Reemplaza `AppUser` + su bolsa `extra`.
 *
 * Todo lo que en Flutter tenía getter con semántica clara (`university`,
 * `studentType`, `canGrade*`, `companyId`, `donorId`, …) pasa a columna
 * tipada. `profile` (JSONB) sobrevive SOLO para los siete campos de perfil
 * libre de LXD y Mentor: company, position, specialty, languages,
 * availability, experience, interests — texto sin estructura que nadie
 * consulta ni agrega.
 *
 * Dos campos de `extra` desaparecen:
 * - `groupId`: la pertenencia a un equipo vive solo en `group_members`
 *   (hoy está duplicada en las dos direcciones y se puede desincronizar).
 * - `labIds` / `courseIds` / `reviewCourseIds`: pasan a tablas puente.
 */
export const users = pgTable(
  'users',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),
    /** Se guarda tal cual lo escribió la persona; la unicidad es sobre lower(email). */
    email: text().notNull(),
    /** bcrypt. NUNCA sale de la base: ni en un DTO, ni en el backup. */
    passwordHash: text().notNull(),
    role: userRole().notNull(),

    phone: text().notNull().default(''),
    cedula: text().notNull().default(''),
    city: text().notNull().default(''),
    /** Estudiantes/alumni y asesores. `studentsForAdvisor` cruza por acá. */
    university: text().notNull().default(''),
    career: text().notNull().default(''),
    /** Solo rol `company`. */
    companyName: text().notNull().default(''),
    /** Solo rol `donor`. Único: es el código que el donante comparte. */
    impactCode: text(),

    /** Obligatorio para student/alumni, prohibido para el resto (ver CHECK). */
    studentType: studentType(),

    /**
     * Permiso de calificar, separado por contexto (decisión confirmada en la
     * Fase 0, punto 8): en Open Learning el LXD es el docente y califica por
     * defecto; en Enactus la calificación es un acto institucional que el
     * Admin habilita caso por caso. Solo admin/superadmin los modifican, y
     * cada cambio queda en `audit_log`.
     */
    canGradeOpenLearning: boolean().notNull().default(true),
    canGradeEnactus: boolean().notNull().default(false),

    /** Empresa aliada a la que pertenece (estudiante patrocinado, LXD, mentor). */
    companyId: uuid().references((): AnyPgColumn => users.id, {
      onDelete: 'set null',
    }),
    /** Donante que apoya a este estudiante. */
    donorId: uuid().references((): AnyPgColumn => users.id, {
      onDelete: 'set null',
    }),

    /** Key en S3. Reemplaza el `avatarBase64` que hoy vive dentro del registro. */
    avatarS3Key: text('avatar_s3_key'),
    joinedAt: timestamp({ withTimezone: true }),

    /** Campos de perfil libre de LXD/Mentor. Ver nota de arriba. */
    profile: jsonb().notNull().default(sql`'{}'::jsonb`),

    ...timestamps,
    ...softDelete,
  },
  (t) => [
    // Índice funcional: dos cuentas no pueden diferir solo en mayúsculas.
    // `findByCredentials` ya compara en minúsculas hoy.
    uniqueIndex('users_email_lower_unique').on(sql`lower(${t.email})`),
    uniqueIndex('users_impact_code_unique')
      .on(t.impactCode)
      .where(sql`${t.impactCode} is not null`),
    index('users_role_idx').on(t.role),
    index('users_company_id_idx').on(t.companyId),
    index('users_donor_id_idx').on(t.donorId),
    // `studentsForAdvisor` filtra por universidad exacta.
    index('users_university_idx').on(t.university),
    index('users_deleted_at_idx').on(t.deletedAt),
    check(
      'users_student_type_matches_role',
      sql`(${t.role} in ('student','alumni')) = (${t.studentType} is not null)`,
    ),
    check(
      'users_impact_code_only_donor',
      sql`${t.impactCode} is null or ${t.role} = 'donor'`,
    ),
  ],
);

/**
 * Refresh tokens con rotación: cada uso emite uno nuevo y marca el anterior
 * como reemplazado. Se guarda el hash, no el token — si se filtra la tabla,
 * no se puede iniciar sesión con ella.
 *
 * Un `replacedBy` que apunta a un token ya revocado es la señal de reuso de
 * un token robado: ahí se revoca toda la cadena del usuario.
 */
export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: text().notNull(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    revokedAt: timestamp({ withTimezone: true }),
    replacedBy: uuid().references((): AnyPgColumn => refreshTokens.id, {
      onDelete: 'set null',
    }),
    userAgent: text().notNull().default(''),
    ip: text().notNull().default(''),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('refresh_tokens_hash_unique').on(t.tokenHash),
    index('refresh_tokens_user_id_idx').on(t.userId),
    index('refresh_tokens_expires_at_idx').on(t.expiresAt),
  ],
);

/**
 * Bitácora de auditoría. Obligatoria para los cambios de `can_grade` (quién,
 * a quién, cuándo, valor anterior y nuevo) y usada además para todo lo que
 * la Fase 0 marcó como sensible: restore de respaldo, cambio de rol,
 * promoción Open Learning→Enactus, emisión de certificado, borrado físico.
 *
 * `actorId` es nullable a propósito: las acciones del sistema (la tarea
 * programada de deadlines) no tienen actor humano.
 */
export const auditLog = pgTable(
  'audit_log',
  {
    id: uuid().primaryKey().defaultRandom(),
    actorId: uuid().references(() => users.id, { onDelete: 'set null' }),
    action: text().notNull(),
    entityType: text().notNull(),
    entityId: uuid(),
    oldValue: jsonb(),
    newValue: jsonb(),
    ip: text().notNull().default(''),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('audit_log_entity_idx').on(t.entityType, t.entityId),
    index('audit_log_actor_id_idx').on(t.actorId),
    index('audit_log_created_at_idx').on(t.createdAt),
  ],
);
