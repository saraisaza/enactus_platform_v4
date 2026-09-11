import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';

import { db as defaultDb, type Database } from './db/client';
import { env } from './env';
import { resolveClientIp } from './lib/client-ip';
import { onError, onNotFound } from './middleware/error';
import { rateLimit } from './middleware/rate-limit';
import type { AppEnv } from './middleware/context';
import { authRoutes } from './routes/auth';
import { adminRoutes } from './routes/admin';
import { certificateRoutes } from './routes/certificates';
import {
  calendarRoutes,
  commResourceRoutes,
  evidenceRoutes,
  notificationRoutes,
} from './routes/content';
import { courseTrackingRoutes } from './routes/course-tracking';
import { assignmentRoutes } from './routes/assignments';
import { userRoutes } from './routes/users';
import { universityRoutes } from './routes/universities';
import { catalogRoutes } from './routes/catalogs';
import { courseRoutes, moduleRoutes } from './routes/courses';
import { fileRoutes } from './routes/files';
import { forumRoutes } from './routes/forum';
import {
  labAuthoringRoutes,
  objectiveRoutes,
  phaseRoutes,
  rutaModuleRoutes,
} from './routes/lab-authoring';
import { labRoutes } from './routes/labs';
import { talentRoutes } from './routes/talent';
import { lessonRoutes, moduleLessonRoutes } from './routes/lessons';
import { groupRoutes, projectRoutes } from './routes/orgs';
import { progressRoutes } from './routes/progress';
import { siteRoutes } from './routes/site';
import { studentRoutes } from './routes/students';
import { submissionRoutes } from './routes/submissions';

/**
 * Techo de peticiones por minuto y por IP para toda la API.
 *
 * Se exporta para que la prueba que lo cuida use ESTE número y no una copia:
 * una constante duplicada en la prueba se desincroniza el día que alguien
 * cambie el límite, y la prueba pasa a cuidar un valor que ya no existe.
 */
export const LIMITE_GENERAL_POR_MINUTO = 1200;

/**
 * Arma la aplicación. Recibe la conexión por parámetro para que las pruebas
 * usen la suya (`TEST_DATABASE_URL`) sin tocar variables globales.
 */
export function createApp(database: Database = defaultDb) {
  const app = new Hono<AppEnv>();

  app.onError(onError);
  app.notFound(onNotFound);

  // CORS restringido al dominio del frontend. Sin comodín en producción: con
  // `*` cualquier sitio podría llamar la API con el token de la persona.
  app.use(
    '*',
    cors({
      origin: env.CORS_ORIGIN.split(',').map((o) => o.trim()),
      // PUT estuvo ausente de esta lista y NADIE lo notó, porque no rompe
      // ninguna prueba de servidor: `app.request()` no hace preflight. En un
      // navegador de verdad el efecto era que los CATORCE endpoints PUT de la
      // aplicación —asignar estudiantes a un laboratorio, ordenar módulos,
      // guardar un quiz, editar los miembros de un equipo— fallaban con
      // "Failed to fetch", sin llegar nunca al servidor y sin dejar rastro en
      // sus logs. `tests/cors.test.ts` compara esta lista contra los métodos
      // realmente registrados para que no pueda volver a desfasarse.
      allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowHeaders: ['Authorization', 'Content-Type'],
      maxAge: 600,
      credentials: false,
    }),
  );

  // Cabeceras de seguridad. Los tres valores explícitos NO son los que trae
  // `secureHeaders()` por defecto:
  //
  // - **CSP**: por defecto no pone ninguna. Esta API devuelve JSON y nada más,
  //   así que la política correcta es la más cerrada que existe: prohibirlo
  //   todo. Si algún día una respuesta devolviera HTML —una página de error de
  //   un proxy, un redirect mal armado—, el navegador no ejecutaría nada de
  //   ella.
  // - **`frame-ancestors 'none'`** es el equivalente moderno de
  //   X-Frame-Options y el que respetan los navegadores actuales; se declaran
  //   los dos porque no todos los intermediarios entienden CSP.
  // - **X-Frame-Options: DENY**, no el `SAMEORIGIN` por defecto. La API no se
  //   embebe en ningún lado, ni siquiera propio.
  // - **HSTS a un año** en vez de los 180 días por defecto: es el mínimo que
  //   exige la lista de precarga de los navegadores.
  app.use(
    '*',
    secureHeaders({
      contentSecurityPolicy: {
        defaultSrc: ["'none'"],
        frameAncestors: ["'none'"],
        baseUri: ["'none'"],
        formAction: ["'none'"],
      },
      xFrameOptions: 'DENY',
      strictTransportSecurity: 'max-age=31536000; includeSubDomains',
    }),
  );

  app.use('*', async (c, next) => {
    c.set('db', database);
    // La IP se resuelve en `lib/client-ip.ts`, NO leyendo la primera entrada
    // de `x-forwarded-for`: esa la escribe el cliente y con ella los dos
    // límites de peticiones se saltan rotando una cabecera. Ver el comentario
    // largo de ese archivo — describe el agujero que había acá.
    c.set('requestIp', resolveClientIp(c));
    await next();
  });

  // Límite moderado para toda la API, aparte del estricto de `/auth/login`.
  //
  // Va DESPUÉS del middleware que fija `requestIp`: registrado antes, la
  // clave sería `api:undefined` para todo el mundo y el cupo pasaría a ser
  // uno solo compartido por todos los clientes, no uno por IP.
  //
  // El número sale de una medición, no de una intuición. Un proxy contador
  // delante de la API mientras corría la suite de contrato del cliente dio
  // **169 peticiones para 9 portales ≈ 19 por carga de portal**.
  //
  // Con 300/min eso son ~15 personas por minuto y por IP. Los usuarios de
  // esta plataforma son estudiantes en universidades: una sala de cómputo
  // entera sale por una sola IP pública. Una clase de 30 entrando a la vez
  // agota el cupo del edificio y el 429 les cae **también en el login** —
  // caída total para gente legítima, provocada por nosotros.
  //
  // 1200/min deja ~60 cargas de portal por minuto por IP, que cubre un
  // campus, y sigue cortando en seco a quien quiera recorrer la API entera
  // (un raspador hace miles por minuto, no cientos).
  //
  // Vale la MISMA limitación que el de login: el contador vive en memoria del
  // proceso, así que en Lambda cada instancia tiene el suyo y el tope
  // efectivo se multiplica por la cantidad de instancias vivas. Esto es una
  // red de seguridad gruesa; el límite duro va en API Gateway (throttling) —
  // ver RUNBOOK.md.
  app.use(
    '*',
    rateLimit({
      max: LIMITE_GENERAL_POR_MINUTO,
      windowMs: 60_000,
      readsBody: false,
      keyOf: (c) => `api:${c.get('requestIp')}`,
    }),
  );


  app.get('/health', (c) =>
    c.json({ status: 'ok', env: env.NODE_ENV, time: new Date().toISOString() }),
  );

  app.route('/auth', authRoutes);
  // Público: la portada se ve sin sesión.
  app.route('/site-content', siteRoutes);
  app.route('/users', userRoutes);
  // Segundo router en la misma base: asignar laboratorios o cursos a un
  // estudiante es solo de Admin, mientras que listar personas lo hacen los
  // ocho portales con alcances distintos.
  app.route('/users', assignmentRoutes);
  // Competencias y ODS: las dibuja el constructor de cursos y salen de la
  // base, no de una constante copiada en el cliente.
  app.route('/catalogs', catalogRoutes);
  app.route('/universities', universityRoutes);
  app.route('/courses', courseRoutes);
  // Segundo router en la misma base: el seguimiento de un curso es de otro
  // rol (quien acompaña, no quien edita) y vive en su propio archivo.
  app.route('/courses', courseTrackingRoutes);
  // Dos routers en la misma base: uno maneja el módulo en sí, el otro sus
  // lecciones. Se separan por archivo para que `courses.ts` no tenga que
  // importar `lessons.ts` y al revés.
  app.route('/modules', moduleRoutes);
  app.route('/modules', moduleLessonRoutes);
  app.route('/lessons', lessonRoutes);
  app.route('/progress', progressRoutes);
  app.route('/students', studentRoutes);
  app.route('/certificates', certificateRoutes);
  app.route('/laboratories', labRoutes);
  // Escritura de laboratorios y de su Ruta de Impacto: otro rol (solo Admin)
  // y otra clase de regla que la lectura, así que otro archivo.
  app.route('/laboratories', labAuthoringRoutes);
  app.route('/phases', phaseRoutes);
  app.route('/ruta-modules', rutaModuleRoutes);
  app.route('/objectives', objectiveRoutes);
  app.route('/projects', projectRoutes);
  app.route('/groups', groupRoutes);
  app.route('/submissions', submissionRoutes);
  app.route('/evidences', evidenceRoutes);
  app.route('/calendar-events', calendarRoutes);
  app.route('/communication-resources', commResourceRoutes);
  app.route('/notifications', notificationRoutes);
  app.route('/forum-posts', forumRoutes);
  app.route('/files', fileRoutes);
  // BuscaTalento: el único listado de personas con alcance más ancho que
  // `/users`, y por eso con ruta propia en vez de un filtro que lo ensanche.
  app.route('/talent', talentRoutes);
  app.route('/admin', adminRoutes);

  return app;
}

export type App = ReturnType<typeof createApp>;
