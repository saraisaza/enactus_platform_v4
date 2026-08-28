import { drizzle } from 'drizzle-orm/postgres-js';
import type { Sql } from 'postgres';

import { createApp } from '../../src/app';
import * as schema from '../../src/db/schema';
import { makeTestClient } from './db';

/**
 * Aplicación real apuntando a la base de pruebas. Se usa
 * `app.request(...)` de Hono, que ejecuta el pipeline completo (CORS,
 * cabeceras, middlewares, rutas, manejo de errores) sin abrir un puerto.
 */
export function makeTestApp(): {
  app: ReturnType<typeof createApp>;
  sql: Sql;
  db: ReturnType<typeof drizzle<typeof schema>>;
} {
  const sql = makeTestClient();
  const db = drizzle(sql, { schema, casing: 'snake_case' });
  return { app: createApp(db), sql, db };
}

export const json = (body: unknown): RequestInit => ({
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

export const auth = (token: string): Record<string, string> => ({
  authorization: `Bearer ${token}`,
});

/** Inicia sesión y devuelve el par de tokens. Falla ruidosamente si no puede. */
export async function login(
  app: ReturnType<typeof createApp>,
  email: string,
  password: string,
): Promise<{ accessToken: string; refreshToken: string; userId: string }> {
  const res = await app.request('/auth/login', json({ email, password }));
  if (res.status !== 200) {
    throw new Error(
      `Login fallido para ${email}: ${res.status} ${await res.text()}`,
    );
  }
  const body = (await res.json()) as {
    accessToken: string;
    refreshToken: string;
    user: { id: string };
  };
  return {
    accessToken: body.accessToken,
    refreshToken: body.refreshToken,
    userId: body.user.id,
  };
}
