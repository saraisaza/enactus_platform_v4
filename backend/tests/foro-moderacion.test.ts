import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { tieneLenguajeNoPermitido } from '../src/lib/moderacion';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Moderación del foro: lo que App Store exige (guía 1.2) para publicar una
 * app donde las personas publican.
 *
 * Las cuatro piezas de la guía, cada una con lo que una persona espera de
 * ella y no solo con que la ruta responda: que lo burdo no llegue a
 * publicarse, que reportar avise al equipo, que bloquear haga desaparecer a
 * esa persona de SU foro (y de nadie más), y que el equipo pueda decidir.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const T: Record<string, { accessToken: string; userId: string }> = {};

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

const publicar = async (quien: string, texto: string) => {
  const res = await req('/forum-posts', T[quien]!.accessToken, json({ body: texto }));
  expect(res.status, await res.clone().text()).toBe(201);
  return (await body<{ id: string }>(res)).id;
};

const responder = async (quien: string, postId: string, texto: string) => {
  const res = await req(
    `/forum-posts/${postId}/replies`,
    T[quien]!.accessToken,
    json({ body: texto }),
  );
  expect(res.status, await res.clone().text()).toBe(201);
  return (await body<{ id: string }>(res)).id;
};

const idsDelForo = async (quien: string): Promise<string[]> => {
  const res = await req('/forum-posts?pageSize=100', T[quien]!.accessToken);
  expect(res.status).toBe(200);
  return (await body<{ data: { id: string }[] }>(res)).data.map((p) => p.id);
};

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
  T.admin = await login(app, 'admin@enactus.co', 'Admin123');
  T.ana = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  T.beto = await login(app, 'estudiante2@uniandes.edu.co', 'Est123');
  T.caro = await login(app, 'estudiante3@unal.edu.co', 'Est123');
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('filtro de lenguaje', () => {
  it('reconoce la palabra sin importar mayúsculas ni tildes', () => {
    expect(tieneLenguajeNoPermitido('Usted es un MALPARIDO')).toBe(true);
    expect(tieneLenguajeNoPermitido('malparído!')).toBe(true);
  });

  it('no confunde palabras que solo la contienen', () => {
    // «computador» contiene «puta»; «disputa» también. Ninguna es ofensiva.
    expect(tieneLenguajeNoPermitido('Llevé el computador a la disputa')).toBe(false);
    expect(tieneLenguajeNoPermitido('Campaña de prevención de la gonorrea')).toBe(false);
  });

  it('una publicación con lenguaje ofensivo no se publica', async () => {
    const res = await req(
      '/forum-posts',
      T.ana!.accessToken,
      json({ body: 'Qué proyecto tan malparido' }),
    );
    expect(res.status).toBe(400);
    expect((await body<{ error: { message: string } }>(res)).error.message).toMatch(/normas/);
  });

  it('una respuesta tampoco', async () => {
    const postId = await publicar('ana', '¿Alguien tiene la plantilla del pitch?');
    const res = await req(
      `/forum-posts/${postId}/replies`,
      T.beto!.accessToken,
      json({ body: 'no sea imbécil' }),
    );
    expect(res.status).toBe(400);
  });
});

describe('reportar', () => {
  it('un reporte llega a la cola del equipo, con el texto y el motivo', async () => {
    const postId = await publicar('beto', 'Compren mis rifas, link en mi perfil');
    const res = await req(
      `/forum-posts/${postId}/report`,
      T.ana!.accessToken,
      json({ reason: 'Es spam o publicidad' }),
    );
    expect(res.status).toBe(201);

    const cola = await body<{
      data: { postId: string; reason: string; body: string; reporterName: string }[];
    }>(await req('/forum-posts/reports', T.admin!.accessToken));
    const item = cola.data.find((r) => r.postId === postId);
    expect(item, 'El reporte no aparece en la cola del equipo.').toBeDefined();
    expect(item!.reason).toBe('Es spam o publicidad');
    expect(item!.body).toContain('rifas');
  });

  it('al equipo le llega una notificación', async () => {
    const [n] = await sql<{ count: number }[]>`
      select count(*)::int as count from notifications
       where user_id = ${T.admin!.userId} and title = 'Nuevo reporte en el foro'`;
    expect(n!.count).toBeGreaterThan(0);
  });

  it('reportar dos veces lo mismo no suma', async () => {
    const postId = await publicar('beto', 'Otra publicación cualquiera');
    const primero = await req(`/forum-posts/${postId}/report`, T.caro!.accessToken, json({}));
    const segundo = await req(`/forum-posts/${postId}/report`, T.caro!.accessToken, json({}));
    expect(primero.status).toBe(201);
    expect(segundo.status).toBe(200);
    const [n] = await sql<{ count: number }[]>`
      select count(*)::int as count from forum_reports where post_id = ${postId}`;
    expect(n!.count).toBe(1);
  });

  it('se puede reportar una respuesta, y no lo propio', async () => {
    const postId = await publicar('ana', 'Pregunta sobre la Ruta de Impacto');
    const replyId = await responder('beto', postId, 'Respuesta fuera de tono');
    const res = await req(
      `/forum-posts/${postId}/report`,
      T.ana!.accessToken,
      json({ replyId, reason: 'Es ofensivo o irrespetuoso' }),
    );
    expect(res.status).toBe(201);

    const propio = await req(`/forum-posts/${postId}/report`, T.ana!.accessToken, json({}));
    expect(propio.status).toBe(400);
  });

  it('un estudiante no ve la cola ni atiende reportes', async () => {
    expect((await req('/forum-posts/reports', T.ana!.accessToken)).status).toBe(403);
    const [r] = await sql<{ id: string }[]>`select id from forum_reports limit 1`;
    const res = await req(
      `/forum-posts/reports/${r!.id}/resolve`,
      T.ana!.accessToken,
      json({ action: 'remove' }),
    );
    expect(res.status).toBe(403);
  });
});

describe('atender un reporte', () => {
  it('quitar el contenido lo saca del foro y cierra TODOS sus reportes', async () => {
    const postId = await publicar('beto', 'Contenido que varios reportan');
    await req(`/forum-posts/${postId}/report`, T.ana!.accessToken, json({}));
    await req(`/forum-posts/${postId}/report`, T.caro!.accessToken, json({}));
    const [r] = await sql<{ id: string }[]>`
      select id from forum_reports where post_id = ${postId} limit 1`;

    const res = await req(
      `/forum-posts/reports/${r!.id}/resolve`,
      T.admin!.accessToken,
      json({ action: 'remove' }),
    );
    expect(res.status).toBe(200);

    expect(await idsDelForo('ana')).not.toContain(postId);
    const [pendientes] = await sql<{ count: number }[]>`
      select count(*)::int as count from forum_reports
       where post_id = ${postId} and resolved_at is null`;
    expect(pendientes!.count, 'Quedaron reportes abiertos de algo ya quitado.').toBe(0);
  });

  it('descartar deja el contenido, y no se atiende dos veces', async () => {
    const postId = await publicar('beto', 'Contenido que no infringe nada');
    await req(`/forum-posts/${postId}/report`, T.caro!.accessToken, json({}));
    const [r] = await sql<{ id: string }[]>`
      select id from forum_reports where post_id = ${postId} limit 1`;

    const res = await req(
      `/forum-posts/reports/${r!.id}/resolve`,
      T.admin!.accessToken,
      json({ action: 'dismiss' }),
    );
    expect(res.status).toBe(200);
    expect(await idsDelForo('ana')).toContain(postId);

    const otraVez = await req(
      `/forum-posts/reports/${r!.id}/resolve`,
      T.admin!.accessToken,
      json({ action: 'remove' }),
    );
    expect(otraVez.status).toBe(409);
  });

  it('quitar una respuesta la saca de la publicación', async () => {
    const postId = await publicar('ana', 'Pregunta con una respuesta reportada');
    const replyId = await responder('beto', postId, 'Respuesta que se va a quitar');
    await req(`/forum-posts/${postId}/report`, T.caro!.accessToken, json({ replyId }));
    const [r] = await sql<{ id: string }[]>`
      select id from forum_reports where reply_id = ${replyId} limit 1`;

    await req(
      `/forum-posts/reports/${r!.id}/resolve`,
      T.admin!.accessToken,
      json({ action: 'remove' }),
    );
    const detalle = await body<{ replies: { id: string }[] }>(
      await req(`/forum-posts/${postId}`, T.ana!.accessToken),
    );
    expect(detalle.replies.map((x) => x.id)).not.toContain(replyId);
  });
});

describe('bloquear', () => {
  it('quien bloquea deja de ver lo que publica y responde esa persona', async () => {
    const postDeBeto = await publicar('beto', 'Publicación de Beto');
    const postDeAna = await publicar('ana', 'Publicación de Ana');
    const respuestaDeBeto = await responder('beto', postDeAna, 'Respuesta de Beto');

    const res = await req(
      '/forum-posts/blocks',
      T.caro!.accessToken,
      json({ userId: T.beto!.userId }),
    );
    expect(res.status).toBe(201);

    // Caro ya no ve a Beto...
    expect(await idsDelForo('caro')).not.toContain(postDeBeto);
    const detalle = await body<{ replies: { id: string }[] }>(
      await req(`/forum-posts/${postDeAna}`, T.caro!.accessToken),
    );
    expect(detalle.replies.map((r) => r.id)).not.toContain(respuestaDeBeto);
    expect((await req(`/forum-posts/${postDeBeto}`, T.caro!.accessToken)).status).toBe(404);

    // ...y para todos los demás no cambió nada.
    expect(await idsDelForo('ana')).toContain(postDeBeto);
  });

  it('el bloqueo aparece en su lista, y desbloquear lo devuelve todo', async () => {
    const lista = await body<{ data: { userId: string }[] }>(
      await req('/forum-posts/blocks', T.caro!.accessToken),
    );
    expect(lista.data.map((b) => b.userId)).toContain(T.beto!.userId);

    const res = await req(`/forum-posts/blocks/${T.beto!.userId}`, T.caro!.accessToken, {
      method: 'DELETE',
    });
    expect(res.status).toBe(204);
    const [n] = await sql<{ count: number }[]>`
      select count(*)::int as count from user_blocks where blocker_id = ${T.caro!.userId}`;
    expect(n!.count).toBe(0);
  });

  it('no se puede bloquear a sí mismo ni al equipo que modera', async () => {
    const propio = await req(
      '/forum-posts/blocks',
      T.ana!.accessToken,
      json({ userId: T.ana!.userId }),
    );
    expect(propio.status).toBe(400);
    const moderador = await req(
      '/forum-posts/blocks',
      T.ana!.accessToken,
      json({ userId: T.admin!.userId }),
    );
    expect(moderador.status).toBe(409);
  });
});

describe('borrar una respuesta', () => {
  it('el autor borra la suya; otra persona no', async () => {
    const postId = await publicar('ana', 'Pregunta para probar el borrado');
    const replyId = await responder('beto', postId, 'Respuesta de Beto');

    const ajena = await req(`/forum-posts/${postId}/replies/${replyId}`, T.caro!.accessToken, {
      method: 'DELETE',
    });
    expect(ajena.status).toBe(403);

    const propia = await req(`/forum-posts/${postId}/replies/${replyId}`, T.beto!.accessToken, {
      method: 'DELETE',
    });
    expect(propia.status).toBe(204);
  });
});
