import postgres from 'postgres';

import { databaseUrl, env } from '../env';

/**
 * Fábrica de conexiones. Vive separada de `client.ts` a propósito: los
 * scripts de migración y rollback necesitan una conexión propia que puedan
 * cerrar, y si importaran `client.ts` se llevarían de paso el pool global
 * (el proceso quedaría colgado sin devolver la terminal).
 *
 * `max: 1` en producción no es un descuido: cada invocación de Lambda es un
 * proceso aislado, así que un pool grande por proceso no aporta nada y sí
 * multiplica las conexiones abiertas contra una `db.t4g.micro`, que tiene
 * ~80-100 en total (ver AUDITORIA_BACKEND.md, observación 2).
 */
export function createClient(url: string = databaseUrl) {
  return postgres(url, {
    max: env.NODE_ENV === 'production' ? 1 : 5,
    idle_timeout: 20,
    connect_timeout: 10,
    // Por defecto postgres.js vuelca el objeto entero de cada NOTICE, y un
    // rollback (que emite un "drop cascades to…" por cada FK) termina
    // pareciendo una excepción. Se resumen a una línea: siguen visibles,
    // no se ocultan.
    onnotice: (notice) => {
      if (env.NODE_ENV === 'test') return;
      console.log(`  [postgres ${notice.severity}] ${notice.message}`);
    },
  });
}

/** Oculta la contraseña antes de imprimir una URL de conexión en un log. */
export function redactUrl(url: string): string {
  return url.replace(/\/\/[^@]*@/, '//***@');
}
