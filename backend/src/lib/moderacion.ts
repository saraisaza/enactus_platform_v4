/**
 * Filtro de lenguaje del foro.
 *
 * App Store (guía 1.2) pide, para una app donde las personas publican, «un
 * método para filtrar el material ofensivo antes de que se publique». Este es
 * ese método, y es deliberadamente modesto: una lista corta de insultos,
 * groserías y expresiones de odio inequívocas. No pretende atraparlo todo
 * —para eso están los reportes y la moderación—, sino que lo más burdo no
 * llegue a publicarse.
 *
 * Por qué una lista corta y no una larga: cada palabra de más es una
 * publicación legítima rechazada. Quedan fuera a propósito palabras que en
 * Colombia tienen un uso corriente además del ofensivo («chimba», «zorra»,
 * «perra», «retrasado», «gonorrea» —un proyecto de salud sexual tiene que
 * poder nombrarla—).
 *
 * Se compara por palabra completa, sin tildes ni mayúsculas: «MALPARIDO» y
 * «malparído» caen; «computador» y «disputa» no.
 */

/** Ya normalizadas: minúsculas y sin tildes (ver [normalizar]). */
const PALABRAS_NO_PERMITIDAS = new Set([
  // Insultos y groserías.
  'hijueputa',
  'hijueputas',
  'hijodeputa',
  'hdp',
  'malparido',
  'malparida',
  'malparidos',
  'malparidas',
  'puta',
  'putas',
  'puto',
  'putos',
  'pirobo',
  'piroba',
  'pirobos',
  'pirobas',
  'careverga',
  'carechimba',
  'mierda',
  'mierdas',
  'imbecil',
  'imbeciles',
  'fuck',
  'fucking',
  'motherfucker',
  'bitch',
  // Expresiones de odio.
  'marica',
  'maricas',
  'maricon',
  'maricones',
  'mongolico',
  'mongolica',
  'subnormal',
  'sudaca',
  'sudacas',
  'veneco',
  'veneca',
  'venecos',
  'venecas',
  'faggot',
  'nigger',
]);

/** Minúsculas y sin tildes; la «ñ» queda como «n», igual que en la lista. */
export function normalizar(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

/** `true` si el texto tiene alguna palabra de la lista. */
export function tieneLenguajeNoPermitido(texto: string): boolean {
  return normalizar(texto)
    .split(/[^a-z0-9]+/)
    .some((palabra) => PALABRAS_NO_PERMITIDAS.has(palabra));
}

export const MENSAJE_LENGUAJE_NO_PERMITIDO =
  'Su mensaje tiene lenguaje que no está permitido en el foro. Revise las ' +
  'normas de la comunidad y vuelva a intentarlo.';
