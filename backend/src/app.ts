import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';

import { db as defaultDb, type Database } from './db/client';
import { env } from './env';
import { onError, onNotFound } from './middleware/error';
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
import { userRoutes } from './routes/users';
import { courseRoutes, moduleRoutes } from './routes/courses';
import { fileRoutes } from './routes/files';
import { forumRoutes } from './routes/forum';
import { labRoutes } from './routes/labs';
import { lessonRoutes, moduleLessonRoutes } from './routes/lessons';
import { groupRoutes, projectRoutes } from './routes/orgs';
import { progressRoutes } from './routes/progress';
import { siteRoutes } from './routes/site';
import { studentRoutes } from './routes/students';
import { submissionRoutes } from './routes/submissions';

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
      allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
      allowHeaders: ['Authorization', 'Content-Type'],
      maxAge: 600,
      credentials: false,
    }),
  );

  app.use('*', secureHeaders());

  app.use('*', async (c, next) => {
    c.set('db', database);
    c.set(
      'requestIp',
      c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ??
        c.req.header('x-real-ip') ??
        '0.0.0.0',
    );
    await next();
  });

  app.get('/health', (c) =>
    c.json({ status: 'ok', env: env.NODE_ENV, time: new Date().toISOString() }),
  );

  app.route('/auth', authRoutes);
  // Público: la portada se ve sin sesión.
  app.route('/site-content', siteRoutes);
  app.route('/users', userRoutes);
  app.route('/courses', courseRoutes);
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
  app.route('/projects', projectRoutes);
  app.route('/groups', groupRoutes);
  app.route('/submissions', submissionRoutes);
  app.route('/evidences', evidenceRoutes);
  app.route('/calendar-events', calendarRoutes);
  app.route('/communication-resources', commResourceRoutes);
  app.route('/notifications', notificationRoutes);
  app.route('/forum-posts', forumRoutes);
  app.route('/files', fileRoutes);
  app.route('/admin', adminRoutes);

  return app;
}

export type App = ReturnType<typeof createApp>;
