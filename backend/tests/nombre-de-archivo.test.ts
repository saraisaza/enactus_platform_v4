import { describe, expect, it } from 'vitest';

import { contentDisposition } from '../src/lib/s3';

/**
 * El «Error 400 al ver un archivo» (recomendaciones del 20 de noviembre).
 *
 * S3 solo acepta en `response-content-disposition` caracteres de ISO-8859-1.
 * Un nombre de archivo que trae otra cosa —las tildes como las guarda un Mac
 * (la letra y el acento por separado, U+0301), una comilla tipográfica, un
 * guion largo, un emoji— hacía que S3 respondiera 400 en vez del archivo.
 */
const soloAscii = (s: string) => /^[\x20-\x7e]*$/.test(s);

describe('contentDisposition', () => {
  it('un nombre con tildes de Mac (NFD) sale en ASCII puro', () => {
    const deMac = 'Presentación Sara Muñoz.pdf'.normalize('NFD');
    expect(deMac).not.toBe('Presentación Sara Muñoz.pdf'); // de verdad es NFD
    const valor = contentDisposition(deMac);
    expect(soloAscii(valor), valor).toBe(true);
    expect(valor).toContain('filename="Presentacion Sara Munoz.pdf"');
    // El nombre real viaja codificado, para que se descargue con sus tildes.
    expect(decodeURIComponent(valor.split("filename*=UTF-8''")[1]!)).toBe(deMac);
  });

  it('comillas tipográficas, guiones largos y emojis tampoco rompen', () => {
    for (const nombre of ['Informe “final” – v2.pdf', 'foto 📸.png', 'año’s.docx']) {
      expect(soloAscii(contentDisposition(nombre)), nombre).toBe(true);
    }
  });

  it('las comillas y los saltos de línea no se cuelan en el encabezado', () => {
    const valor = contentDisposition('a"b\r\nSet-Cookie: x.pdf');
    expect(valor).not.toMatch(/[\r\n]/);
    expect(valor.split('"').length).toBe(3); // solo las dos del filename
  });

  it('un nombre vacío se llama «archivo»', () => {
    expect(contentDisposition('  ')).toContain('filename="archivo"');
  });
});
