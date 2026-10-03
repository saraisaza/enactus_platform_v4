import { spawnSync } from 'node:child_process';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

/**
 * `scripts/csp-video.mjs` reescribe la CSP del frontend de producción. Un
 * error ahí no rompe ninguna prueba de la API: deja el sitio en blanco, como
 * en septiembre (ver BLOQUEOS_INFRA.md). Se prueba como lo usa
 * `infra/video-subido.sh`: por la línea de comandos, con lo que devuelve
 * `aws cloudfront get-response-headers-policy-config`.
 */
const SCRIPT = join(__dirname, '../scripts/csp-video.mjs');

function correr(entrada: string, ...args: string[]) {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], {
    input: entrada,
    encoding: 'utf8',
  });
  return { codigo: r.status, salida: r.stdout, avisos: r.stderr };
}

const configCon = (csp: string) =>
  JSON.stringify({
    ETag: 'E2ABC',
    ResponseHeadersPolicyConfig: {
      Name: 'enactus-web-seguridad',
      SecurityHeadersConfig: {
        ContentSecurityPolicy: { Override: true, ContentSecurityPolicy: csp },
        StrictTransportSecurity: { Override: true, AccessControlMaxAgeSec: 63072000 },
      },
    },
  });

interface Config {
  Name: string;
  SecurityHeadersConfig: {
    ContentSecurityPolicy: { Override: boolean; ContentSecurityPolicy: string };
    StrictTransportSecurity: unknown;
  };
}
const leerConfig = (salida: string) => JSON.parse(salida) as Config;
const directivas = (csp: string) => csp.split(';').map((d) => d.trim());

// La forma de la CSP de producción: default-src 'self' y sin media-src.
const PRODUCCION = [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval' blob: https://www.youtube.com 'sha256-mWFg57gl8GJ7fzq2EpNugYZ+DmaKVteJFmNmucj0+9w='",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob: https://i.ytimg.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "connect-src 'self' https://api.eduxaction.com https://enactus-media-dev.s3.us-east-1.amazonaws.com https://fonts.gstatic.com",
  'frame-src https://www.youtube-nocookie.com',
  "object-src 'none'",
  "frame-ancestors 'none'",
].join('; ');

describe('csp-video.mjs sobre la política de CloudFront', () => {
  it('agrega el CDN y blob: sin tocar ninguna otra directiva', () => {
    const r = correr(configCon(PRODUCCION));
    expect(r.codigo).toBe(0);

    const csp = leerConfig(r.salida).SecurityHeadersConfig.ContentSecurityPolicy
      .ContentSecurityPolicy;
    const nuevas = directivas(csp);
    // media-src no existía: hereda lo de default-src y suma lo del video.
    expect(nuevas).toContain("media-src 'self' https://videos.eduxaction.com blob:");
    expect(nuevas).toContain(
      "img-src 'self' data: blob: https://i.ytimg.com https://videos.eduxaction.com",
    );
    // Todo lo demás, letra por letra; img-src es la única que cambió.
    for (const d of directivas(PRODUCCION)) {
      if (d.startsWith('img-src')) continue;
      expect(nuevas).toContain(d);
    }
    expect(nuevas).toHaveLength(directivas(PRODUCCION).length + 1);
  });

  it('devuelve solo la configuración, que es lo que acepta update-response-headers-policy', () => {
    const r = correr(configCon(PRODUCCION));
    const config = leerConfig(r.salida);
    expect(Object.keys(config)).toEqual(['Name', 'SecurityHeadersConfig']);
    expect(config.SecurityHeadersConfig.StrictTransportSecurity).toEqual({
      Override: true,
      AccessControlMaxAgeSec: 63072000,
    });
  });

  it('correrlo dos veces no cambia nada la segunda', () => {
    const primera = leerConfig(correr(configCon(PRODUCCION)).salida);
    const segunda = correr(
      JSON.stringify({ ETag: 'E3', ResponseHeadersPolicyConfig: primera }),
    );
    expect(segunda.codigo).toBe(3);
    expect(segunda.salida).toBe('');
  });

  it('no repite lo que un comodín ya deja pasar', () => {
    const r = correr(
      configCon(
        "default-src 'none'; img-src https:; media-src https://*.eduxaction.com blob:; connect-src *",
      ),
    );
    expect(r.codigo).toBe(3);
  });

  it("saca 'none' de la directiva a la que le agrega fuentes", () => {
    const r = correr(configCon("default-src 'self'; media-src 'none'; img-src *; connect-src *"));
    const csp = leerConfig(r.salida).SecurityHeadersConfig.ContentSecurityPolicy
      .ContentSecurityPolicy;
    expect(directivas(csp)).toContain('media-src https://videos.eduxaction.com blob:');
  });

  it('se niega si la CSP pasaría el tope de CloudFront', () => {
    const larga = `${PRODUCCION}; script-src-elem ${"'sha256-x' ".repeat(170)}`;
    const r = correr(configCon(larga));
    expect(r.codigo).toBe(1);
    expect(r.salida).toBe('');
    expect(r.avisos).toMatch(/1783/);
  });

  it('se niega si la política no tiene CSP', () => {
    const r = correr(JSON.stringify({ ResponseHeadersPolicyConfig: { SecurityHeadersConfig: {} } }));
    expect(r.codigo).toBe(1);
    expect(r.salida).toBe('');
  });
});

describe('csp-video.mjs --revisar, sobre la cabecera que llega al navegador', () => {
  it('dice exactamente qué falta', () => {
    const r = correr(PRODUCCION, '--revisar');
    expect(r.codigo).toBe(3);
    expect(r.avisos.trim().split('\n')).toEqual([
      'falta media-src https://videos.eduxaction.com',
      'falta media-src blob:',
      'falta img-src https://videos.eduxaction.com',
    ]);
  });

  it('sale con 0 cuando ya está todo', () => {
    const lista = leerConfig(correr(configCon(PRODUCCION)).salida).SecurityHeadersConfig
      .ContentSecurityPolicy.ContentSecurityPolicy;
    expect(correr(lista, '--revisar').codigo).toBe(0);
  });
});
