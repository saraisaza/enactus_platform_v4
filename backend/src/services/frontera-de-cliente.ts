import { type SQL, sql } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';

import type { Database } from '../db/client';
import { forbidden } from '../lib/errors';
import type { AuthUser } from '../middleware/context';

/**
 * La frontera entre clientes.
 *
 * Una cuenta que pertenece a un cliente —Enactus o una empresa— solo alcanza a
 * personas de ESE cliente. Las cuentas sin cliente (la administración y los
 * LXD de eduXaction) no tienen frontera: atienden a todos.
 *
 * Cada ruta decide primero, con la regla de su rol, a quién alcanza (su
 * universidad, sus laboratorios, sus cursos). Esta frontera va ENCIMA, como un
 * segundo cerrojo: aunque la regla de un rol sea ancha —«los de mi
 * universidad» incluía a la estudiante de una empresa que estudia ahí—, no
 * cruza de un cliente a otro.
 */

/**
 * Condición «la persona de [personaId] es del mismo cliente que [quienMira]».
 *
 * Sin cliente no hay frontera: `true`. Una persona sin cliente no es de
 * ninguno, así que para una cuenta con cliente queda fuera (`null in (...)`
 * no es verdadero).
 */
export function delMismoCliente(quienMira: AuthUser, personaId: SQL | AnyPgColumn): SQL {
  if (!quienMira.clientId) return sql`true`;
  return sql`${personaId} in (select fc.id from users fc
                               where fc.client_id = ${quienMira.clientId})`;
}

/** ¿[personaId] es del mismo cliente que [quienMira]? */
export async function mismoCliente(
  db: Database,
  quienMira: AuthUser,
  personaId: string | null,
): Promise<boolean> {
  if (!quienMira.clientId) return true;
  if (!personaId) return false;
  const filas = await db.execute<{ ok: number }>(sql`
    select 1 as ok from users
     where id = ${personaId} and client_id = ${quienMira.clientId}
     limit 1`);
  return filas.length > 0;
}

/**
 * ¿La cuenta es de una EMPRESA cliente (un cliente sin laboratorios)?
 *
 * Laboratorios, proyectos, equipos y la Ruta de Impacto son de Enactus: una
 * cuenta de empresa no los ve, sea del rol que sea.
 */
export async function esDeEmpresa(db: Database, cuenta: AuthUser): Promise<boolean> {
  if (!cuenta.clientId) return false;
  const filas = await db.execute<{ labs: boolean }>(sql`
    select has_laboratories as labs from clients where id = ${cuenta.clientId} limit 1`);
  return filas.length > 0 && !filas[0]!.labs;
}

/** Corta a una cuenta de empresa antes de lo que es solo de Enactus. */
export async function exigirLadoEnactus(db: Database, cuenta: AuthUser): Promise<void> {
  if (await esDeEmpresa(db, cuenta)) {
    throw forbidden(
      'Los laboratorios, los proyectos y los equipos son de Enactus: su cuenta es de una empresa.',
    );
  }
}
