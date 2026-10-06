/**
 * Lo mínimo para reconocer un PNG de verdad y saber cuánto mide.
 *
 * El navegador declara el tipo de un archivo por su extensión: un `.png` que
 * en realidad es un JPG, un PDF o cualquier otra cosa llega diciendo
 * `image/png`. Por eso el servidor no se fía del tipo declarado y mira los
 * primeros bytes del archivo ya subido.
 *
 * Todo PNG empieza con la misma firma de 8 bytes y, enseguida, con el bloque
 * `IHDR`, que trae el ancho y el alto. 24 bytes alcanzan para las dos cosas.
 */

/** Cuántos bytes hay que leer del principio del archivo. */
export const BYTES_PARA_RECONOCER_PNG = 24;

const FIRMA_PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** Ancho y alto del PNG, o `null` si los bytes no son de un PNG. */
export function medidasDePng(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (bytes.length < BYTES_PARA_RECONOCER_PNG) return null;
  for (let i = 0; i < FIRMA_PNG.length; i++) {
    if (bytes[i] !== FIRMA_PNG[i]) return null;
  }
  // Bytes 8–11: largo del bloque; 12–15: su nombre, que tiene que ser IHDR.
  const nombre = String.fromCharCode(bytes[12]!, bytes[13]!, bytes[14]!, bytes[15]!);
  if (nombre !== 'IHDR') return null;
  const vista = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const width = vista.getUint32(16);
  const height = vista.getUint32(20);
  if (width === 0 || height === 0) return null;
  return { width, height };
}
