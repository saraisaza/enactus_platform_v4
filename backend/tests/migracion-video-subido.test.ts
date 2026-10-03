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
 * La migración 0008 corrida COMO SE DESPLIEGA: sola, sobre una base que ya
 * estaba en 0007 y con datos. Y lo que la hace delicada, que es el trigger:
 * qué keys anota para borrar y, sobre todo, cuáles NO.
 */

const CARPETA = resolve(__dirname, '../drizzle');
const TAG = '0008_video_subido';
const REVERSO = resolve(CARPETA, 'down', `${TAG}.down.sql`);

let hasta0007 = '';
let hasta0008 = '';

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

/** Lo que hay en la cola, ordenado para comparar. */
const cola = () =>
  conCliente(async (sql) =>
    (
      await sql<{ key: string; reason: string }[]>`
        select key, reason from storage_pending_deletes order by key`
    ).map((r) => ({ key: r.key, reason: r.reason })),
  );

const vaciarCola = () =>
  conCliente((sql) => sql`delete from storage_pending_deletes`);

beforeAll(async () => {
  hasta0007 = carpetaCon((tag) => tag < TAG);
  hasta0008 = carpetaCon((tag) => tag <= TAG);
  await conCliente(async (sql) => {
    await sql.unsafe('drop schema if exists public cascade');
    await sql.unsafe('drop schema if exists drizzle cascade');
    await sql.unsafe('create schema public');
  });
  await migrarCon(hasta0007);
}, 120_000);

afterAll(() => {
  rmSync(hasta0007, { recursive: true, force: true });
  rmSync(hasta0008, { recursive: true, force: true });
});

describe('0008 sobre una base que ya existía', () => {
  let modulo = '';
  let subida = '';
  let delSeed = '';

  it('se aplica sola, con datos adentro, y lo que había sigue igual', async () => {
    await conCliente(async (sql) => {
      const [curso] = await sql<{ id: string }[]>`
        insert into courses (name) values ('Curso previo') returning id`;
      const [m] = await sql<{ id: string }[]>`
        insert into course_modules (course_id, order_index, title)
        values (${curso!.id}, 1, 'Módulo') returning id`;
      modulo = m!.id;
      const [a] = await sql<{ id: string }[]>`
        insert into lessons (course_module_id, title, type, video_type, video_s3_key)
        values (${modulo}, 'Subido', 'video', 'uploaded', 'lessons/a/video-1.mp4')
        returning id`;
      // Una key del seed: no empieza por `lessons/`.
      const [b] = await sql<{ id: string }[]>`
        insert into lessons (course_module_id, title, type, video_type, video_s3_key)
        values (${modulo}, 'Del seed', 'video', 'uploaded',
                'lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4')
        returning id`;
      subida = a!.id;
      delSeed = b!.id;
    });

    await migrarCon(hasta0008);

    await conCliente(async (sql) => {
      const [fila] = await sql<
        {
          video_s3_key: string;
          video_thumbnail_s3_key: string | null;
          video_original_name: string | null;
          video_uploaded_at: Date | null;
        }[]
      >`select video_s3_key, video_thumbnail_s3_key, video_original_name,
               video_uploaded_at
          from lessons where id = ${subida}`;
      expect(fila).toEqual({
        video_s3_key: 'lessons/a/video-1.mp4',
        video_thumbnail_s3_key: null,
        video_original_name: null,
        video_uploaded_at: null,
      });
    });
    // Migrar no anota nada: agregar columnas no dispara el trigger.
    expect(await cola()).toEqual([]);
  });

  it('cambiar el título no anota nada', async () => {
    await conCliente((sql) => sql`update lessons set title = 'Otro' where id = ${subida}`);
    expect(await cola()).toEqual([]);
  });

  it('reemplazar el video anota el anterior', async () => {
    await conCliente(
      (sql) => sql`update lessons set video_s3_key = 'lessons/a/video-2.mp4'
                    where id = ${subida}`,
    );
    expect(await cola()).toEqual([
      { key: 'lessons/a/video-1.mp4', reason: 'video_replaced' },
    ]);
    await vaciarCola();
  });

  it('reemplazar o quitar la portada anota la anterior', async () => {
    await conCliente(async (sql) => {
      await sql`update lessons set video_thumbnail_s3_key = 'lessons/a/thumb-1.jpg'
                 where id = ${subida}`;
      // Ponerla por primera vez no anota nada.
      expect(await cola()).toEqual([]);
      await sql`update lessons set video_thumbnail_s3_key = 'lessons/a/thumb-2.jpg'
                 where id = ${subida}`;
    });
    expect(await cola()).toEqual([
      { key: 'lessons/a/thumb-1.jpg', reason: 'thumbnail_replaced' },
    ]);
    await vaciarCola();
  });

  it('pasar la lección a YouTube anota el video y la portada', async () => {
    await conCliente(
      (sql) => sql`update lessons
                      set video_type = 'youtube', video_youtube_id = 'dQw4w9WgXcQ',
                          video_s3_key = null, video_thumbnail_s3_key = null
                    where id = ${subida}`,
    );
    expect(await cola()).toEqual([
      { key: 'lessons/a/thumb-2.jpg', reason: 'thumbnail_replaced' },
      { key: 'lessons/a/video-2.mp4', reason: 'video_replaced' },
    ]);
    await vaciarCola();
  });

  it('borrar el módulo se lleva las lecciones en cascada, y el trigger lo ve', async () => {
    await conCliente(async (sql) => {
      await sql`update lessons
                   set video_type = 'uploaded', video_youtube_id = null,
                       video_s3_key = 'lessons/a/video-3.mp4',
                       video_thumbnail_s3_key = 'lessons/a/thumb-3.jpg'
                 where id = ${subida}`;
      await sql`delete from storage_pending_deletes`;
      await sql`delete from course_modules where id = ${modulo}`;
      const quedan = await sql`select 1 from lessons where id in (${subida}, ${delSeed})`;
      expect(quedan.length).toBe(0);
    });
    // Las dos de la lección subida, y NADA del seed: esa key la comparten
    // staging y producción en el mismo bucket.
    expect(await cola()).toEqual([
      { key: 'lessons/a/thumb-3.jpg', reason: 'lesson_deleted' },
      { key: 'lessons/a/video-3.mp4', reason: 'lesson_deleted' },
    ]);
  });

  it('el reverso quita el trigger, la cola y las columnas', async () => {
    await conCliente(async (sql) => {
      const [ultima] = await sql<{ id: number }[]>`
        select id from drizzle.__drizzle_migrations
         order by created_at desc limit 1`;
      await sql.begin(async (tx) => {
        await tx.unsafe(readFileSync(REVERSO, 'utf8'));
        await tx`delete from drizzle.__drizzle_migrations where id = ${ultima!.id}`;
      });

      const columnas = await sql`
        select column_name from information_schema.columns
         where table_name = 'lessons'
           and column_name in ('video_thumbnail_s3_key', 'video_original_name',
                               'video_uploaded_at')`;
      expect(columnas.length).toBe(0);
      const [tabla] = await sql<{ existe: string | null }[]>`
        select to_regclass('public.storage_pending_deletes')::text as existe`;
      expect(tabla!.existe).toBeNull();
      const triggers = await sql`
        select 1 from pg_trigger where tgname = 'lessons_queue_file_deletion'`;
      expect(triggers.length).toBe(0);
    });
  });

  it('y 0008 se puede volver a aplicar después del reverso', async () => {
    await migrarCon(hasta0008);
    await conCliente(async (sql) => {
      const triggers = await sql`
        select 1 from pg_trigger where tgname = 'lessons_queue_file_deletion'`;
      expect(triggers.length).toBe(1);
    });
  });
});
