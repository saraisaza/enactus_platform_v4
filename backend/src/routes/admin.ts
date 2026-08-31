import { and, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { auditLog, users } from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import { publicUser } from '../lib/dto';
import {
  ADMIN_ROLES,
  currentUser,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { impactMetrics } from '../services/impact-metrics';

export const adminRoutes = new Hono<AppEnv>();
adminRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

const canGradeBody = z.object({
  canGradeOpenLearning: z.boolean().optional(),
  canGradeEnactus: z.boolean().optional(),
});

/**
 * Cambia el permiso de calificar de un LXD.
 *
 * Son DOS permisos, no uno (decisión confirmada en la Fase 0). Cada cambio
 * queda en `audit_log` con quién, a quién, cuándo y los valores anterior y
 * nuevo — es requisito explícito.
 */
adminRoutes.patch('/users/:id/can-grade', async (c) => {
  const actor = currentUser(c);
  const body = canGradeBody.parse(await c.req.json());
  if (body.canGradeOpenLearning === undefined && body.canGradeEnactus === undefined) {
    throw conflict('No enviaste ningún permiso para cambiar.');
  }

  const db = c.get('db');
  const targetId = c.req.param('id');
  const [target] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, targetId), isNull(users.deletedAt)))
    .limit(1);
  if (!target) throw notFound('No se encontró el usuario.');

  if (target.role !== 'lxd') {
    throw conflict(
      'El permiso de calificar solo aplica a cuentas LXD. Admin y superadmin califican sin él.',
      { role: target.role },
    );
  }

  const before = {
    canGradeOpenLearning: target.canGradeOpenLearning,
    canGradeEnactus: target.canGradeEnactus,
  };
  const after = {
    canGradeOpenLearning: body.canGradeOpenLearning ?? before.canGradeOpenLearning,
    canGradeEnactus: body.canGradeEnactus ?? before.canGradeEnactus,
  };

  const [updated] = await db
    .update(users)
    .set({ ...after, updatedAt: new Date() })
    .where(eq(users.id, target.id))
    .returning();

  await db.insert(auditLog).values({
    actorId: actor.id,
    action: 'user.can_grade.update',
    entityType: 'user',
    entityId: target.id,
    oldValue: before,
    newValue: after,
    ip: c.get('requestIp'),
  });

  return c.json(publicUser(updated!));
});

/**
 * Métricas de impacto formativo del panel Admin.
 *
 * Las tres las calculaba el cliente recorriendo toda la base en memoria: horas
 * por competencia, cobertura de ODS y horas patrocinadas por empresa. Contra
 * una base remota eso sería descargar cada curso, cada estudiante y cada
 * progreso para sumar tres números.
 *
 * Van juntas en una sola respuesta porque la pantalla las muestra juntas: son
 * tres agregaciones sobre las mismas dos vistas, y pedirlas por separado
 * costaría tres viajes para dibujar un panel.
 */
adminRoutes.get('/metrics', async (c) => {
  return c.json(await impactMetrics(c.get('db')));
});

/**
 * Métrica de almacenamiento de video.
 *
 * Es el número que va a crecer y necesita visibilidad: sin transcodificación,
 * lo que se sube es lo que se guarda y lo que se paga.
 */
adminRoutes.get('/storage/video', async (c) => {
  const [row] = await c.get('db').execute<{
    lesson_count: number;
    lesson_bytes: string;
    course_intro_count: number;
    course_intro_bytes: string;
  }>(sql`
    select
      (select count(*)::int from lessons where video_s3_key is not null) as lesson_count,
      (select coalesce(sum(video_size_bytes), 0)::text from lessons) as lesson_bytes,
      (select count(*)::int from courses where intro_video_s3_key is not null) as course_intro_count,
      (select coalesce(sum(intro_video_size_bytes), 0)::text from courses) as course_intro_bytes
  `);

  const lessonBytes = Number(row?.lesson_bytes ?? 0);
  const introBytes = Number(row?.course_intro_bytes ?? 0);
  const totalBytes = lessonBytes + introBytes;

  return c.json({
    lessons: { count: row?.lesson_count ?? 0, bytes: lessonBytes },
    courseIntros: { count: row?.course_intro_count ?? 0, bytes: introBytes },
    totalBytes,
    totalGb: Number((totalBytes / 1024 ** 3).toFixed(3)),
  });
});

/**
 * Respaldo completo.
 *
 * A diferencia de `exportBackupJson()` de hoy, que vuelca la caja `users`
 * entera —contraseñas en texto plano incluidas— a un archivo que el Admin
 * descarga: acá `password_hash` y los `refresh_tokens` quedan FUERA. Un
 * respaldo es para restaurar datos, no para llevarse las credenciales.
 */
const BACKUP_TABLES = [
  'ods_goals',
  'competencies',
  'users',
  'projects',
  'project_ods',
  'groups',
  'group_members',
  'laboratories',
  'laboratory_mentors',
  'phases',
  'objectives',
  'ruta_modules',
  'courses',
  'course_tags',
  'course_objectives',
  'course_competencies',
  'course_learning_outcomes',
  'course_prerequisites',
  'course_ods',
  'course_modules',
  'lessons',
  'quiz_questions',
  'quiz_question_options',
  'lesson_activities',
  'activity_allowed_types',
  'activity_rubric_items',
  'objective_courses',
  'ruta_module_courses',
  'student_laboratories',
  'student_courses',
  'mentor_review_courses',
  'progress',
  'progress_lessons',
  'ruta_progress',
  'ruta_progress_lessons',
  'submissions',
  'submission_files',
  'quiz_attempts',
  'certificates',
  'evidences',
  'communication_resources',
  'notifications',
  'forum_posts',
  'forum_replies',
  'forum_likes',
  'calendar_events',
  'site_content',
  'site_gallery_images',
  'staff_notes',
  'expo_checklist_items',
] as const;

adminRoutes.get('/backup', async (c) => {
  const db = c.get('db');
  const data: Record<string, unknown[]> = {};

  for (const table of BACKUP_TABLES) {
    const rows =
      table === 'users'
        ? await db.execute(
            sql`select id, name, email, role, phone, cedula, city, university,
                       career, company_name, impact_code, student_type,
                       can_grade_open_learning, can_grade_enactus, company_id,
                       donor_id, avatar_s3_key, joined_at, profile,
                       created_at, updated_at, deleted_at
                  from users`,
          )
        : await db.execute(sql`select * from ${sql.identifier(table)}`);
    data[table] = rows;
  }

  await db.insert(auditLog).values({
    actorId: currentUser(c).id,
    action: 'admin.backup',
    entityType: 'database',
    ip: c.get('requestIp'),
  });

  return c.json({
    version: 1,
    generatedAt: new Date().toISOString(),
    note:
      'Un respaldo no lleva credenciales: se excluyen las contraseñas ' +
      'hasheadas y las sesiones abiertas.',
    data,
  });
});

/**
 * Restauración. El endpoint más peligroso de toda la API.
 *
 * Reservado a superadmin (decisión de la matriz: hoy en Flutter cualquier
 * Admin puede hacerlo). Es transaccional: o entra todo, o no entra nada.
 */
adminRoutes.post('/restore', async (c) => {
  const actor = currentUser(c);
  if (actor.role !== 'superadmin') {
    throw forbidden(
      'Restaurar reemplaza la base entera: solo un Super Admin puede hacerlo.',
    );
  }

  const payload = z
    .object({
      version: z.number().int(),
      data: z.record(z.string(), z.array(z.record(z.string(), z.unknown()))),
      confirm: z.literal('REEMPLAZAR TODOS LOS DATOS'),
    })
    .parse(await c.req.json());

  const db = c.get('db');
  const restored: Record<string, number> = {};

  await db.transaction(async (tx) => {
    // En orden inverso, para no chocar con las claves ajenas.
    for (const table of [...BACKUP_TABLES].reverse()) {
      await tx.execute(sql`delete from ${sql.identifier(table)}`);
    }
    for (const table of BACKUP_TABLES) {
      const rows = payload.data[table] ?? [];
      restored[table] = rows.length;
      for (const row of rows) {
        const cols = Object.keys(row);
        if (cols.length === 0) continue;
        const identifiers = sql.join(
          cols.map((col) => sql.identifier(col)),
          sql`, `,
        );
        const values = sql.join(
          cols.map((col) => sql`${row[col]}`),
          sql`, `,
        );
        await tx.execute(
          sql`insert into ${sql.identifier(table)} (${identifiers}) values (${values})`,
        );
      }
    }
  });

  await db.insert(auditLog).values({
    actorId: actor.id,
    action: 'admin.restore',
    entityType: 'database',
    newValue: restored,
    ip: c.get('requestIp'),
  });

  return c.json({ restored });
});
