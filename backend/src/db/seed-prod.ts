import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';

import { count } from 'drizzle-orm';
import { drizzle } from 'drizzle-orm/postgres-js';
import { z } from 'zod';

import { databaseUrl, env } from '../env';
import { hashPassword } from '../lib/password';
import { createClient, redactUrl } from './connection';
import * as s from './schema';
import { seedId } from './seed-ids';
import { COMPETENCIES, LABS, ODS } from './seed';

/**
 * Seed de PRODUCCIÓN. Lo mínimo para que la plataforma exista y nada más:
 * los super admins reales, los 6 laboratorios y los dos catálogos.
 *
 * Es el hermano serio de `db:seed`, que siembra datos de demostración —
 * estudiantes inventados, entregas, foro, y cuentas con contraseñas de ejemplo
 * (`Admin123`). Ese está bloqueado en producción; este es el que corresponde.
 *
 * Tres decisiones que lo hacen seguro de correr:
 *
 * 1. **Las identidades no están en el código.** Los super admins se leen de un
 *    archivo que se pasa por parámetro. Hardcodearlos significaría tener los
 *    correos de la organización en el repositorio y, peor, invitar a poner
 *    también la contraseña.
 * 2. **Las contraseñas las genera él, al azar, y se imprimen UNA vez.** No hay
 *    contraseña por defecto que alguien pueda adivinar leyendo el repositorio.
 * 3. **Se niega a correr sobre una base que ya tiene gente**, salvo `--force`.
 *    Correrlo dos veces por accidente no duplica ni pisa nada.
 *
 * Uso:
 *
 *     npm run seed:prod -- ./admins.json
 *
 * con un archivo así (NO se versiona):
 *
 *     [{ "name": "Nombre Real", "email": "persona@enactuscolombia.org" }]
 */

type Db = ReturnType<typeof drizzle<typeof s>>;

const adminsSchema = z
  .array(
    z.object({
      name: z.string().trim().min(1, 'Cada admin necesita nombre.'),
      email: z.email('Correo inválido.'),
    }),
  )
  .min(1, 'Hace falta al menos un super admin: si no, nadie puede entrar.');

/**
 * Contraseña inicial: 24 caracteres de `randomBytes`, en base64url.
 *
 * Se entrega por un canal seguro y se cambia al primer ingreso. Ojo con esto
 * último: **hoy la plataforma no obliga al cambio** — no existe el campo que
 * lo marcaría. Está anotado en REVISION_FINAL.md como casilla abierta; hasta
 * que exista, el cambio es un acuerdo con la persona, no algo que el sistema
 * garantice.
 */
const contrasenaInicial = () => randomBytes(18).toString('base64url');

export async function seedProduccion(
  db: Db,
  admins: { name: string; email: string }[],
): Promise<{ email: string; password: string }[]> {
  // --- catálogos: son datos objetivos, iguales en cualquier entorno ---
  await db.insert(s.odsGoals).values(
    ODS.map((title, i) => ({ code: `ods_${i + 1}`, number: i + 1, title })),
  );
  await db
    .insert(s.competencies)
    .values(COMPETENCIES.map(([code, name]) => ({ code, name })));

  // --- los 6 laboratorios reales, sin patrocinador ni mentor asignado ---
  // El patrocinio y los mentores se asignan desde la plataforma, que es donde
  // queda registro de quién lo hizo.
  await db.insert(s.laboratories).values(
    LABS.map(([key, name, description, objectives]) => ({
      id: seedId(key),
      name,
      description,
      objectives,
      sponsorCompanyId: null,
    })),
  );

  // Las 3 fases de cada laboratorio, vacías y sin fecha límite: el contenido
  // y los plazos los pone el equipo desde la plataforma.
  await db.insert(s.phases).values(
    LABS.flatMap(([key]) =>
      [1, 2, 3].map((order) => ({
        id: seedId(`${key}_fase${order}`),
        laboratoryId: seedId(key),
        orderIndex: order,
        title: `Fase ${order}`,
        description: '',
        deadline: null,
      })),
    ),
  );

  // --- super admins ---
  const credenciales: { email: string; password: string }[] = [];
  const filas: (typeof s.users.$inferInsert)[] = [];
  for (const admin of admins) {
    const password = contrasenaInicial();
    credenciales.push({ email: admin.email, password });
    filas.push({
      name: admin.name,
      email: admin.email,
      passwordHash: await hashPassword(password),
      role: 'superadmin',
      joinedAt: new Date(),
    });
  }
  await db.insert(s.users).values(filas);

  return credenciales;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

async function main() {
  const argumentos = process.argv.slice(2);
  const force = argumentos.includes('--force');
  const ruta = argumentos.find((a) => !a.startsWith('--'));

  if (!ruta) {
    throw new Error(
      'Falta el archivo de super admins.\n\n' +
        '  npm run seed:prod -- ./admins.json\n\n' +
        'Contenido esperado:\n' +
        '  [{ "name": "Nombre Real", "email": "persona@enactuscolombia.org" }]\n\n' +
        'Ese archivo NO se versiona.',
    );
  }

  const admins = adminsSchema.parse(
    JSON.parse(readFileSync(ruta, 'utf8')) as unknown,
  );

  const sql = createClient(databaseUrl);
  const db = drizzle(sql, { schema: s, casing: 'snake_case' });
  try {
    // Se mira si ya hay gente ANTES de escribir nada. Correr esto dos veces
    // por accidente sobre una base viva no puede duplicar cuentas.
    const filasDeConteo = await db.select({ total: count() }).from(s.users);
    const total = filasDeConteo[0]?.total ?? 0;
    if (total > 0 && !force) {
      throw new Error(
        `La base ya tiene ${total} usuarios: ${redactUrl(databaseUrl)}\n` +
          'seed:prod es para una base recién creada. Si de verdad querés ' +
          'escribir encima, pasá --force.',
      );
    }

    console.log(`Sembrando producción en ${redactUrl(databaseUrl)}…`);
    console.log(`Entorno: ${env.NODE_ENV}`);
    const credenciales = await seedProduccion(db, admins);

    console.log('\nListo:');
    console.log(`  ${ODS.length} ODS · ${COMPETENCIES.length} competencias`);
    console.log(`  ${LABS.length} laboratorios, con 3 fases cada uno`);
    console.log(`  ${credenciales.length} super admins\n`);
    console.log('CONTRASEÑAS INICIALES — se muestran UNA sola vez.');
    console.log('Entregalas por un canal seguro y pedí el cambio al entrar:\n');
    for (const c of credenciales) {
      console.log(`  ${c.email.padEnd(38)} ${c.password}`);
    }
    console.log('');
  } finally {
    await sql.end();
  }
}

if (process.argv[1]?.endsWith('seed-prod.ts')) {
  main().catch((error: unknown) => {
    console.error(
      `\n${error instanceof Error ? error.message : String(error)}\n`,
    );
    process.exit(1);
  });
}
