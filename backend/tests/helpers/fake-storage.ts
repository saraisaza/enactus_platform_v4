import { AppError } from '../../src/lib/errors';
import type { MediaStorage, UploadedPart } from '../../src/lib/media-storage';

/**
 * S3 en memoria para la subida por partes.
 *
 * Imita lo que importa del de verdad: una subida abierta acumula partes, al
 * completarla las partes se vuelven UN objeto del tamaño de su suma, y una
 * subida cancelada o completada deja de existir (`NoSuchUpload` → 404). Lo
 * que el navegador haría con cada URL firmada lo hace [subirParte].
 */
export class FakeMediaStorage implements MediaStorage {
  readonly objetos = new Map<string, number>();
  readonly subidas = new Map<string, { key: string; partes: Map<number, UploadedPart> }>();
  readonly borrados: string[] = [];
  readonly canceladas: string[] = [];
  /** Keys cuyo borrado falla, para probar los reintentos. */
  readonly borradoFalla = new Set<string>();
  private siguiente = 1;

  configured() {
    return true;
  }

  createMultipartUpload(key: string) {
    const id = `subida-${this.siguiente++}`;
    this.subidas.set(id, { key, partes: new Map() });
    return Promise.resolve(id);
  }

  signUploadPart(key: string, uploadId: string, partNumber: number, sizeBytes: number) {
    return Promise.resolve(
      `https://s3.prueba/${key}?uploadId=${uploadId}&partNumber=${partNumber}&size=${sizeBytes}`,
    );
  }

  /** El `PUT` del navegador contra la URL de una parte. */
  subirParte(uploadId: string, partNumber: number, sizeBytes: number) {
    const subida = this.subidas.get(uploadId);
    if (!subida) throw new Error(`no existe la subida ${uploadId}`);
    subida.partes.set(partNumber, { partNumber, sizeBytes, etag: `"etag-${partNumber}"` });
  }

  private subida(key: string, uploadId: string) {
    const subida = this.subidas.get(uploadId);
    if (!subida || subida.key !== key) {
      throw new AppError(404, 'upload_not_found', 'Esa subida ya no existe.');
    }
    return subida;
  }

  listParts(key: string, uploadId: string) {
    try {
      return Promise.resolve([...this.subida(key, uploadId).partes.values()]);
    } catch (error) {
      return Promise.reject(error instanceof Error ? error : new Error(String(error)));
    }
  }

  completeMultipartUpload(
    key: string,
    uploadId: string,
    parts: { partNumber: number; etag: string }[],
  ) {
    try {
      const subida = this.subida(key, uploadId);
      let total = 0;
      for (const p of parts) total += subida.partes.get(p.partNumber)?.sizeBytes ?? 0;
      this.objetos.set(key, total);
      this.subidas.delete(uploadId);
      return Promise.resolve();
    } catch (error) {
      return Promise.reject(error instanceof Error ? error : new Error(String(error)));
    }
  }

  abortMultipartUpload(_key: string, uploadId: string) {
    this.canceladas.push(uploadId);
    this.subidas.delete(uploadId);
    return Promise.resolve();
  }

  objectSize(key: string) {
    return Promise.resolve(this.objetos.get(key) ?? null);
  }

  /** El contenido de los objetos subidos con [subirArchivo]. */
  readonly contenidos = new Map<string, Uint8Array>();

  readObjectStart(key: string, bytes: number) {
    if (!this.objetos.has(key)) return Promise.resolve(null);
    return Promise.resolve((this.contenidos.get(key) ?? new Uint8Array()).slice(0, bytes));
  }

  signPutObject(key: string, contentType: string, sizeBytes: number) {
    return Promise.resolve(
      `https://s3.prueba/${key}?put=1&type=${encodeURIComponent(contentType)}&size=${sizeBytes}`,
    );
  }

  /** El `PUT` simple de la portada. */
  subirObjeto(key: string, sizeBytes: number) {
    this.objetos.set(key, sizeBytes);
  }

  /** Un `PUT` con contenido de verdad: lo que el servidor después inspecciona. */
  subirArchivo(key: string, contenido: Uint8Array) {
    this.objetos.set(key, contenido.length);
    this.contenidos.set(key, contenido);
  }

  deleteObjects(keys: string[]) {
    const deleted: string[] = [];
    const failed: { key: string; error: string }[] = [];
    for (const key of keys) {
      if (this.borradoFalla.has(key)) {
        failed.push({ key, error: 'AccessDenied: sin permiso' });
        continue;
      }
      this.objetos.delete(key);
      this.borrados.push(key);
      deleted.push(key);
    }
    return Promise.resolve({ deleted, failed });
  }
}
