import type { Context } from 'hono';

import { MENSAJES_EN } from './mensajes';

/**
 * Idioma de las respuestas del servidor: el de la interfaz de quien llama.
 *
 * La app manda `Accept-Language: es` o `Accept-Language: en` en cada pedido
 * (el idioma que la persona eligió en el selector). El servidor solo traduce
 * sus propios mensajes —errores y avisos—; los datos que escriben las
 * personas salen siempre tal como se escribieron.
 */
export type Idioma = 'es' | 'en';

/**
 * El idioma que pide la cabecera `Accept-Language`.
 *
 * Solo cuenta el primero de la lista, igual que en la app: «en-US,en;q=0.9»
 * es inglés; «fr-FR,en;q=0.8» es español, que es el idioma por defecto.
 * Sin cabecera, español: así responde hoy a cualquier cliente que no la
 * mande, incluida una versión vieja de la app.
 */
export function idiomaDe(c: Context): Idioma {
  const cabecera = c.req.header('accept-language') ?? '';
  const primero = cabecera.split(',')[0]?.trim().toLowerCase() ?? '';
  return primero.startsWith('en') ? 'en' : 'es';
}

const exactos = new Map<string, string>();
const conPartes: { patron: RegExp; en: string }[] = [];

for (const [es, en] of MENSAJES_EN) {
  if (/\{\d+\}/.test(es)) {
    const escapado = es.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const patron = escapado.replace(/\\\{(\d+)\\\}/g, '(?<p$1>[\\s\\S]+?)');
    conPartes.push({ patron: new RegExp(`^${patron}$`), en });
  } else {
    exactos.set(es, en);
  }
}

/**
 * Un mensaje del servidor en el idioma pedido.
 *
 * En español, el mensaje tal cual. En inglés, su par del catálogo; si es un
 * mensaje con partes que cambian («La nota debe estar entre 0 y 5…»), se
 * reconoce por su forma y las partes se copian a la traducción. Un mensaje que
 * no está en el catálogo sale en español antes que vacío —la prueba de
 * `idiomas.test.ts` existe para que eso no pase—.
 */
export function traducir(mensaje: string, idioma: Idioma): string {
  if (idioma === 'es') return mensaje;
  const exacto = exactos.get(mensaje);
  if (exacto !== undefined) return exacto;
  for (const { patron, en } of conPartes) {
    const m = patron.exec(mensaje);
    if (m?.groups) {
      const partes = m.groups;
      return en.replace(/\{(\d+)\}/g, (_, d: string) => partes[`p${d}`] ?? '');
    }
  }
  return mensaje;
}
