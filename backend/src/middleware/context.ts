import type { Database } from '../db/client';
import type * as schema from '../db/schema';

/** Usuario autenticado, leído de la base en cada petición (ver `auth.ts`). */
export type AuthUser = typeof schema.users.$inferSelect;

/**
 * Variables que los middlewares dejan en el contexto de Hono.
 * `db` se inyecta para que las pruebas puedan pasar su propia conexión.
 */
export interface AppEnv {
  Variables: {
    db: Database;
    user?: AuthUser;
    requestIp: string;
  };
}
