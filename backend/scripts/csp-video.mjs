// Agrega a la CSP del frontend lo que necesita el video subido de las
// lecciones, sin tocar nada más. Lo usa `infra/video-subido.sh`.
//
//   node csp-video.mjs < config.json > nueva.json
//     config.json es la salida de
//     `aws cloudfront get-response-headers-policy-config --id <id>`.
//     Escribe la configuración nueva (lo que espera
//     `update-response-headers-policy`) y cuenta en stderr qué cambió.
//
//   node csp-video.mjs --revisar < csp.txt
//     csp.txt es el valor de la cabecera tal como llega al navegador.
//     Solo dice qué falta.
//
// Sale con 0 si hay algo que cambiar (o, con --revisar, si no falta nada), con
// 3 si no hay nada que cambiar (o si falta algo) y con 1 ante un error.

import { readFileSync } from 'node:fs';

/** Lo que el navegador pide, directiva por directiva. */
export const NECESARIO = {
  // El reproductor (`<video>` con la URL firmada de CloudFront) y la vista
  // previa del editor, que reproduce el archivo elegido con una URL `blob:`.
  // La miniatura automática también sale de un `<video>` con esa URL.
  'media-src': ['https://videos.eduxaction.com', 'blob:'],
  // La portada del video, que es un `<img>` con la URL firmada.
  'img-src': ['https://videos.eduxaction.com'],
  // Las partes del video viajan con `PUT` directo al bucket. Las subidas de
  // siempre ya lo usan, así que casi seguro ya está.
  'connect-src': ['https://enactus-media-dev.s3.us-east-1.amazonaws.com'],
};

/** Tope de CloudFront para el valor de la CSP en una política de cabeceras. */
export const MAXIMO_CLOUDFRONT = 1783;

export function leer(csp) {
  return csp
    .split(';')
    .map((d) => d.trim())
    .filter(Boolean)
    .map((d) => {
      const [nombre, ...fuentes] = d.split(/\s+/);
      return { nombre: nombre.toLowerCase(), fuentes };
    });
}

export function escribir(directivas) {
  return directivas.map((d) => [d.nombre, ...d.fuentes].join(' ')).join('; ');
}

/** ¿`fuente` ya deja pasar `pedida`? Cubre los comodines que se usan de verdad. */
export function cubre(fuente, pedida) {
  const f = fuente.toLowerCase().replace(/\/$/, '');
  const p = pedida.toLowerCase().replace(/\/$/, '');
  if (f === p) return true;
  if (p === 'blob:') return false; // ni `*` ni `https:` dejan pasar blob:
  if (f === '*' || f === 'https:') return p.startsWith('https://');
  const comodin = /^https:\/\/\*\.(.+)$/.exec(f);
  if (comodin) return p.startsWith('https://') && p.endsWith('.' + comodin[1]);
  return false;
}

/**
 * Devuelve la CSP con lo que falte agregado y la lista de cambios.
 *
 * Una directiva que no existe hereda de `default-src`: al crearla se copian
 * esas fuentes primero, para que lo que hoy pasa por herencia siga pasando.
 */
export function agregar(csp) {
  const directivas = leer(csp);
  const porDefecto = directivas.find((d) => d.nombre === 'default-src');
  const cambios = [];
  for (const [nombre, pedidas] of Object.entries(NECESARIO)) {
    let d = directivas.find((x) => x.nombre === nombre);
    if (!d) {
      const heredadas = (porDefecto?.fuentes ?? []).filter((f) => f !== "'none'");
      d = { nombre, fuentes: [...heredadas] };
      directivas.push(d);
      cambios.push(`${nombre}: no existía; se crea con lo de default-src (${heredadas.join(' ') || 'nada'})`);
    }
    for (const pedida of pedidas) {
      if (d.fuentes.some((f) => cubre(f, pedida))) continue;
      d.fuentes = d.fuentes.filter((f) => f !== "'none'");
      d.fuentes.push(pedida);
      cambios.push(`${nombre}: + ${pedida}`);
    }
  }
  return { csp: escribir(directivas), cambios };
}

export function faltantes(csp) {
  const directivas = leer(csp);
  const porDefecto = directivas.find((d) => d.nombre === 'default-src');
  const faltan = [];
  for (const [nombre, pedidas] of Object.entries(NECESARIO)) {
    const d = directivas.find((x) => x.nombre === nombre) ?? porDefecto;
    for (const pedida of pedidas) {
      if (!d?.fuentes.some((f) => cubre(f, pedida))) faltan.push(`${nombre} ${pedida}`);
    }
  }
  return faltan;
}

function principal() {
  const entrada = readFileSync(0, 'utf8');

  if (process.argv.includes('--revisar')) {
    const faltan = faltantes(entrada.trim());
    for (const f of faltan) console.error(`falta ${f}`);
    process.exit(faltan.length ? 3 : 0);
  }

  const config = JSON.parse(entrada).ResponseHeadersPolicyConfig;
  const politica = config?.SecurityHeadersConfig?.ContentSecurityPolicy;
  if (!politica?.ContentSecurityPolicy) {
    console.error('esta política de cabeceras no tiene CSP; no se toca');
    process.exit(1);
  }
  const { csp, cambios } = agregar(politica.ContentSecurityPolicy);
  if (cambios.length === 0) {
    console.error('la CSP ya tiene todo');
    process.exit(3);
  }
  if (csp.length > MAXIMO_CLOUDFRONT) {
    console.error(
      `la CSP quedaría de ${csp.length} caracteres y CloudFront acepta ` +
        `${MAXIMO_CLOUDFRONT}: hay que acortarla a mano antes`,
    );
    process.exit(1);
  }
  for (const c of cambios) console.error(c);
  politica.ContentSecurityPolicy = csp;
  process.stdout.write(JSON.stringify(config, null, 2) + '\n');
  process.exit(0);
}

if (import.meta.url === `file://${process.argv[1]}`) principal();
