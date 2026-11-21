import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Quitar UN archivo de una entrega (recomendaciones del 20 de noviembre).
 *
 * Quien se equivocaba de archivo solo podía borrar la entrega entera. Ahora
 * quita el que sobra, con las mismas reglas de borrar la entrega: solo la
 * suya y solo mientras nadie la haya calificado ni comentado.
 */

let t: ReturnType<typeof makeTestApp>;
const tok: Record<string, string> = {};
const CURSO_IA = seedId('crs_ia_1'); // lo cursa est1

interface Archivo {
  id: string;
  fileName: string;
}
interface Entrega {
  id: string;
  files: Archivo[];
}

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

const archivo = (nombre: string) => ({
  s3Key: `submissions/prueba-quitar-${nombre}-${Date.now()}-${Math.random()}`,
  fileName: nombre,
  contentType: 'application/pdf',
  sizeBytes: 1024,
});

async function entregar(nombres: string[], comentario = ''): Promise<Entrega> {
  const res = await pedir('/submissions', 'POST', tok.est1!, {
    courseId: CURSO_IA,
    taskName: 'Entrega libre',
    comment: comentario,
    files: nombres.map(archivo),
  });
  expect(res.status, await res.clone().text()).toBe(201);
  const { id } = (await res.json()) as { id: string };
  return laEntrega(id);
}

async function laEntrega(id: string): Promise<Entrega> {
  const res = await pedir('/submissions?pageSize=100', 'GET', tok.est1!);
  const { data } = (await res.json()) as { data: Entrega[] };
  return data.find((e) => e.id === id)!;
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  for (const [clave, correo, clave2] of [
    ['est1', 'estudiante1@uniandes.edu.co', 'Est123'],
    ['est3', 'estudiante3@unal.edu.co', 'Est123'],
    ['admin', 'admin@enactus.co', 'Admin123'],
  ] as const) {
    tok[clave] = (await login(t.app, correo, clave2)).accessToken;
  }
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await t.sql.end();
});

describe('DELETE /submissions/:id/files/:fileId', () => {
  it('quien entregó quita el archivo que sobra; el otro queda', async () => {
    const entrega = await entregar(['bien.pdf', 'equivocado.pdf']);
    const sobra = entrega.files.find((f) => f.fileName === 'equivocado.pdf')!;
    const res = await pedir(
      `/submissions/${entrega.id}/files/${sobra.id}`, 'DELETE', tok.est1!);
    expect(res.status, await res.clone().text()).toBe(204);
    const despues = await laEntrega(entrega.id);
    expect(despues.files.map((f) => f.fileName)).toEqual(['bien.pdf']);
  });

  it('nadie más puede quitarle archivos', async () => {
    const entrega = await entregar(['a.pdf', 'b.pdf']);
    const res = await pedir(
      `/submissions/${entrega.id}/files/${entrega.files[0]!.id}`, 'DELETE', tok.est3!);
    expect(res.status).toBe(403);
  });

  it('una vez comentada, ya no se toca', async () => {
    const entrega = await entregar(['a.pdf', 'b.pdf']);
    await t.sql`update submissions set feedback = 'Bien' where id = ${entrega.id}`;
    const res = await pedir(
      `/submissions/${entrega.id}/files/${entrega.files[0]!.id}`, 'DELETE', tok.est1!);
    expect(res.status).toBe(409);
  });

  it('no deja una entrega vacía', async () => {
    const entrega = await entregar(['solo.pdf']);
    const res = await pedir(
      `/submissions/${entrega.id}/files/${entrega.files[0]!.id}`, 'DELETE', tok.est1!);
    expect(res.status).toBe(409);
    // Con comentario sí: la entrega sigue diciendo algo.
    const conTexto = await entregar(['solo.pdf'], 'Mi respuesta, por escrito.');
    const ok = await pedir(
      `/submissions/${conTexto.id}/files/${conTexto.files[0]!.id}`, 'DELETE', tok.est1!);
    expect(ok.status).toBe(204);
  });

  it('un archivo de otra entrega no se confunde', async () => {
    const una = await entregar(['a.pdf', 'b.pdf']);
    const otra = await entregar(['c.pdf', 'd.pdf']);
    const res = await pedir(
      `/submissions/${una.id}/files/${otra.files[0]!.id}`, 'DELETE', tok.est1!);
    expect(res.status).toBe(404);
  });
});
