import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * ¿Los guardias están ENGANCHADOS a los endpoints reales?
 *
 * Esta prueba existe por el hallazgo más caro de la auditoría. Un barrido de
 * mutaciones —quitar cada guardia de su ruta, una por una, y correr la suite
 * entera— encontró que **36 de las 79 aplicaciones podían quitarse sin que
 * ninguna prueba se pusiera roja**, entre ellas `DELETE /users/:id`,
 * `PATCH /users/:id`, `DELETE /courses/:id` y toda la autoría de lecciones.
 *
 * La causa es siempre la misma: las pruebas de autorización montaban el
 * middleware sobre una ruta de mentira. Eso demuestra que el middleware
 * **funciona**; no que esté **puesto** donde hace falta.
 *
 * REGLA PERMANENTE: ninguna prueba de middleware cuenta si corre sobre una
 * ruta sintética. Tiene que ejercitar el endpoint real.
 *
 * Por eso esto no son 36 pruebas escritas a mano sino **un barrido sobre
 * `app.routes`**: cubre lo que hay hoy y, sobre todo, lo que se agregue
 * mañana. Un endpoint nuevo entra cubierto sin que nadie se acuerde de
 * cubrirlo — que es la única forma de que no se olvide.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let tokenEstudiante = '';

/** Un uuid cualquiera para rellenar `:id`. No tiene que existir: los guardias
 *  corren ANTES de buscar la fila, así que un 404 significaría que no corrieron. */
const UUID = '00000000-0000-4000-8000-000000000000';

/**
 * Lo que se puede pedir SIN sesión.
 *
 * Es una lista explícita a propósito: si mañana alguien deja público un
 * endpoint nuevo, esta prueba se pone roja y hay que venir a escribirlo acá.
 * Un `skip` genérico convertiría ese descuido en silencio.
 */
const PUBLICAS = new Set([
  'GET /health',
  'POST /auth/login',
  'POST /auth/refresh',
  'POST /auth/logout',
  'GET /site-content',
  'GET /projects',
  'GET /projects/:id',
]);

/**
 * Lo que un ESTUDIANTE sí puede tocar.
 *
 * Todo lo demás tiene que devolverle una negativa. Esta lista es la definición
 * operativa de «qué alcanza un estudiante», y vale como documentación: si
 * crece sin que nadie lo discuta, el alcance creció sin que nadie lo discuta.
 */
const ESTUDIANTE_PUEDE = [
  /^GET \/(health|site-content|catalogs)/,
  /^(GET|PATCH) \/auth\/me$/,
  /^POST \/auth\/(login|refresh|logout)$/,
  /^GET \/(courses|laboratories|projects|groups|certificates|evidences)/,
  /^GET \/(calendar-events|communication-resources|notifications|forum-posts)/,
  // Ojo con el alcance de estos comodines: `GET /lessons/…` a secas dejaba
  // pasar `GET /lessons/:id/quiz`, que devuelve el cuestionario **con las
  // respuestas** y por eso está reservado a CONTENT_ROLES. Un estudiante que
  // lo pidiera vería el solucionario. Los comodines anchos en una lista de
  // permitidos son justo el error que esta prueba busca en el código.
  /^GET \/students/,
  /^GET \/(lessons|modules)\/[^/]+$/,
  /^GET \/(phases|ruta-modules|objectives|progress)/,
  // Ve las suyas: el alcance del handler ya lo acota a su propia persona.
  /^GET \/submissions/,
  /^GET \/users$/,
  /^GET \/talent/,
  /^(POST|PATCH|PUT|DELETE) \/(progress|submissions|forum-posts|notifications)/,
  /^POST \/lessons\/[^/]+\/(quiz-attempt|survey|activity-submission)/,
  /^POST \/files\/upload-url$/,
  /^GET \/files\//,

  // Estos NO llevan guardia de ruta, y está bien: autorizan **dentro** del
  // handler, después de cargar la fila —`assertOwnsEvent`,
  // `loadTrackableCourse`— porque la decisión depende de quién creó ese
  // registro, dato que el middleware no tiene.
  //
  // Con un id inexistente responden 404, que es lo correcto: no delatan si
  // existe. Pero eso hace que este barrido no pueda distinguirlos de un
  // endpoint sin guardia, así que van con una prueba dirigida propia —ver
  // «autorización dentro del handler» abajo— y no colgando de esta lista.
  /^GET \/users\/:id$/,
  /^GET \/lessons\/:id\/video-url$/,
  /^POST \/calendar-events$/,
  /^POST \/files\/download-url$/,
  /^PUT \/courses\/:id\/students\/:studentId\/note$/,
  /^(PATCH|DELETE) \/calendar-events\/:id$/,
];

const puedeElEstudiante = (clave: string): boolean =>
  ESTUDIANTE_PUEDE.some((re) => re.test(clave));

/** Las rutas registradas de verdad, sin los middlewares (`ALL` sobre comodín). */
function rutasReales(): { method: string; path: string; clave: string }[] {
  const vistas = new Set<string>();
  const fuera: { method: string; path: string; clave: string }[] = [];
  for (const r of app.routes) {
    if (r.method === 'ALL') continue;
    const clave = `${r.method} ${r.path}`;
    if (vistas.has(clave)) continue;
    vistas.add(clave);
    fuera.push({ method: r.method, path: r.path, clave });
  }
  return fuera;
}

const concreta = (path: string) => path.replace(/:[A-Za-z0-9_]+/g, UUID);

async function pedir(
  r: { method: string; path: string },
  cabeceras: Record<string, string>,
): Promise<Response> {
  const init: RequestInit = { method: r.method, headers: { ...cabeceras } };
  if (!['GET', 'HEAD', 'OPTIONS'].includes(r.method)) {
    (init.headers as Record<string, string>)['content-type'] = 'application/json';
    init.body = '{}';
  }
  return app.request(concreta(r.path), init);
}

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  const s = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  tokenEstudiante = s.accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('todo endpoint no público exige sesión', () => {
  it('sin token, ninguno responde 2xx', async () => {
    const coladas: string[] = [];
    for (const r of rutasReales()) {
      if (PUBLICAS.has(r.clave)) continue;
      resetRateLimits();
      const res = await pedir(r, {});
      if (res.status < 300) coladas.push(`${r.clave} -> ${res.status}`);
    }
    expect(
      coladas,
      'estos endpoints respondieron sin sesión. O les falta `requireAuth`, ' +
        'o son públicos a propósito y hay que anotarlos en PUBLICAS',
    ).toEqual([]);
  });
});

describe('un estudiante no alcanza lo que no le toca', () => {
  it('cada endpoint fuera de su alcance le responde una negativa', async () => {
    const coladas: string[] = [];
    for (const r of rutasReales()) {
      if (puedeElEstudiante(r.clave)) continue;
      resetRateLimits();
      const res = await pedir(r, auth(tokenEstudiante));
      // Se exige **exactamente** 401 o 403. Nada más.
      //
      // La primera versión aceptaba cualquier 4xx razonando que «el guardia
      // corrió y la validación se quejó después». Estaba mal, y se vio al
      // re-verificar: al quitar el guardia, el cuerpo `{}` falla la validación
      // y devuelve **400** — indistinguible de lo anterior. 17 de los huecos
      // seguían abiertos por esa rendija.
      //
      // El orden es lo que lo hace tajante: el guardia es middleware, así que
      // corre ANTES de validar. Con guardia -> 403. Sin guardia -> 400 o 404.
      if (res.status !== 401 && res.status !== 403) {
        coladas.push(`${r.clave} -> ${res.status}`);
      }
    }
    expect(
      coladas,
      'un estudiante llegó al handler de estos endpoints. O les falta el ' +
        'guardia de rol, o son suyos y hay que anotarlos en ESTUDIANTE_PUEDE',
    ).toEqual([]);
  });
});

describe('autorización dentro del handler, con un id que sí existe', () => {
  /**
   * Los endpoints que deciden por quién creó la fila no pueden llevar guardia
   * de ruta: el middleware no sabe de quién es el registro hasta cargarlo.
   *
   * El barrido de arriba no los cubre —con un id inventado responden 404, igual
   * que un endpoint sin guardia— así que se prueban acá con un evento REAL de
   * otra persona. Sin esto quedarían en la lista de permitidos y nadie estaría
   * mirándolos, que es como se llegó a los 36 huecos.
   */
  it('un estudiante no puede editar ni borrar el evento de otra persona', async () => {
    const admin = await login(app, 'admin@enactus.co', 'Admin123');

    const creado = await app.request('/calendar-events', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(admin.accessToken) },
      body: JSON.stringify({
        title: 'Evento de la administración',
        type: 'ruta_impacto',
        startsAt: new Date().toISOString(),
      }),
    });
    // El cuerpo se lee UNA vez: `Response` no se puede leer dos veces, y
    // hacerlo en el mensaje del `expect` rompe la lectura siguiente.
    const textoCreado = await creado.text();
    expect(creado.status, textoCreado).toBeLessThan(300);
    const evento = JSON.parse(textoCreado) as { id: string };

    resetRateLimits();
    const editar = await app.request(`/calendar-events/${evento.id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(tokenEstudiante) },
      body: JSON.stringify({ title: 'secuestrado' }),
    });
    expect(editar.status).toBe(403);

    resetRateLimits();
    const borrar = await app.request(`/calendar-events/${evento.id}`, {
      method: 'DELETE',
      headers: auth(tokenEstudiante),
    });
    expect(borrar.status).toBe(403);

    // Y sigue ahí, con su título. Un 403 que igual borró sería peor que un 204.
    const [fila] = await sql<{ title: string; deleted_at: Date | null }[]>`
      select title, deleted_at from calendar_events where id = ${evento.id}`;
    expect(fila!.title).toBe('Evento de la administración');
    expect(fila!.deleted_at).toBeNull();
  });
});
