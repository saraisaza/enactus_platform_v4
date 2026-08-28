import { drizzle } from 'drizzle-orm/postgres-js';

import { createClient } from './connection';
import * as schema from './schema';

/**
 * Conexión global de la aplicación. Los scripts sueltos (migrate, rollback,
 * seed, reset) NO deben importar de acá: usan `createClient()` de
 * `connection.ts` para poder cerrar su propia conexión al terminar.
 */
export const sql = createClient();
export const db = drizzle(sql, { schema, casing: 'snake_case' });

export type Database = typeof db;
export { schema };
