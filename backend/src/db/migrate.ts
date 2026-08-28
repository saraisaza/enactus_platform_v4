import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';

import { databaseUrl } from '../env';
import { createClient, redactUrl } from './connection';

/**
 * Aplica todas las migraciones pendientes.
 *
 * Usa una conexión propia con `max: 1` y la cierra al terminar: si el proceso
 * dejara el pool abierto, `npm run db:migrate` nunca devolvería el control a
 * la terminal.
 */
async function main() {
  const sql = createClient(databaseUrl);
  const db = drizzle(sql);
  console.log(`Aplicando migraciones sobre ${redactUrl(databaseUrl)}…`);
  await migrate(db, { migrationsFolder: './drizzle' });
  console.log('Migraciones aplicadas.');
  await sql.end();
}

main().catch((error: unknown) => {
  console.error('Falló la migración:', error);
  process.exit(1);
});
