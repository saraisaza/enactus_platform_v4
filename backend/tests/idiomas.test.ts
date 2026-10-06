import { resolve } from 'node:path';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { traducir } from '../src/i18n';
import { MENSAJES_EN } from '../src/i18n/mensajes';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';
import { mensajesDelCodigo } from './helpers/mensajes-del-codigo';

/**
 * La plataforma en español e inglés, del lado del servidor.
 *
 * Tres cosas: los mensajes de error salen en el idioma que pide la app
 * (`Accept-Language`), los avisos se guardan con su tipo para que quien los
 * LEE los vea en su idioma, y la portada tiene sus textos en inglés.
 */

const partes = (s: string) => (s.match(/\{\d+\}/g) ?? []).sort();

describe('el catálogo de mensajes en inglés', () => {
  const delCodigo = mensajesDelCodigo(resolve(__dirname, '..'));
  const catalogo = new Map(MENSAJES_EN);

  it('encuentra los mensajes del código (si da cero, el extractor se rompió)', () => {
    expect(delCodigo.length).toBeGreaterThan(150);
  });

  it('todo mensaje que el servidor puede mostrar tiene su traducción', () => {
    const faltan = [
      ...new Set(
        delCodigo
          .filter((m) => !catalogo.has(m.texto))
          .map((m) => `${m.archivo}:${m.linea}  «${m.texto}»`),
      ),
    ];
    // Si esto falla: agregue el par [español, inglés] en src/i18n/mensajes.ts.
    expect(faltan).toEqual([]);
  });

  it('no quedan traducciones de mensajes que el código ya no usa', () => {
    const usados = new Set(delCodigo.map((m) => m.texto));
    const sobran = [...catalogo.keys()].filter((es) => !usados.has(es));
    expect(sobran).toEqual([]);
  });

  it('cada traducción conserva las partes que cambian', () => {
    const malas = MENSAJES_EN.filter(
      ([es, en]) => partes(es).join() !== partes(en).join(),
    ).map(([es]) => es);
    expect(malas).toEqual([]);
  });

  it('no hay dos entradas para el mismo mensaje', () => {
    expect(MENSAJES_EN.length).toBe(catalogo.size);
  });
});

describe('traducir', () => {
  it('en español devuelve el mensaje tal cual', () => {
    expect(traducir('No se encontró el curso.', 'es')).toBe('No se encontró el curso.');
  });

  it('en inglés usa el catálogo', () => {
    expect(traducir('No se encontró el curso.', 'en')).toBe('The course was not found.');
  });

  it('reconoce un mensaje con partes y las copia a la traducción', () => {
    expect(
      traducir('La nota debe estar entre 0 y 5 en la escala scale5.', 'en'),
    ).toBe('The grade must be between 0 and 5 on the scale5 scale.');
    expect(
      traducir('El término «Pitch» ya está en el glosario de este curso, en el módulo «Módulo 1».', 'en'),
    ).toBe('The term “Pitch” is already in this course\'s glossary, in the module “Módulo 1”.');
  });

  it('un mensaje desconocido sale en español antes que vacío', () => {
    expect(traducir('Algo que nadie tradujo.', 'en')).toBe('Algo que nadie tradujo.');
  });
});

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
const T: Record<string, { accessToken: string; userId: string }> = {};

const con = (idioma: string | null, init: RequestInit = {}): RequestInit => ({
  ...init,
  headers: {
    ...(init.headers ?? {}),
    ...(idioma === null ? {} : { 'accept-language': idioma }),
  },
});

const mensaje = async (res: Response) =>
  ((await res.json()) as { error: { message: string } }).error.message;

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
  T.admin = await login(app, 'admin@enactus.co', 'Admin123');
  T.ana = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  T.beto = await login(app, 'estudiante2@uniandes.edu.co', 'Est123');
  T.empresa = await login(app, 'empresa@bancolombia.com', 'Empresa123');
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('Accept-Language en los errores', () => {
  it('sin cabecera responde en español, como siempre', async () => {
    const res = await app.request('/auth/me', con(null));
    expect(res.status).toBe(401);
    expect(await mensaje(res)).toBe('Falta el encabezado Authorization.');
  });

  it('con «en» responde en inglés', async () => {
    const res = await app.request('/auth/me', con('en'));
    expect(res.status).toBe(401);
    expect(await mensaje(res)).toBe('The Authorization header is missing.');
  });

  it('cuenta el primer idioma de la lista, como la app', async () => {
    const en = await app.request('/auth/me', con('en-US,en;q=0.9,es;q=0.8'));
    expect(await mensaje(en)).toBe('The Authorization header is missing.');
    // Francés primero: no es ni español ni inglés, así que español.
    const fr = await app.request('/auth/me', con('fr-FR,en;q=0.8'));
    expect(await mensaje(fr)).toBe('Falta el encabezado Authorization.');
  });

  it('traduce un error de negocio de una ruta real', async () => {
    const res = await app.request(
      '/auth/login',
      con('en', json({ email: 'admin@enactus.co', password: 'no-es-esta' })),
    );
    expect(res.status).toBe(401);
    expect(await mensaje(res)).toBe('Incorrect email or password.');
  });

  it('traduce los mensajes con partes (la ruta que no existe)', async () => {
    const res = await app.request('/no-existe', con('en'));
    expect(res.status).toBe(404);
    expect(await mensaje(res)).toBe('The route GET /no-existe does not exist.');
  });

  it('traduce el error de validación', async () => {
    const res = await app.request('/auth/login', con('en', json({ email: 'x' })));
    expect(res.status).toBe(400);
    expect(await mensaje(res)).toBe('The data sent is not valid.');
  });
});

type Aviso = {
  title: string;
  body: string;
  kind: string | null;
  params: Record<string, string> | null;
};

const avisosDe = async (quien: string): Promise<Aviso[]> => {
  const res = await app.request('/notifications?pageSize=100', {
    headers: auth(T[quien]!.accessToken),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { data: Aviso[] }).data;
};

describe('avisos con tipo', () => {
  it('un aviso de la app guarda su tipo y sus datos, además del texto en español', async () => {
    const res = await app.request('/notifications', {
      ...json({
        userIds: [T.ana!.userId],
        title: 'Entrega revisada',
        body: 'Su mentor comentó "Informe final".',
        kind: 'mentor_comento',
        params: { tarea: 'Informe final' },
      }),
      headers: { 'content-type': 'application/json', ...auth(T.admin!.accessToken) },
    });
    expect(res.status, await res.clone().text()).toBe(201);

    const aviso = (await avisosDe('ana')).find((a) => a.kind === 'mentor_comento');
    expect(aviso).toMatchObject({
      title: 'Entrega revisada',
      body: 'Su mentor comentó "Informe final".',
      params: { tarea: 'Informe final' },
    });
  });

  it('un aviso sin tipo se guarda como siempre (BuscaTalento)', async () => {
    const res = await app.request('/notifications', {
      ...json({ userIds: [T.ana!.userId], title: 'Una oportunidad', body: 'Hola' }),
      headers: { 'content-type': 'application/json', ...auth(T.admin!.accessToken) },
    });
    expect(res.status).toBe(201);
    const aviso = (await avisosDe('ana')).find((a) => a.title === 'Una oportunidad');
    expect(aviso).toMatchObject({ kind: null, params: null });
  });

  it('desde la app no se puede fabricar un aviso que solo genera el servidor', async () => {
    const res = await app.request('/notifications', {
      ...json({
        userIds: [T.ana!.userId],
        title: 'Nuevo certificado',
        kind: 'certificado_nuevo',
        params: { laboratorio: 'Falso' },
      }),
      headers: { 'content-type': 'application/json', ...auth(T.admin!.accessToken) },
    });
    expect(res.status).toBe(400);
  });

  it('el pedido a administración lleva la firma en los datos, puesta por el servidor', async () => {
    const res = await app.request('/notifications/admins', {
      ...json({
        title: 'Solicitud de estudiantes patrocinados',
        body: 'Un aliado pidió que le asignen estudiantes a su aporte.',
        kind: 'solicitud_patrocinados',
        // Quien pide no puede firmar por otro.
        params: { remitente: 'Otra persona', correo: 'otra@x.co' },
      }),
      headers: { 'content-type': 'application/json', ...auth(T.empresa!.accessToken) },
    });
    expect(res.status, await res.clone().text()).toBe(201);
    const aviso = (await avisosDe('admin')).find((a) => a.kind === 'solicitud_patrocinados');
    expect(aviso?.params?.correo).toBe('empresa@bancolombia.com');
    expect(aviso?.params?.remitente).not.toBe('Otra persona');
    // El texto en español conserva la firma, como antes.
    expect(aviso?.body).toContain('empresa@bancolombia.com');
  });

  it('los avisos que genera el servidor llevan su tipo (un reporte del foro)', async () => {
    const pub = await app.request('/forum-posts', {
      ...json({ body: 'Una publicación para reportar' }),
      headers: { 'content-type': 'application/json', ...auth(T.beto!.accessToken) },
    });
    expect(pub.status).toBe(201);
    const { id } = (await pub.json()) as { id: string };
    const rep = await app.request(`/forum-posts/${id}/report`, {
      ...json({ reason: 'Es spam o publicidad' }),
      headers: { 'content-type': 'application/json', ...auth(T.ana!.accessToken) },
    });
    expect(rep.status, await rep.clone().text()).toBe(201);
    const aviso = (await avisosDe('admin')).find((a) => a.kind === 'foro_reporte');
    expect(aviso?.title).toBe('Nuevo reporte en el foro');
  });
});

describe('la portada en inglés', () => {
  const guardar = (cuerpo: Record<string, unknown>) =>
    app.request('/site-content', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(T.admin!.accessToken) },
      body: JSON.stringify(cuerpo),
    });

  it('guarda y sirve los textos en inglés', async () => {
    const res = await guardar({
      heroTitle: 'eduXaction Colombia',
      heroSubtitle: 'Formamos líderes',
      heroTitleEn: 'eduXaction Colombia',
      heroSubtitleEn: 'We develop leaders',
      bannerTextEn: 'Sign-ups are open',
      aboutTextEn: 'About us',
    });
    expect(res.status, await res.clone().text()).toBe(200);

    const portada = (await (await app.request('/site-content')).json()) as Record<string, unknown>;
    expect(portada).toMatchObject({
      heroSubtitle: 'Formamos líderes',
      heroSubtitleEn: 'We develop leaders',
      bannerTextEn: 'Sign-ups are open',
      aboutTextEn: 'About us',
    });
  });

  it('un cliente que no manda los textos en inglés no los borra', async () => {
    const res = await guardar({ heroTitle: 'eduXaction Colombia', heroSubtitle: 'Otro' });
    expect(res.status).toBe(200);
    const portada = (await (await app.request('/site-content')).json()) as Record<string, unknown>;
    expect(portada.heroSubtitle).toBe('Otro');
    expect(portada.heroSubtitleEn).toBe('We develop leaders');
  });
});
