import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { makeTestClient } from './helpers/db';

/**
 * La migración 0007 corrida COMO SE DESPLIEGA, no como la corre el resto de
 * la suite.
 *
 * El resto de las pruebas migra una base vacía: las ocho migraciones en UNA
 * transacción, con el enum `video_type` naciendo ahí mismo. En ese escenario
 * PostgreSQL deja usar un valor de enum recién agregado. Al desplegar no: la
 * base ya existe, 0007 corre sola en su transacción, y usar `'youtube'` como
 * enum en el CHECK falla con «unsafe use of new value». Ese fallo pasaría
 * todo CI en verde y aparecería en el pipeline, a mitad del despliegue.
 *
 * Así que acá se reproduce el despliegue: una base migrada hasta 0006 y con
 * datos, y después 0007 sola. Y el reverso, que se escribe a mano y por eso
 * es lo que más fácil se pudre sin que nadie lo note.
 */

const CARPETA = resolve(__dirname, '../drizzle');
const TAG = '0007_video_youtube';
const REVERSO = resolve(CARPETA, 'down', `${TAG}.down.sql`);
const ID = 'dQw4w9WgXcQ';

let hasta0006 = '';
let hasta0007 = '';

/**
 * Copia de `drizzle/` cuyo registro solo tiene las migraciones que [incluir]
 * acepta.
 *
 * Se migra hasta 0007 y no hasta la última: el reverso de abajo borra el
 * registro de la migración MÁS RECIENTE, y con migraciones posteriores a 0007
 * aplicadas, esa ya no sería 0007.
 */
function carpetaCon(incluir: (tag: string) => boolean): string {
  const dir = mkdtempSync(join(tmpdir(), 'migraciones-'));
  cpSync(CARPETA, dir, { recursive: true });
  const ruta = join(dir, 'meta', '_journal.json');
  const journal = JSON.parse(readFileSync(ruta, 'utf8')) as {
    entries: { tag: string }[];
  };
  journal.entries = journal.entries.filter((e) => incluir(e.tag));
  writeFileSync(ruta, JSON.stringify(journal));
  return dir;
}

/**
 * Un cliente por paso. Al recrear el esquema los enum nacen con OID nuevos, y
 * un cliente de `postgres.js` que los tenía en caché falla con «cache lookup
 * failed for type» (ver `universidades.test.ts`).
 */
async function conCliente<T>(fn: (sql: Sql) => Promise<T>): Promise<T> {
  const sql = makeTestClient();
  try {
    return await fn(sql);
  } finally {
    await sql.end();
  }
}

const migrarCon = (carpeta: string) =>
  conCliente((sql) => migrate(drizzle(sql), { migrationsFolder: carpeta }));

beforeAll(async () => {
  hasta0006 = carpetaCon((tag) => tag < TAG);
  hasta0007 = carpetaCon((tag) => tag <= TAG);
  await conCliente(async (sql) => {
    await sql.unsafe('drop schema if exists public cascade');
    await sql.unsafe('drop schema if exists drizzle cascade');
    await sql.unsafe('create schema public');
  });
  await migrarCon(hasta0006);
}, 120_000);

afterAll(() => {
  rmSync(hasta0006, { recursive: true, force: true });
  rmSync(hasta0007, { recursive: true, force: true });
});

describe('0007 sobre una base que ya existía', () => {
  let externa = '';
  let propia = '';

  it('se aplica sola, en su propia transacción, con datos adentro', async () => {
    // Lecciones como las que hay hoy en producción: una de YouTube guardada
    // como enlace y un video propio. El CHECK nuevo se valida contra ellas.
    await conCliente(async (sql) => {
      const [curso] = await sql<{ id: string }[]>`
        insert into courses (name) values ('Curso previo') returning id`;
      const [modulo] = await sql<{ id: string }[]>`
        insert into course_modules (course_id, order_index, title)
        values (${curso!.id}, 1, 'Módulo') returning id`;
      const [conEnlace] = await sql<{ id: string }[]>`
        insert into lessons (course_module_id, title, type, video_type, video_url)
        values (${modulo!.id}, 'Enlace', 'video', 'external',
                ${`https://www.youtube.com/watch?v=${ID}`})
        returning id`;
      const [conArchivo] = await sql<{ id: string }[]>`
        insert into lessons (course_module_id, title, type, video_type, video_s3_key)
        values (${modulo!.id}, 'Propio', 'video', 'uploaded', 'lessons/x/video.mp4')
        returning id`;
      externa = conEnlace!.id;
      propia = conArchivo!.id;
    });

    await migrarCon(hasta0007);

    await conCliente(async (sql) => {
      const valores = await sql<{ v: string }[]>`
        select unnest(enum_range(null::video_type))::text as v`;
      expect(valores.map((r) => r.v)).toEqual(['external', 'uploaded', 'youtube']);

      // Lo que había sigue igual y sigue siendo válido.
      const [e] = await sql<{ video_type: string; video_youtube_id: null }[]>`
        select video_type, video_youtube_id from lessons where id = ${externa}`;
      expect(e).toEqual({ video_type: 'external', video_youtube_id: null });

      // Y lo nuevo entra.
      await sql`update lessons
                   set video_type = 'youtube', video_youtube_id = ${ID},
                       video_s3_key = null
                 where id = ${propia}`;
    });
  });

  it('el reverso convierte las de YouTube en enlaces, sin perder cuál era', async () => {
    // Igual que `npm run db:rollback`: el archivo de bajada en una
    // transacción, y recién después se borra el registro de la migración.
    await conCliente(async (sql) => {
      // Una persona para que la fila de posición tenga a quién apuntar.
      await sql`insert into users (name, email, password_hash, role, student_type)
                values ('Alguien', 'alguien@prueba.test', '$2b$10$x', 'student',
                        'enactus')`;
      await sql`insert into lesson_video_progress
                  (student_id, lesson_id, position_sec, furthest_sec, duration_sec)
                select id, ${propia}, 30, 90, 212 from users
                on conflict do nothing`;

      const [ultima] = await sql<{ id: number }[]>`
        select id from drizzle.__drizzle_migrations
         order by created_at desc limit 1`;
      await sql.begin(async (tx) => {
        await tx.unsafe(readFileSync(REVERSO, 'utf8'));
        await tx`delete from drizzle.__drizzle_migrations where id = ${ultima!.id}`;
      });

      const [convertida] = await sql<{ video_type: string; video_url: string }[]>`
        select video_type, video_url from lessons where id = ${propia}`;
      expect(convertida).toEqual({
        video_type: 'external',
        video_url: `https://www.youtube.com/watch?v=${ID}`,
      });

      const columnas = await sql`
        select 1 from information_schema.columns
         where table_name = 'lessons' and column_name = 'video_youtube_id'`;
      expect(columnas.length).toBe(0);
      const [tabla] = await sql<{ existe: string | null }[]>`
        select to_regclass('public.lesson_video_progress')::text as existe`;
      expect(tabla!.existe).toBeNull();
    });
  });

  it('y 0007 se puede volver a aplicar después del reverso', async () => {
    // El valor `youtube` del enum sobrevive al reverso (PostgreSQL no sabe
    // quitarlo): sin `IF NOT EXISTS`, esto fallaría con «already exists».
    await migrarCon(hasta0007);
    await conCliente(async (sql) => {
      const columnas = await sql`
        select 1 from information_schema.columns
         where table_name = 'lessons' and column_name = 'video_youtube_id'`;
      expect(columnas.length).toBe(1);
    });
  });
});
