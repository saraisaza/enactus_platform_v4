import { createHash } from 'node:crypto';

/**
 * UUID determinístico a partir de la clave que la entidad tenía en Hive
 * (`est1`, `lab_ia`, `crs_ia_1`, …).
 *
 * Sirve para dos cosas:
 * - El seed es reproducible: `db:reset` dos veces da exactamente los mismos
 *   ids, así que una URL o un test escrito ayer sigue valiendo hoy.
 * - Las pruebas pueden apuntar a una entidad por su nombre de siempre
 *   (`seedId('est1')`) en vez de arrastrar ids sueltos.
 *
 * Es un UUID v5 sobre SHA-1, igual que `uuid.v5`, sin agregar la dependencia
 * por seis líneas de código.
 */
const NAMESPACE = '6e6f6465-0000-0000-0000-656e61637475'; // "node…enactu"

export function seedId(key: string): string {
  const namespaceBytes = Buffer.from(NAMESPACE.replace(/-/g, ''), 'hex');
  const hash = createHash('sha1')
    .update(namespaceBytes)
    .update(key)
    .digest();

  // Bits de versión (5) y variante (RFC 4122), como manda la especificación.
  hash[6] = (hash[6]! & 0x0f) | 0x50;
  hash[8] = (hash[8]! & 0x3f) | 0x80;

  const hex = hash.subarray(0, 16).toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}
