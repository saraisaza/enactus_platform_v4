import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import { describe, expect, it } from 'vitest';

import { makeTestApp } from './helpers/app';

/**
 * El OpenAPI tiene que describir la API que existe, no la que existía.
 *
 * Esta prueba compara el documento contra las rutas realmente registradas en
 * Hono, así que agregar un endpoint sin documentarlo rompe la suite. Sin
 * esto, un archivo de especificación envejece en silencio y termina mintiendo.
 */

interface OpenApiDoc {
  openapi: string;
  info: { title: string; version: string };
  paths: Record<string, Record<string, unknown>>;
  components: { schemas: Record<string, unknown> };
}

const doc = parse(readFileSync('openapi.yaml', 'utf8')) as OpenApiDoc;

/** `/courses/:id` (Hono) → `/courses/{id}` (OpenAPI). */
const toOpenApiPath = (path: string) =>
  path.replace(/:([A-Za-z0-9_]+)/g, '{$1}').replace(/\/$/, '') || '/';

describe('openapi.yaml', () => {
  it('es un documento OpenAPI 3.1 válido en su estructura básica', () => {
    expect(doc.openapi).toMatch(/^3\.1/);
    expect(doc.info.title).toBeTruthy();
    expect(Object.keys(doc.paths).length).toBeGreaterThan(30);
  });

  it('documenta TODAS las rutas registradas en la aplicación', () => {
    const { app } = makeTestApp();

    const registradas = new Set<string>();
    for (const route of app.routes) {
      // Los middlewares se registran como ALL sobre comodines: no son
      // endpoints y no se documentan.
      if (route.method === 'ALL' || route.path.includes('*')) continue;
      registradas.add(`${route.method} ${toOpenApiPath(route.path)}`);
    }

    const documentadas = new Set<string>();
    for (const [path, methods] of Object.entries(doc.paths)) {
      for (const method of Object.keys(methods)) {
        if (method === 'parameters') continue;
        documentadas.add(`${method.toUpperCase()} ${path}`);
      }
    }

    const sinDocumentar = [...registradas].filter((r) => !documentadas.has(r)).sort();
    const documentadasDeMas = [...documentadas].filter((d) => !registradas.has(d)).sort();

    expect(sinDocumentar, 'endpoints sin documentar en openapi.yaml').toEqual([]);
    expect(documentadasDeMas, 'documentados pero inexistentes').toEqual([]);
  });

  it('todos los $ref apuntan a algo que existe', () => {
    const refs: string[] = [];
    const walk = (node: unknown): void => {
      if (Array.isArray(node)) return node.forEach(walk);
      if (node && typeof node === 'object') {
        for (const [key, value] of Object.entries(node)) {
          if (key === '$ref' && typeof value === 'string') refs.push(value);
          else walk(value);
        }
      }
    };
    walk(doc);

    const rotos = refs.filter((ref) => {
      const segments = ref.replace(/^#\//, '').split('/');
      let node: unknown = doc;
      for (const segment of segments) {
        if (!node || typeof node !== 'object') return true;
        node = (node as Record<string, unknown>)[segment];
      }
      return node === undefined;
    });

    expect([...new Set(rotos)]).toEqual([]);
  });
});
