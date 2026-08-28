import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';

import { db as defaultDb, type Database } from './db/client';
import { env } from './env';
import { onError, onNotFound } from './middleware/error';
import type { AppEnv } from './middleware/context';
import { authRoutes } from './routes/auth';

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

  return app;
}

export type App = ReturnType<typeof createApp>;
