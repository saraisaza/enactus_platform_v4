import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';

/**
 * Tareas de base de datos contra la instancia privada.
 *
 * La base vive en una subred sin salida a internet —que es lo que se
 * buscaba—, así que migrar y sembrar no se puede hacer desde un portátil ni
 * desde un *runner* de GitHub. Esta función es el camino: la invoca una
 * persona o el pipeline, y corre dentro de la VPC.
 *
 * A diferencia de `enactus-db-admin` —que recibe SQL suelto y las credenciales
 * en la invocación— esta trae el código real de la aplicación: el migrador de
 * Drizzle y los dos *seeds*. Así lo que corre en producción es exactamente lo
 * mismo que se probó en local, no una traducción a mano.
 *
 * El entorno llega en el evento y decide qué secreto se lee. Un `entorno`
 * equivocado no puede tocar la base que no es: cada usuario está encerrado en
 * la suya.
 */

interface Evento {
  entorno: 'staging' | 'prod';
  tarea: 'migrar' | 'sembrar-demo' | 'sembrar-prod';
  /** Solo para `sembrar-prod`: las cuentas de administración reales. */
  admins?: { name: string; email: string; role?: string; password?: string }[];
}

const s3 = new S3Client({});

async function configuracionDe(entorno: string): Promise<void> {
  const bucket = process.env.SECRETS_BUCKET;
  if (!bucket) throw new Error('Falta SECRETS_BUCKET.');

  const key = `${entorno}/runtime.json`;
  const respuesta = await s3.send(
    new GetObjectCommand({ Bucket: bucket, Key: key }),
  );
  if (!respuesta.Body) {
    throw new Error(`s3://${bucket}/${key} llegó sin cuerpo.`);
  }
  const config = JSON.parse(await respuesta.Body.transformToString()) as Record<
    string,
    string
  >;

  // A diferencia de la API, acá se PISA lo que hubiera: una invocación para
  // `staging` no puede quedarse con la conexión de `prod` de la invocación
  // anterior, que es el peor error posible en una función que migra y siembra.
  for (const [nombre, valor] of Object.entries(config)) {
    process.env[nombre] = String(valor);
  }
}

export async function handler(evento: Evento) {
  const { entorno, tarea, admins } = evento;
  if (entorno !== 'staging' && entorno !== 'prod') {
    throw new Error(`Entorno inválido: ${String(entorno)}.`);
  }

  await configuracionDe(entorno);

  // Los módulos se importan DESPUÉS de fijar la configuración: `env.ts` la lee
  // al importarse. Y se limpia la caché entre invocaciones para que un
  // contenedor tibio no reutilice la conexión del entorno anterior.
  const { createClient, redactUrl } = await import('./db/connection');
  const { drizzle } = await import('drizzle-orm/postgres-js');
  const esquema = await import('./db/schema');

  const sql = createClient(process.env.DATABASE_URL);
  const db = drizzle(sql, { schema: esquema, casing: 'snake_case' });

  try {
    if (tarea === 'migrar') {
      const { migrate } = await import('drizzle-orm/postgres-js/migrator');
      await migrate(drizzle(sql), { migrationsFolder: './drizzle' });
      const filas = await sql<{ total: number }[]>`
        select count(*)::int as total from information_schema.tables
         where table_schema = 'public'`;
      return {
        ok: true, tarea, entorno,
        destino: redactUrl(process.env.DATABASE_URL ?? ''),
        tablas: filas[0]?.total ?? 0,
      };
    }

    if (tarea === 'sembrar-demo') {
      // Datos de DEMOSTRACIÓN. Que esto no pueda correr contra producción no
      // es una convención: `seed.ts` se niega si NODE_ENV es production, y acá
      // además se corta antes por el entorno.
      if (entorno === 'prod') {
        throw new Error(
          'sembrar-demo está prohibido en prod: sembraría estudiantes ' +
            'inventados y cuentas con contraseñas de ejemplo.',
        );
      }
      const { seed } = await import('./db/seed');
      await seed(db);
      const filas = await sql<{ total: number }[]>`select count(*)::int as total from users`;
      return { ok: true, tarea, entorno, usuarios: filas[0]?.total ?? 0 };
    }

    if (tarea === 'sembrar-prod') {
      if (!admins?.length) {
        throw new Error('sembrar-prod necesita la lista de cuentas en `admins`.');
      }
      const { seedProduccion } = await import('./db/seed-prod');
      const credenciales = await seedProduccion(
        db,
        admins.map((a) => ({
          name: a.name,
          email: a.email,
          role: (a.role ?? 'superadmin') as 'superadmin' | 'admin',
          password: a.password,
        })),
      );
      // Se devuelven los correos y si la contraseña la eligió quien invocó,
      // NUNCA la contraseña: la respuesta va a los logs de quien invoca.
      return {
        ok: true,
        tarea,
        entorno,
        cuentas: credenciales.map((c) => ({
          email: c.email,
          role: c.role,
          contrasenaElegida: c.elegida,
        })),
      };
    }

    throw new Error(`Tarea desconocida: ${String(tarea)}.`);
  } finally {
    await sql.end({ timeout: 5 });
  }
}
