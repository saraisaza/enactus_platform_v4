import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { databaseUrl } from '../env';
import { createClient } from './connection';

/**
 * Revierte la última migración aplicada.
 *
 * `drizzle-kit` genera solo el "up". El "down" lo escribimos a mano en
 * `drizzle/down/<tag>.down.sql`, con el mismo `tag` que el archivo generado.
 * Este script:
 *   1. lee de `drizzle.__drizzle_migrations` la última migración aplicada,
 *   2. la cruza contra `drizzle/meta/_journal.json` para saber su `tag`,
 *   3. ejecuta el archivo de bajada dentro de una transacción,
 *   4. borra la fila del registro de migraciones.
 *
 * Si el paso 3 falla, la transacción se revierte entera y el registro queda
 * intacto: nunca se marca como revertida una migración que no bajó.
 */

interface JournalEntry {
  idx: number;
  when: number;
  tag: string;
}

interface Journal {
  entries: JournalEntry[];
}

async function main() {
  const sql = createClient(databaseUrl);
  try {
    const applied = await sql<{ id: number; created_at: string }[]>`
      select id, created_at
      from drizzle.__drizzle_migrations
      order by created_at desc
      limit 1
    `;

    const last = applied[0];
    if (!last) {
      console.log('No hay migraciones aplicadas. Nada que revertir.');
      return;
    }

    const journalRaw = await readFile(
      path.resolve('drizzle/meta/_journal.json'),
      'utf8',
    );
    const journal = JSON.parse(journalRaw) as Journal;
    const entry = journal.entries.find(
      (e) => String(e.when) === String(last.created_at),
    );

    if (!entry) {
      throw new Error(
        `La migración aplicada (created_at=${last.created_at}) no aparece en ` +
          'drizzle/meta/_journal.json. El registro y los archivos están ' +
          'desincronizados: revisalo a mano antes de seguir.',
      );
    }

    const downPath = path.resolve('drizzle/down', `${entry.tag}.down.sql`);
    let downSql: string;
    try {
      downSql = await readFile(downPath, 'utf8');
    } catch {
      throw new Error(
        `Falta el archivo de bajada ${downPath}. Toda migración necesita su ` +
          'reverso escrito a mano — sin él, `npm run db:rollback` no puede ' +
          'cumplir lo que promete.',
      );
    }

    console.log(`Revirtiendo ${entry.tag}…`);
    await sql.begin(async (tx) => {
      await tx.unsafe(downSql);
      await tx`delete from drizzle.__drizzle_migrations where id = ${last.id}`;
    });
    console.log(`Revertida ${entry.tag}.`);
  } finally {
    await sql.end();
  }
}

main().catch((error: unknown) => {
  console.error('Falló el rollback:', error);
  process.exit(1);
});
