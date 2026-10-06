import { asc, eq, inArray, or, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { clients, courses, lessons, storagePendingDeletes } from '../db/schema';
import { mediaStorage } from '../lib/media-storage';

/**
 * Borra de S3 los archivos que la base anotó como huérfanos.
 *
 * La cola la llena el trigger de `lessons` (migración 0008): al borrar una
 * lección —también en cascada— o al reemplazarle el video o la portada. Acá
 * se vacía, DESPUÉS de confirmar el cambio: si el borrado fuera antes y la
 * escritura fallara, la lección quedaría apuntando a un archivo que ya no
 * existe.
 *
 * **Nunca hace fallar el pedido que la llama.** Si S3 no responde, las keys
 * quedan en la cola con el error y se reintentan en el siguiente cambio de
 * video. Un archivo que sobra un rato más es un costo; una lección que no se
 * puede guardar porque S3 tardó, un problema.
 *
 * **Antes de borrar, comprueba que nadie haya vuelto a referenciar la key.**
 * Restaurar un respaldo borra y reinserta `lessons` entera: el trigger anota
 * todos los videos, y sin esta comprobación se borrarían los archivos de las
 * lecciones recién restauradas.
 */
export async function drainStorageDeletes(
  db: Database,
  { limit = 25 }: { limit?: number } = {},
): Promise<{ deleted: number; failed: number; stillInUse: number }> {
  const resultado = { deleted: 0, failed: 0, stillInUse: 0 };
  const storage = mediaStorage();
  if (!storage.configured()) return resultado;

  try {
    const pendientes = await db
      .select({ key: storagePendingDeletes.key })
      .from(storagePendingDeletes)
      .orderBy(asc(storagePendingDeletes.createdAt))
      .limit(limit);
    if (pendientes.length === 0) return resultado;
    const keys = pendientes.map((p) => p.key);

    const enUso = new Set<string>();
    const deLecciones = await db
      .select({ video: lessons.videoS3Key, portada: lessons.videoThumbnailS3Key })
      .from(lessons)
      .where(
        or(inArray(lessons.videoS3Key, keys), inArray(lessons.videoThumbnailS3Key, keys)),
      );
    for (const fila of deLecciones) {
      if (fila.video) enUso.add(fila.video);
      if (fila.portada) enUso.add(fila.portada);
    }
    const deCursos = await db
      .select({ video: courses.introVideoS3Key })
      .from(courses)
      .where(inArray(courses.introVideoS3Key, keys));
    for (const fila of deCursos) if (fila.video) enUso.add(fila.video);
    const deClientes = await db
      .select({ logo: clients.logoS3Key })
      .from(clients)
      .where(inArray(clients.logoS3Key, keys));
    for (const fila of deClientes) if (fila.logo) enUso.add(fila.logo);

    const siguenEnUso = keys.filter((k) => enUso.has(k));
    if (siguenEnUso.length > 0) {
      await db
        .delete(storagePendingDeletes)
        .where(inArray(storagePendingDeletes.key, siguenEnUso));
      resultado.stillInUse = siguenEnUso.length;
    }

    const borrar = keys.filter((k) => !enUso.has(k));
    if (borrar.length === 0) return resultado;

    let respuesta: Awaited<ReturnType<typeof storage.deleteObjects>>;
    try {
      respuesta = await storage.deleteObjects(borrar);
    } catch (error) {
      const mensaje = error instanceof Error ? error.message : String(error);
      respuesta = { deleted: [], failed: borrar.map((key) => ({ key, error: mensaje })) };
    }

    if (respuesta.deleted.length > 0) {
      await db
        .delete(storagePendingDeletes)
        .where(inArray(storagePendingDeletes.key, respuesta.deleted));
    }
    for (const fallo of respuesta.failed) {
      await db
        .update(storagePendingDeletes)
        .set({
          attempts: sql`${storagePendingDeletes.attempts} + 1`,
          lastError: fallo.error.slice(0, 500),
          lastAttemptAt: new Date(),
          updatedAt: new Date(),
        })
        .where(eq(storagePendingDeletes.key, fallo.key));
    }
    resultado.deleted = respuesta.deleted.length;
    resultado.failed = respuesta.failed.length;
    if (resultado.failed > 0) {
      console.error('[borrado de archivos] S3 no borró', respuesta.failed);
    }
    return resultado;
  } catch (error) {
    console.error('[borrado de archivos] no se pudo vaciar la cola', error);
    return resultado;
  }
}
