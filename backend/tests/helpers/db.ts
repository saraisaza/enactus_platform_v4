import 'dotenv/config';
import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';

import * as schema from '../../src/db/schema';

const url = process.env.TEST_DATABASE_URL;
if (!url) {
  throw new Error(
    'Falta TEST_DATABASE_URL. Las pruebas NUNCA corren contra la base de ' +
      'desarrollo: borran y recrean el esquema entero.',
  );
}

/** URL confirmada como no-nula, para no repetir el chequeo en cada uso. */
const testUrl: string = url;

export function makeTestClient() {
  return postgres(testUrl, { max: 1, onnotice: () => undefined });
}

/**
 * Deja la base de pruebas con el esquema recién migrado y sin datos.
 *
 * Borra los dos esquemas (el del dominio y el de bookkeeping de Drizzle) en
 * vez de usar `db:rollback`: acá interesa un punto de partida limpio, no
 * ejercitar el reverso — eso lo prueba `migrations.test.ts` aparte.
 */
export async function resetTestDatabase() {
  const sql = makeTestClient();
  try {
    await sql.unsafe('drop schema if exists public cascade');
    await sql.unsafe('drop schema if exists drizzle cascade');
    await sql.unsafe('create schema public');
    await migrate(drizzle(sql), { migrationsFolder: './drizzle' });
  } finally {
    await sql.end();
  }
}

export { schema };
