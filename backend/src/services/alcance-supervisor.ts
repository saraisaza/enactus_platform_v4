import { type SQL, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import type { AuthUser } from '../middleware/context';

/**
 * A quién alcanza el Manager / Supervisor de una empresa cliente: a las
 * personas de SU empresa que cursan (estudiantes y alumni), y a nadie más.
 *
 * Una sola definición para todas las rutas —personas, entregas, archivos,
 * certificados, seguimiento de cursos— para que no haya dos versiones de «su
 * gente» que puedan separarse.
 */

/**
 * Los ids de la gente de la empresa de [clientId], como subconsulta.
 *
 * Sin cliente no hay nadie: la base no deja un supervisor sin cliente, pero si
 * alguna vez pasara, `client_id = null` no es verdadero para ninguna fila y la
 * consulta se cierra en vez de abrirse.
 */
export function genteDeLaEmpresa(clientId: string | null): SQL {
  return sql`(select u.id from users u
               where u.client_id = ${clientId}
                 and u.role in ('student', 'alumni')
                 and u.deleted_at is null)`;
}

/** ¿[studentId] es de la empresa de este supervisor? */
export async function supervisorAlcanza(
  db: Database,
  supervisor: AuthUser,
  studentId: string | null,
): Promise<boolean> {
  if (!supervisor.clientId || !studentId) return false;
  const filas = await db.execute<{ ok: number }>(sql`
    select 1 as ok from users
     where id = ${studentId}
       and client_id = ${supervisor.clientId}
       and role in ('student', 'alumni')
       and deleted_at is null
     limit 1`);
  return filas.length > 0;
}
