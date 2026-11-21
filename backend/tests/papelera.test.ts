import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * La papelera (recomendaciones del 20 de noviembre, «borrado lógico»).
 *
 * Lo que todavía se borraba de verdad —las piezas de un curso o de una Ruta y
 * los moldes de certificado— deja antes una copia completa en `papelera`. Lo
 * hace la base, con un trigger: vale para lo que borra la API, para lo que se
 * va en cascada y para lo que se borre a mano.
 */
let sql: Sql;

beforeAll(async () => {
  await seedTestDatabase();
  sql = makeTestApp().sql;
}, 120_000);

afterAll(async () => {
  await sql.end();
});

const enPapelera = async (tabla: string, id: string) =>
  (
    await sql<{ datos: Record<string, unknown> }[]>`
      select datos from papelera where tabla = ${tabla} and fila_id = ${id}`
  )[0]?.datos;

describe('cada borrado deja su copia', () => {
  for (const tabla of [
    'lessons',
    'course_modules',
    'ruta_modules',
    'objectives',
    'glossary_terms',
  ]) {
    it(tabla, async () => {
      const [fila] = await sql<{ id: string }[]>`
        select id from ${sql(tabla)} limit 1`;
      if (!fila) return; // el sembrado no trae filas de esta tabla
      const antes = (
        await sql<Record<string, unknown>[]>`select * from ${sql(tabla)} where id = ${fila.id}`
      )[0]!;
      await sql`delete from ${sql(tabla)} where id = ${fila.id}`;
      const copia = await enPapelera(tabla, fila.id);
      expect(copia, `${tabla} ${fila.id}`).toBeDefined();
      expect(copia!.id).toBe(antes.id);
    });
  }

  it('lo que cae en cascada también: el módulo y sus lecciones', async () => {
    const [modulo] = await sql<{ id: string }[]>`
      select m.id from course_modules m
       where exists (select 1 from lessons l where l.course_module_id = m.id) limit 1`;
    const lecciones = await sql<{ id: string }[]>`
      select id from lessons where course_module_id = ${modulo!.id}`;
    await sql`delete from course_modules where id = ${modulo!.id}`;
    expect(await enPapelera('course_modules', modulo!.id)).toBeDefined();
    for (const l of lecciones) {
      expect(await enPapelera('lessons', l.id), l.id).toBeDefined();
    }
  });
});
