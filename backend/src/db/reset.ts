import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';

import { databaseUrl, env } from '../env';
import { createClient, redactUrl } from './connection';
import * as schema from './schema';
import { seed } from './seed';

/**
 * Borra y regenera todo: esquema, migraciones y datos.
 *
 * Destructivo por definición, así que se niega a correr en producción — el
 * comando existe para desarrollo y para la base de pruebas, no para arreglar
 * algo en vivo.
 */
async function main() {
  if (env.NODE_ENV === 'production') {
    throw new Error(
      'db:reset borra la base entera y está bloqueado en producción. ' +
        'Para restaurar datos en producción se usa POST /admin/restore.',
    );
  }

  const sql = createClient(databaseUrl);
  const db = drizzle(sql, { schema, casing: 'snake_case' });
  try {
    console.log(`Reiniciando ${redactUrl(databaseUrl)}…`);
    await sql.unsafe('drop schema if exists public cascade');
    await sql.unsafe('drop schema if exists drizzle cascade');
    await sql.unsafe('create schema public');
    await migrate(drizzle(sql), { migrationsFolder: './drizzle' });
    console.log('Esquema recreado. Sembrando…');
    await seed(db);
    console.log('Base lista.');
  } finally {
    await sql.end();
  }
}

main().catch((error: unknown) => {
  console.error('Falló el reset:', error);
  process.exit(1);
});
