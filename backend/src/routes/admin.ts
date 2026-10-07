import { randomBytes } from 'node:crypto';

import { and, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { auditLog, users } from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
import { hashPassword } from '../lib/password';
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
    throw conflict('No envió ningún permiso para cambiar.');
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
  // Antes de `users`: las cuentas van a apuntar a su cliente.
  'clients',
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
  'glossary_terms',
  'glossary_term_lessons',
  'glossary_term_related',
  'objective_courses',
  'ruta_module_courses',
  'student_laboratories',
  'student_courses',
  'mentor_review_courses',
  'progress',
  'progress_lessons',
  'ruta_progress',
  'ruta_progress_lessons',
  // Después de `users` y `lessons`, de las que cuelga: el orden de la lista
  // es el de inserción al restaurar.
  'lesson_video_progress',
  'glossary_reviews',
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
  'forum_reports',
  'user_blocks',
  'calendar_events',
  'site_content',
  'site_gallery_images',
  'staff_notes',
  'expo_checklist_items',
  // `storage_pending_deletes` NO va: es la cola de archivos por borrar, trabajo
  // pendiente y no datos. Restaurarla volvería a anotar archivos ya borrados.
] as const;

/**
 * Tablas que un respaldo hecho antes de que existieran no trae, y que por eso
 * se conservan al restaurarlo. Solo las que se agregaron después de que hubo
 * respaldos en uso; agregar una acá es decidir que un respaldo viejo no la
 * vacíe.
 */
/** Columnas de `users` que apuntan a otra cuenta. Ver la restauración. */
const REFERENCIAS_ENTRE_CUENTAS = ['company_id', 'donor_id', 'advisor_id'];

const TABLAS_POSTERIORES_A_RESPALDOS_VIEJOS: readonly (typeof BACKUP_TABLES)[number][] = [
  'clients',
];

/**
 * Un valor del JSON, listo para pasarle al driver.
 *
 * Las columnas `jsonb` (`profile`, `new_value` del log) vuelven del `select`
 * como objetos de JavaScript. Pasados tal cual al `insert`, el driver los
 * convierte con `String(...)` y llegan a PostgreSQL como el literal
 * `[object Object]`. Se serializan acá.
 */
function valorParaSql(valor: unknown): unknown {
  if (valor !== null && typeof valor === 'object' && !(valor instanceof Date)) {
    return JSON.stringify(valor);
  }
  return valor;
}

adminRoutes.get('/backup', async (c) => {
  const db = c.get('db');
  const data: Record<string, unknown[]> = {};

  // De `users` sale todo MENOS la contraseña. La lista de columnas se lee de
  // la base y no se escribe a mano: escrita a mano, quedó de antes de
  // `university_id` y `advisor_id`, y restaurar dejaba a todos sin universidad
  // y sin asesor. Una columna que se agregue mañana entra sola.
  const columnasDeUsers = (
    await db.execute<{ column_name: string }>(
      sql`select column_name from information_schema.columns
           where table_schema = 'public' and table_name = 'users'
             and column_name <> 'password_hash'
           order by ordinal_position`,
    )
  ).map((fila) => sql.identifier(fila.column_name));

  for (const table of BACKUP_TABLES) {
    const rows =
      table === 'users'
        ? await db.execute(
            sql`select ${sql.join(columnasDeUsers, sql`, `)} from users`,
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
    // Las contraseñas NO viajan en el archivo —eso es deliberado y correcto:
    // el respaldo termina en el portátil de alguien, y un hash bcrypt se
    // rompe sin prisa y sin conexión—. Pero `password_hash` es `not null`, así
    // que sin ellas el `insert` de `users` fallaba SIEMPRE y, como todo va en
    // una transacción, la restauración entera se caía. La función existía en
    // la interfaz y no había funcionado nunca.
    //
    // Se resuelve conservando los hashes que YA están en esta base, antes de
    // borrar nada, y volviéndolos a poner por id. El archivo sigue sin
    // credenciales y la restauración funciona.
    const hashesActuales = new Map<string, string>();
    for (const fila of await tx.execute<{ id: string; password_hash: string }>(
      sql`select id, password_hash from users`,
    )) {
      hashesActuales.set(fila.id, fila.password_hash);
    }

    // Para una cuenta que está en el respaldo pero ya no en esta base, no hay
    // hash que recuperar. Se le pone uno imposible de adivinar —derivado de
    // bytes aleatorios de esta misma ejecución— en vez de dejarla sin
    // contraseña: la cuenta queda restaurada y visible para administración,
    // pero no se puede entrar a ella hasta que le asignen una nueva.
    const hashInservible = await hashPassword(randomBytes(32).toString('hex'));

    // Las columnas generadas (`glossary_terms.word_key`) las calcula la base:
    // PostgreSQL rechaza cualquier valor que se le quiera escribir, así que se
    // quitan de la fila antes del insert. El respaldo las trae porque sale
    // de un `select *`.
    const generadas = new Set<string>();
    for (const fila of await tx.execute<{ table_name: string; column_name: string }>(
      sql`select table_name, column_name from information_schema.columns
           where table_schema = 'public' and is_generated = 'ALWAYS'`,
    )) {
      generadas.add(`${fila.table_name}.${fila.column_name}`);
    }

    // Una tabla que el archivo no trae porque es de DESPUÉS del respaldo se
    // deja como está. Sin esto, restaurar un respaldo anterior a los clientes
    // los borraba a todos —Enactus incluido, con su logo y sus colores— en vez
    // de dejarlos como estaban.
    const conservar = new Set(
      TABLAS_POSTERIORES_A_RESPALDOS_VIEJOS.filter((t) => !(t in payload.data)),
    );

    // En orden inverso, para no chocar con las claves ajenas.
    for (const table of [...BACKUP_TABLES].reverse()) {
      if (conservar.has(table)) continue;
      await tx.execute(sql`delete from ${sql.identifier(table)}`);
    }
    for (const table of BACKUP_TABLES) {
      if (conservar.has(table)) continue;
      const rows = payload.data[table] ?? [];

      restored[table] = rows.length;
      // Las referencias de una cuenta a otra (su empresa aliada, su donante,
      // su asesor) se ponen DESPUÉS de insertar todas las cuentas. El respaldo
      // las trae en el orden en que estaban guardadas, y PostgreSQL guarda al
      // final cada fila que se edita: insertándolas con la referencia puesta,
      // una cuenta que salía antes que su empresa hacía fallar la clave ajena
      // y, con ella, la restauración entera.
      const referenciasPendientes: { id: unknown; columnas: Record<string, unknown> }[] = [];
      for (const row of rows) {
        let fila =
          table === 'users'
            ? {
                ...row,
                password_hash:
                  hashesActuales.get(String(row.id)) ?? hashInservible,
              }
            : row;
        if (table === 'users') {
          const columnas: Record<string, unknown> = {};
          for (const col of REFERENCIAS_ENTRE_CUENTAS) {
            if (fila[col] !== null && fila[col] !== undefined) {
              columnas[col] = fila[col];
              fila = { ...fila, [col]: null };
            }
          }
          if (Object.keys(columnas).length > 0) {
            referenciasPendientes.push({ id: fila.id, columnas });
          }
        }

        const cols = Object.keys(fila).filter(
          (col) => !generadas.has(`${table}.${col}`),
        );
        if (cols.length === 0) continue;
        const identifiers = sql.join(
          cols.map((col) => sql.identifier(col)),
          sql`, `,
        );
        const values = sql.join(
          cols.map((col) => sql`${valorParaSql(fila[col])}`),
          sql`, `,
        );
        await tx.execute(
          sql`insert into ${sql.identifier(table)} (${identifiers}) values (${values})`,
        );
      }
      for (const { id, columnas } of referenciasPendientes) {
        const asignaciones = sql.join(
          Object.entries(columnas).map(
            ([col, valor]) => sql`${sql.identifier(col)} = ${valorParaSql(valor)}`,
          ),
          sql`, `,
        );
        await tx.execute(sql`update users set ${asignaciones} where id = ${id}`);
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
