import { index, integer, pgTable, text, timestamp } from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';

/**
 * Archivos de S3 que ya nadie referencia y hay que borrar.
 *
 * **La anota un trigger de la base, no la aplicación** (migración 0008), y es
 * a propósito, aunque el resto del esquema evite los triggers. Borrar un
 * módulo se lleva sus lecciones en cascada sin que esas filas pasen por el
 * código: un trigger es lo único que las ve. Dispara al borrar una lección o
 * al cambiarle el video o la portada, y solo anota keys de `lessons/`, las
 * que genera la subida — nunca las del seed, que staging y producción
 * comparten en el mismo bucket.
 *
 * El borrado en S3 lo hace la API después de confirmar el cambio
 * (`services/storage-cleanup.ts`), y antes de borrar comprueba que la key no
 * esté referenciada de nuevo: restaurar un respaldo borra y reinserta
 * `lessons` entera, y sin esa comprobación se llevaría todos los videos.
 *
 * No va en el respaldo de `/admin/backup`: es una cola de trabajo pendiente,
 * no datos.
 */
export const storagePendingDeletes = pgTable(
  'storage_pending_deletes',
  {
    key: text().primaryKey(),
    /** `lesson_deleted`, `video_replaced` o `thumbnail_replaced`. */
    reason: text().notNull(),
    attempts: integer().notNull().default(0),
    lastError: text(),
    lastAttemptAt: timestamp({ withTimezone: true }),
    ...timestamps,
  },
  (t) => [index('storage_pending_deletes_created_at_idx').on(t.createdAt)],
);
