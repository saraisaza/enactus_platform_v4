import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  check,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
  unique,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { courses } from './courses';
import {
  calendarEventType,
  commResourceType,
  evidenceType,
  forumCategory,
} from './enums';
import { laboratories } from './labs';
import { groups, projects } from './orgs';
import { users } from './users';

/**
 * Evidencia de impacto visible para un donante.
 *
 * `projectId` es la segunda brecha de modelo que detectó la auditoría de
 * frontend (BLOQUEOS.md § 2): hoy una evidencia solo se relaciona con el
 * donante, y no hay forma de saber a qué proyecto pertenece sin adivinar.
 * Nulable: existen evidencias generales, no atadas a un proyecto.
 */
export const evidences = pgTable(
  'evidences',
  {
    id: uuid().primaryKey().defaultRandom(),
    donorId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    projectId: uuid().references(() => projects.id, { onDelete: 'set null' }),
    type: evidenceType().notNull(),
    title: text().notNull(),
    description: text().notNull().default(''),
    s3Key: text('s3_key'),
    fileName: text(),
    contentType: text(),
    sizeBytes: bigint({ mode: 'number' }),
    evidenceDate: timestamp({ withTimezone: true }).notNull().defaultNow(),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('evidences_donor_id_idx').on(t.donorId),
    index('evidences_project_id_idx').on(t.projectId),
    index('evidences_deleted_at_idx').on(t.deletedAt),
  ],
);

/**
 * Plantillas de comunicaciones que publica el Admin. El contenido del archivo
 * deja de vivir en base64 dentro del registro y pasa a S3.
 */
export const communicationResources = pgTable(
  'communication_resources',
  {
    id: uuid().primaryKey().defaultRandom(),
    title: text().notNull(),
    description: text().notNull().default(''),
    type: commResourceType().notNull(),
    fileName: text(),
    s3Key: text('s3_key'),
    contentType: text(),
    sizeBytes: bigint({ mode: 'number' }),
    url: text(),
    uploadedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('communication_resources_uploaded_by_idx').on(t.uploadedBy),
    index('communication_resources_deleted_at_idx').on(t.deletedAt),
    check(
      'communication_resources_source_matches_type',
      sql`(${t.type} = 'file' and ${t.s3Key} is not null and ${t.url} is null)
       or (${t.type} = 'link' and ${t.url} is not null and ${t.s3Key} is null)`,
    ),
  ],
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    title: text().notNull(),
    body: text().notNull().default(''),
    readAt: timestamp({ withTimezone: true }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // La bandeja siempre se lee por usuario y en orden cronológico inverso.
    index('notifications_user_created_idx').on(t.userId, t.createdAt),
  ],
);

/**
 * Foro de la comunidad: el único espacio que NO está aislado por laboratorio,
 * universidad ni empresa. Lo comparten Admin, Super Admin, Asesores y
 * estudiantes/alumni Enactus (los de Open Learning no participan).
 */
export const forumPosts = pgTable(
  'forum_posts',
  {
    id: uuid().primaryKey().defaultRandom(),
    authorId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    body: text().notNull(),
    category: forumCategory().notNull().default('question'),
    pinned: boolean().notNull().default(false),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('forum_posts_author_id_idx').on(t.authorId),
    index('forum_posts_created_at_idx').on(t.createdAt),
    index('forum_posts_pinned_idx').on(t.pinned),
    index('forum_posts_deleted_at_idx').on(t.deletedAt),
  ],
);

/** Respuestas. Salen de `ForumPost.replies` a su propia tabla, con FK. */
export const forumReplies = pgTable(
  'forum_replies',
  {
    id: uuid().primaryKey().defaultRandom(),
    postId: uuid()
      .notNull()
      .references(() => forumPosts.id, { onDelete: 'cascade' }),
    authorId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    body: text().notNull(),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('forum_replies_post_id_idx').on(t.postId),
    index('forum_replies_author_id_idx').on(t.authorId),
  ],
);

/**
 * Un apoyo por persona por publicación. Reemplaza `ForumPost.likedBy`, que
 * hoy obliga a leer-modificar-escribir el post entero para dar un like (una
 * condición de carrera segura en cuanto haya concurrencia real).
 */
export const forumLikes = pgTable(
  'forum_likes',
  {
    postId: uuid()
      .notNull()
      .references(() => forumPosts.id, { onDelete: 'cascade' }),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.postId, t.userId] }),
    index('forum_likes_user_id_idx').on(t.userId),
  ],
);

export const calendarEvents = pgTable(
  'calendar_events',
  {
    id: uuid().primaryKey().defaultRandom(),
    title: text().notNull().default(''),
    description: text().notNull().default(''),
    startsAt: timestamp({ withTimezone: true }).notNull(),
    type: calendarEventType().notNull().default('ruta_impacto'),
    meetLink: text().notNull().default(''),
    /** Texto libre, ej. "Invitados: María Pérez (Bancolombia)". */
    guests: text().notNull().default(''),
    /** Solo `open_learning_sync`. */
    courseId: uuid().references(() => courses.id, { onDelete: 'cascade' }),
    /** Solo `ruta_impacto` / `mentoria`. */
    laboratoryId: uuid().references(() => laboratories.id, {
      onDelete: 'cascade',
    }),
    createdBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('calendar_events_starts_at_idx').on(t.startsAt),
    index('calendar_events_course_id_idx').on(t.courseId),
    index('calendar_events_laboratory_id_idx').on(t.laboratoryId),
    index('calendar_events_type_idx').on(t.type),
    check(
      'calendar_events_target_matches_type',
      sql`(${t.type} = 'open_learning_sync' and ${t.courseId} is not null and ${t.laboratoryId} is null)
       or (${t.type} in ('ruta_impacto','mentoria') and ${t.courseId} is null)`,
    ),
  ],
);

/**
 * Contenido editable de la página principal. Fila única: `id` fijo en 1.
 */
export const siteContent = pgTable(
  'site_content',
  {
    id: integer().primaryKey().default(1),
    heroTitle: text().notNull().default(''),
    heroSubtitle: text().notNull().default(''),
    bannerText: text().notNull().default(''),
    aboutText: text().notNull().default(''),
    /** Link genérico de videollamada para los módulos de mentoría. */
    meetingLink: text().notNull().default(''),
    /** Cifras curadas a mano por el equipo, no calculadas. */
    statStudents: integer().notNull().default(0),
    statProjects: integer().notNull().default(0),
    statLabs: integer().notNull().default(0),
    statUniversities: integer().notNull().default(0),
    updatedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (t) => [check('site_content_singleton', sql`${t.id} = 1`)],
);

/** Galería del landing. Antes una lista de base64 dentro de `SiteContent`. */
export const siteGalleryImages = pgTable(
  'site_gallery_images',
  {
    id: uuid().primaryKey().defaultRandom(),
    s3Key: text('s3_key').notNull(),
    orderIndex: integer().notNull().default(0),
    ...timestamps,
  },
  (t) => [uniqueIndex('site_gallery_images_s3_key_unique').on(t.s3Key)],
);

/**
 * Notas del equipo docente sobre un estudiante en un curso.
 *
 * Se renombra de `mentor_notes` a `staff_notes` porque el nombre mentía:
 * quien las escribe hoy es el LXD desde su seguimiento de curso, no el
 * Mentor. Privadas para el equipo docente — el estudiante NO las ve
 * (decisión B.5); para lo que sí debe llegarle está `submissions.feedback`.
 */
export const staffNotes = pgTable(
  'staff_notes',
  {
    id: uuid().primaryKey().defaultRandom(),
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    authorId: uuid().references(() => users.id, { onDelete: 'set null' }),
    note: text().notNull().default(''),
    ...timestamps,
  },
  (t) => [
    // Una nota por estudiante y curso, como hoy (clave 'studentId::courseId').
    unique('staff_notes_student_course_unique').on(t.studentId, t.courseId),
    index('staff_notes_course_id_idx').on(t.courseId),
  ],
);

/** Checklist RUTA NATIONAL EXPO, por equipo. Legado. */
export const expoChecklistItems = pgTable(
  'expo_checklist_items',
  {
    id: uuid().primaryKey().defaultRandom(),
    groupId: uuid()
      .notNull()
      .references(() => groups.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull().default(0),
    label: text().notNull(),
    done: boolean().notNull().default(false),
    ...timestamps,
  },
  (t) => [index('expo_checklist_items_group_id_idx').on(t.groupId)],
);
