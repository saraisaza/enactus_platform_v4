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
 * las cuentas de administración reales, los 6 laboratorios y los catálogos.
 *
 * Es el hermano serio de `db:seed`, que siembra datos de demostración —
 * estudiantes inventados, entregas, foro, y cuentas con contraseñas de ejemplo
 * (`Admin123`). Ese está bloqueado en producción; este es el que corresponde.
 *
 * Tres decisiones que lo hacen seguro de correr:
 *
 * 1. **Las identidades no están en el código.** Se leen de un archivo que se
 *    pasa por parámetro. Hardcodearlas significaría tener los correos de la
 *    organización en el repositorio y, peor, invitar a poner también las
 *    contraseñas.
 * 2. **Si no se indica contraseña, la genera al azar** y la imprime UNA vez.
 *    No hay contraseña por defecto que alguien pueda adivinar leyendo el
 *    repositorio.
 * 3. **Se niega a correr sobre una base que ya tiene gente**, salvo `--force`.
 *    Correrlo dos veces por accidente no duplica ni pisa nada.
 *
 * Uso:
 *
 *     npm run seed:prod -- ./admins.json
 *
 * con un archivo así (NO se versiona, está en .gitignore):
 *
 *     [
 *       { "name": "Nombre Real", "email": "persona@enactuscolombia.org",
 *         "role": "superadmin" },
 *       { "name": "Otra Persona", "email": "otra@enactuscolombia.org",
 *         "role": "admin", "password": "la-que-eligieron" }
 *     ]
 */

type Db = ReturnType<typeof drizzle<typeof s>>;

/**
 * Piso de 12 caracteres para una contraseña elegida a mano.
 *
 * `createBody` de `/users` acepta 6, que está bien para dar de alta a un
 * estudiante desde la plataforma —esa cuenta la crea alguien ya autenticado y
 * no abre nada—. Acá no: estas son las cuentas que administran la plataforma
 * entera y se crean antes de que exista cualquier otro control. El piso es más
 * alto a propósito.
 */
const CARACTERES_MINIMOS = 12;

const cuentaSchema = z.object({
  name: z.string().trim().min(1, 'Cada cuenta necesita nombre.'),
  email: z.email('Correo inválido.'),
  /**
   * Por defecto `superadmin`: si el archivo no dice el rol, la intención más
   * probable es la cuenta de arranque. Equivocarse hacia arriba se ve y se
   * corrige; equivocarse hacia abajo deja la plataforma sin quien administre.
   */
  role: z.enum(['superadmin', 'admin']).default('superadmin'),
  /** Si no viene, se genera una al azar y se imprime al final. */
  password: z
    .string()
    .min(
      CARACTERES_MINIMOS,
      `Una contraseña de administración necesita al menos ${CARACTERES_MINIMOS} caracteres.`,
    )
    .optional(),
});

export type CuentaInicial = z.infer<typeof cuentaSchema>;

const adminsSchema = z
  .array(cuentaSchema)
  .min(1, 'Hace falta al menos una cuenta: si no, nadie puede entrar.')
  .refine(
    (cuentas) => cuentas.some((c) => c.role === 'superadmin'),
    'Hace falta al menos un superadmin: es el único rol que puede restaurar un respaldo.',
  )
  .refine((cuentas) => {
    const correos = cuentas.map((c) => c.email.trim().toLowerCase());
    return new Set(correos).size === correos.length;
  }, 'Hay correos repetidos en el archivo.');

/** Contraseña generada: 24 caracteres de `randomBytes`, en base64url. */
const contrasenaGenerada = () => randomBytes(18).toString('base64url');

export interface CredencialCreada {
  email: string;
  role: 'superadmin' | 'admin';
  password: string;
  /** `true` si la eligió quien corrió el comando, `false` si la generamos. */
  elegida: boolean;
}

export async function seedProduccion(
  db: Db,
  cuentas: CuentaInicial[],
): Promise<CredencialCreada[]> {
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

  // --- cuentas de administración ---
  const credenciales: CredencialCreada[] = [];
  const filas: (typeof s.users.$inferInsert)[] = [];
  for (const cuenta of cuentas) {
    const password = cuenta.password ?? contrasenaGenerada();
    credenciales.push({
      email: cuenta.email,
      role: cuenta.role,
      password,
      elegida: cuenta.password !== undefined,
    });
    filas.push({
      name: cuenta.name,
      email: cuenta.email,
      passwordHash: await hashPassword(password),
      role: cuenta.role,
      joinedAt: new Date(),
    });
  }
  await db.insert(s.users).values(filas);

  return credenciales;
}

/**
 * Contraseñas repetidas entre cuentas distintas.
 *
 * No aborta: es una decisión de quien opera, no un error de formato. Pero se
 * dice, porque una clave compartida por varias personas borra la diferencia
 * entre esas cuentas — una filtración las compromete todas a la vez, y ninguna
 * puede sostener después que no fue ella.
 */
export function contrasenasCompartidas(
  credenciales: CredencialCreada[],
): string[][] {
  const porClave = new Map<string, string[]>();
  for (const c of credenciales) {
    porClave.set(c.password, [...(porClave.get(c.password) ?? []), c.email]);
  }
  return [...porClave.values()].filter((correos) => correos.length > 1);
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
      'Falta el archivo de cuentas.\n\n' +
        '  npm run seed:prod -- ./admins.json\n\n' +
        'Contenido esperado:\n' +
        '  [{ "name": "Nombre Real", "email": "persona@enactuscolombia.org",\n' +
        '     "role": "superadmin" }]\n\n' +
        '`role` es "superadmin" o "admin" (por defecto superadmin).\n' +
        '`password` es opcional: sin ella se genera una al azar.\n\n' +
        'Ese archivo NO se versiona.',
    );
  }

  const cuentas = adminsSchema.parse(
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
          'seed:prod es para una base recién creada. Si de verdad quiere ' +
          'escribir encima, pasá --force.',
      );
    }

    console.log(`Sembrando producción en ${redactUrl(databaseUrl)}…`);
    console.log(`Entorno: ${env.NODE_ENV}`);
    const credenciales = await seedProduccion(db, cuentas);

    console.log('\nListo:');
    console.log(`  ${ODS.length} ODS · ${COMPETENCIES.length} competencias`);
    console.log(`  ${LABS.length} laboratorios, con 3 fases cada uno`);
    console.log(`  ${credenciales.length} cuentas de administración\n`);

    const generadas = credenciales.filter((c) => !c.elegida);
    if (generadas.length > 0) {
      console.log('CONTRASEÑAS GENERADAS — se muestran UNA sola vez.');
      console.log('Entregalas por un canal seguro:\n');
      for (const c of generadas) {
        console.log(`  ${c.role.padEnd(10)} ${c.email.padEnd(38)} ${c.password}`);
      }
      console.log('');
    }

    const elegidas = credenciales.filter((c) => c.elegida);
    if (elegidas.length > 0) {
      console.log('Cuentas con contraseña elegida (no se muestra):\n');
      for (const c of elegidas) {
        console.log(`  ${c.role.padEnd(10)} ${c.email}`);
      }
      console.log('');
    }

    for (const compartida of contrasenasCompartidas(credenciales)) {
      console.log(
        `AVISO: ${compartida.length} cuentas comparten la misma contraseña:\n` +
          compartida.map((e) => `  · ${e}`).join('\n') +
          '\n  Una filtración las compromete a todas, y ninguna puede sostener\n' +
          '  después que no fue ella. Conviene una distinta por persona.\n',
      );
    }
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
