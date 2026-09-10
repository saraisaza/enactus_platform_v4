import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { makeTestClient, resetTestDatabase } from './helpers/db';

/**
 * El relleno de universidades (migración 0005).
 *
 * Se ejecuta **el SQL que de verdad se despliega**, leído del archivo de
 * migración, no una copia escrita para la prueba. Una copia probaría que la
 * copia funciona: el día que alguien toque la migración y no la copia, la
 * prueba seguiría verde sobre código que ya no existe.
 *
 * Es el mismo razonamiento por el que las pruebas de guardias van contra el
 * endpoint real y no contra una ruta sintética.
 */

const MIGRACION = resolve(__dirname, '../drizzle/0005_universidades.sql');

let sql: Sql;

/**
 * Las sentencias del RELLENO, sin las del esquema.
 *
 * El esquema ya está aplicado cuando la prueba corre —`resetTestDatabase`
 * migra— así que reaplicarlo fallaría. El relleno, en cambio, está escrito
 * para ser idempotente, y eso es justo lo que se quiere ejercitar.
 */
function sentenciasDeRelleno(): string[] {
  const texto = readFileSync(MIGRACION, 'utf8');
  const marca = texto.indexOf('-- RELLENO.');
  if (marca === -1) {
    throw new Error(
      'No encontré la marca «-- RELLENO.» en 0005_universidades.sql. ' +
        'Si se renombró, esta prueba dejó de ejercitar lo que cree.',
    );
  }
  return texto
    .slice(marca)
    .split('--> statement-breakpoint')
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !/^(--[^\n]*\n?)*$/.test(s));
}

async function correrRelleno(): Promise<void> {
  for (const sentencia of sentenciasDeRelleno()) {
    await sql.unsafe(sentencia);
  }
}

/** Un usuario mínimo. Solo interesan `role`, `student_type` y `university`. */
async function crearUsuario(
  nombre: string,
  rol: string,
  universidad: string,
  tipo: string | null = null,
): Promise<string> {
  const [fila] = await sql<{ id: string }[]>`
    insert into users (name, email, password_hash, role, university, student_type)
    values (${nombre}, ${`${nombre.replace(/\s+/g, '.').toLowerCase()}@prueba.test`},
            '$2b$10$prueba', ${rol}::user_role, ${universidad},
            ${tipo}::student_type)
    returning id`;
  return fila!.id;
}

beforeAll(async () => {
  // El esquema se recrea UNA vez. Hacerlo entre casos rompía con «cache lookup
  // failed for type»: `resetTestDatabase` borra y recrea el esquema, los tipos
  // enum nacen con OID nuevos, y el cliente de `postgres.js` los tiene
  // cacheados de la conexión anterior. Se limpian filas, no tipos.
  await resetTestDatabase();
  sql = makeTestClient();
}, 120_000);

beforeEach(async () => {
  // En orden de dependencia: `users.university_id` es `restrict`, así que las
  // universidades no se pueden borrar antes que sus usuarios.
  await sql`delete from university_advisors`;
  await sql`delete from users`;
  await sql`delete from universities`;
});

afterAll(async () => {
  await sql.end();
});

describe('el relleno fusiona las variantes de un mismo nombre', () => {
  it('«Universidad de los Andes», «universidad de los andes » y «U. de los Andes»', async () => {
    await crearUsuario('Ana Uno', 'student', 'Universidad de los Andes', 'enactus');
    await crearUsuario('Beto Dos', 'student', 'universidad de los andes ', 'enactus');
    await crearUsuario('Caro Tres', 'student', 'Universidad de los Andes', 'enactus');
    // «U. de los Andes» NO se fusiona con las anteriores, y es correcto: no es
    // una variante tipográfica sino una abreviatura distinta. Fusionarlas
    // exigiría adivinar, y adivinar mal junta dos universidades de verdad.
    await crearUsuario('Dani Cuatro', 'student', 'U. de los Andes', 'enactus');
    await crearUsuario('Eva Cinco', 'student', '  Universidad   Nacional  ', 'enactus');

    await correrRelleno();

    const filas = await sql<{ name: string; slug: string }[]>`
      select name, slug from universities where slug <> 'sin asignar' order by slug`;

    const andes = filas.filter((f) => f.slug === 'universidad de los andes');
    expect(andes.length, 'las tres variantes de Andes tienen que ser UNA fila').toBe(1);
    // El nombre canónico es la variante más frecuente: «Universidad de los
    // Andes» aparece 2 veces, la de minúsculas 1.
    expect(andes[0]!.name).toBe('Universidad de los Andes');

    // Los espacios de más se colapsan, y el nombre queda recortado.
    const nacional = filas.filter((f) => f.slug === 'universidad nacional');
    expect(nacional.length).toBe(1);
    expect(nacional[0]!.name).toBe('Universidad   Nacional');

    // Y los cuatro de Andes-con-variante apuntan a la MISMA fila.
    const [conteo] = await sql<{ n: number }[]>`
      select count(distinct university_id)::int as n
        from users
       where university in ('Universidad de los Andes', 'universidad de los andes ')`;
    expect(conteo!.n).toBe(1);
  });

  it('correrlo dos veces no duplica nada', async () => {
    await crearUsuario('Ana Uno', 'student', 'Universidad de los Andes', 'enactus');
    await crearUsuario('Jorge Asesor', 'advisor', 'Universidad de los Andes');

    await correrRelleno();
    const primera = await sql<{ n: number }[]>`select count(*)::int as n from universities`;
    const puentes1 = await sql<{ n: number }[]>`select count(*)::int as n from university_advisors`;

    await correrRelleno();
    const segunda = await sql<{ n: number }[]>`select count(*)::int as n from universities`;
    const puentes2 = await sql<{ n: number }[]>`select count(*)::int as n from university_advisors`;

    expect(segunda[0]!.n).toBe(primera[0]!.n);
    expect(puentes2[0]!.n).toBe(puentes1[0]!.n);
  });
});

describe('el relleno no descarta nada en silencio', () => {
  it('un estudiante Enactus sin universidad legible va a «Sin asignar»', async () => {
    const id = await crearUsuario('Sin Uni', 'student', '', 'enactus');
    await correrRelleno();

    const [fila] = await sql<{ slug: string; active: boolean }[]>`
      select un.slug, un.active
        from users u join universities un on un.id = u.university_id
       where u.id = ${id}`;
    expect(fila!.slug).toBe('sin asignar');
    // Inactiva: no debe aparecer como destino elegible en ningún desplegable.
    expect(fila!.active).toBe(false);
  });

  it('un Open Learning se queda SIN universidad, que es su estado correcto', async () => {
    const id = await crearUsuario('Camila OL', 'student', '', 'open_learning');
    await correrRelleno();

    const [fila] = await sql<{ university_id: string | null }[]>`
      select university_id from users where id = ${id}`;
    // INV-9. Mandarlo a «Sin asignar» sería tratar como hueco lo que es una
    // decisión: Open Learning no lleva universidad.
    expect(fila!.university_id).toBeNull();
  });
});

describe('los asesores quedan en la tabla puente', () => {
  it('un asesor con universidad entra en university_advisors', async () => {
    const id = await crearUsuario('Jorge Asesor', 'advisor', 'Universidad Nacional');
    await correrRelleno();

    const filas = await sql<{ slug: string }[]>`
      select un.slug
        from university_advisors ua
        join universities un on un.id = ua.university_id
       where ua.user_id = ${id}`;
    expect(filas.length).toBe(1);
    expect(filas[0]!.slug).toBe('universidad nacional');
  });

  it('un asesor sin universidad no entra, y eso es visible', async () => {
    const id = await crearUsuario('Asesor Suelto', 'advisor', '');
    await correrRelleno();

    const filas = await sql`select 1 from university_advisors where user_id = ${id}`;
    expect(filas.length).toBe(0);
    // Tampoco se le inventa la marcadora: un asesor sin universidad es un
    // problema de datos que alguien tiene que resolver, no algo que la
    // migración deba tapar eligiendo por él.
    const [u] = await sql<{ university_id: string | null }[]>`
      select university_id from users where id = ${id}`;
    expect(u!.university_id).toBeNull();
  });
});
