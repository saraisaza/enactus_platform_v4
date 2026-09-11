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
const REPORTE = resolve(__dirname, '../scripts/reporte-universidades.sql');
const CATALOGO = resolve(__dirname, '../drizzle/0006_catalogo_universidades.sql');

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
  await sql`delete from group_members`;
  await sql`delete from groups`;
  await sql`delete from projects`;
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

  it('las apariciones se SUMAN entre users y groups, no se comparan por fuente', async () => {
    // El caso que descubre el fallo: «Nombre Uno» aparece 2 veces en users y 2
    // en groups —4 en total— y «nombre uno» 3 veces, solo en users.
    //
    // Sumando, gana «Nombre Uno» (4 > 3). Comparando el máximo por fuente,
    // como hacía la primera versión, gana «nombre uno» con sus 3 contra los 2
    // de cada fuente por separado. El nombre canónico salía mal sin que nada
    // fallara: la fusión ocurría igual, solo que la lista mostraba la variante
    // equivocada.
    await crearUsuario('A Uno', 'student', 'Universidad Ejemplo', 'enactus');
    await crearUsuario('B Dos', 'student', 'Universidad Ejemplo', 'enactus');
    await crearUsuario('C Tres', 'student', 'universidad ejemplo', 'enactus');
    await crearUsuario('D Cuatro', 'student', 'universidad ejemplo', 'enactus');
    await crearUsuario('E Cinco', 'student', 'universidad ejemplo', 'enactus');

    // Dos equipos con la variante en mayúsculas. `groups` exige proyecto.
    const [proyecto] = await sql<{ id: string }[]>`
      insert into projects (name) values ('Proyecto de prueba') returning id`;
    await sql`insert into groups (name, project_id, university)
              values ('Equipo Uno', ${proyecto!.id}, 'Universidad Ejemplo'),
                     ('Equipo Dos', ${proyecto!.id}, 'Universidad Ejemplo')`;

    await correrRelleno();

    const [uni] = await sql<{ name: string }[]>`
      select name from universities where slug = 'universidad ejemplo'`;
    expect(uni!.name).toBe('Universidad Ejemplo');
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

describe('el reporte del relleno es accionable', () => {
  /**
   * El reporte es un insumo de R2 y R3, no un adorno: hasta que «Sin asignar»
   * esté vacío y los pares candidatos estén resueltos, R3 no se puede
   * desplegar — ahí las lecturas pasan a id y un estudiante mal mapeado
   * DESAPARECE del portal de su asesor.
   *
   * Se ejercita el `.sql` que se corre de verdad. Un reporte que no se
   * ejecuta nunca es un reporte que dejó de compilar hace tres migraciones y
   * nadie lo sabe.
   */
  it('corre entero y encuentra el par que NO se fusionó', async () => {
    await crearUsuario('Ana Uno', 'student', 'Universidad de los Andes', 'enactus');
    await crearUsuario('Beto Dos', 'student', 'universidad de los andes ', 'enactus');
    // Abreviatura: mismo sitio en la realidad, slug distinto. El relleno NO la
    // fusiona —adivinar mal junta dos universidades de verdad— así que tiene
    // que salir en el reporte para que una persona decida.
    await crearUsuario('Caro Tres', 'student', 'U. de los Andes', 'enactus');
    await crearUsuario('Eva Cinco', 'student', '', 'enactus');
    await crearUsuario('Suelto Asesor', 'advisor', '');
    await correrRelleno();

    const bloques = readFileSync(REPORTE, 'utf8')
      .split(/\n(?=-- \d\.)/)
      .filter((b) => /\b(SELECT|WITH)\b/.test(b));
    expect(bloques.length, 'el reporte perdió bloques').toBeGreaterThanOrEqual(7);

    const salidas: Record<string, unknown[]> = {};
    for (const bloque of bloques) {
      // El número del bloque. Si un bloque perdiera su encabezado `-- N.` no
      // se podría afirmar sobre él, así que se falla acá y no más adelante
      // con un `undefined` que parecería otra cosa.
      const encabezado = bloque.match(/^-- (\d)\./m);
      if (!encabezado) throw new Error(`Un bloque del reporte no tiene «-- N.»: ${bloque.slice(0, 60)}`);
      const titulo = encabezado[1]!;
      const consulta = bloque
        .split('\n')
        .filter((l) => !l.startsWith('--'))
        .join('\n')
        .trim();
      if (!consulta) continue;
      // Que cada bloque EJECUTE ya es la mitad de la prueba: un `.sql` suelto
      // se rompe en silencio cuando cambia una columna.
      salidas[titulo] = await sql.unsafe(consulta);
    }

    // 3 · el par candidato, con su camino de fusión escrito.
    const pares = salidas['3'] as { candidata_a: string; candidata_b: string; como_fusionar: string }[];
    expect(pares.length, 'no detectó «U. de los Andes» junto a «Universidad de los Andes»')
      .toBeGreaterThan(0);
    const nombres = pares.flatMap((p) => [p.candidata_a, p.candidata_b]);
    expect(nombres).toContain('U. de los Andes');
    expect(nombres).toContain('Universidad de los Andes');
    // Y el camino no es un consejo: es SQL que se puede pegar.
    expect(pares[0]!.como_fusionar).toMatch(/UPDATE users SET university_id/);
    expect(pares[0]!.como_fusionar).toMatch(/UPDATE projects SET university_id/);
    expect(pares[0]!.como_fusionar).toMatch(/deleted_at = now\(\)/);

    // 4 · quién quedó en «Sin asignar», con nombre y correo para ir a
    //     preguntarle. Un conteo no dice a quién escribirle.
    const sinAsignar = salidas['4'] as { name: string; email: string }[];
    expect(sinAsignar.map((f) => f.name)).toContain('Eva Cinco');
    expect(sinAsignar[0]!.email).toBeTruthy();

    // 5 · los asesores que en R3 no verían a NADIE.
    const asesores = salidas['5'] as { name: string }[];
    expect(asesores.map((f) => f.name)).toContain('Suelto Asesor');

    // 6 · texto contra id. Tiene que dar cero: es la condición de R3.
    expect(salidas['6'], 'texto e id no coinciden tras el relleno').toEqual([]);

    // 7 · universidades activas sin asesor (INV-4). «Universidad de los
    //     Andes» no tiene ninguno en este caso, así que tiene que salir —con
    //     el conteo de estudiantes que quedarían sin que nadie los vea.
    const sinAsesor = salidas['7'] as { name: string; estudiantes_sin_asesor: number }[];
    expect(sinAsesor.map((f) => f.name)).toContain('Universidad de los Andes');
    expect(Number(sinAsesor[0]!.estudiantes_sin_asesor)).toBeGreaterThan(0);
  });
});

describe('el catálogo de las 33 universidades de la red', () => {
  async function correrCatalogo(): Promise<void> {
    const texto = readFileSync(CATALOGO, 'utf8');
    for (const s of texto.split('--> statement-breakpoint')) {
      const q = s.trim();
      if (q && !/^(--[^\n]*\n?)*$/.test(q)) await sql.unsafe(q);
    }
  }

  it('entran las 33 y ninguna queda sin slug', async () => {
    await correrCatalogo();
    const filas = await sql<{ n: number }[]>`
      select count(*)::int as n from universities where slug <> 'sin asignar'`;
    expect(filas[0]!.n).toBe(33);

    const sinSlug = await sql`select name from universities where slug is null or slug = ''`;
    expect(sinSlug.length).toBe(0);
  });

  it('correrlo dos veces no duplica', async () => {
    await correrCatalogo();
    const [antes] = await sql<{ n: number }[]>`select count(*)::int as n from universities`;
    await correrCatalogo();
    const [despues] = await sql<{ n: number }[]>`select count(*)::int as n from universities`;
    expect(despues!.n).toBe(antes!.n);
  });

  it('el slug lo calcula la MISMA función que el relleno, no una copia a mano', async () => {
    await correrCatalogo();
    // Si el catálogo escribiera sus slugs a mano, una universidad de la lista
    // y la misma escrita por una persona podrían normalizar distinto y entrar
    // como dos filas. Se comprueba que coincidan para las 33.
    const desalineadas = await sql<{ name: string }[]>`
      select name from universities
       where slug <> enactus_normalizar_universidad(name)`;
    expect(desalineadas.map((f) => f.name)).toEqual([]);
  });

  it('las siglas entre paréntesis quedan como nombre corto, no en el nombre', async () => {
    await correrCatalogo();
    const [uniminuto] = await sql<{ name: string; short_name: string }[]>`
      select name, short_name from universities where short_name = 'UNIMINUTO'`;
    expect(uniminuto!.name).toBe('Corporación Universitaria Minuto de Dios (UNIMINUTO)');
    // El nombre completo se conserva tal cual llegó: es el oficial y es el que
    // alguien reconoce. El corto es para chips y tablas, donde no cabe.
    expect(uniminuto!.short_name).toBe('UNIMINUTO');
  });

  it('una universidad que ya existía con otro nombre NO se fusiona sola', async () => {
    // «Universidad Nacional» (la que hay en el sembrado) y «Universidad
    // Nacional de Colombia» (la del catálogo) son slugs distintos. El catálogo
    // NO las junta: fusionarlas sería adivinar, y adivinar mal une dos
    // universidades de verdad. Sale en el bloque 3 del reporte.
    await crearUsuario('Ana Uno', 'student', 'Universidad Nacional', 'enactus');
    await correrRelleno();
    await correrCatalogo();

    const filas = await sql<{ slug: string }[]>`
      select slug from universities where slug like 'universidad nacional%' order by slug`;
    expect(filas.map((f) => f.slug)).toEqual([
      'universidad nacional',
      'universidad nacional abierta y a distancia (unad)',
      'universidad nacional de colombia',
    ]);
  });
});
