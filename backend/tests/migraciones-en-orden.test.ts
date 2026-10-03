import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { describe, expect, it } from 'vitest';

/**
 * El orden de las migraciones, sin base de datos.
 *
 * El migrador de Drizzle lee la ÚLTIMA migración aplicada en la base y aplica
 * solo las del journal cuyo `when` sea posterior. Una migración con un `when`
 * anterior a esa se salta **sin avisar**: el despliegue sale verde y la tabla
 * no existe.
 *
 * Pasa al combinar ramas. La 0007 de `main` (videos de YouTube) y la 0007 del
 * trabajo móvil (moderación del foro) nacieron en paralelo; al renumerar una
 * de ellas, su `when` viejo puede quedar por debajo del de otra ya aplicada en
 * staging. Esta prueba no deja que eso llegue a desplegarse: si falla, a la
 * migración que quedó fuera de orden se le pone un `when` nuevo (el actual,
 * en milisegundos) y se rehace su snapshot.
 */

type Entrada = { idx: number; when: number; tag: string };

const DRIZZLE = resolve(__dirname, '../drizzle');
const { entries } = JSON.parse(
  readFileSync(resolve(DRIZZLE, 'meta/_journal.json'), 'utf8'),
) as { entries: Entrada[] };

describe('drizzle/meta/_journal.json', () => {
  it('los `when` crecen en el orden del journal', () => {
    const fueraDeOrden = entries
      .slice(1)
      .filter((e, i) => e.when <= entries[i]!.when)
      .map((e, i) => `${e.tag} (${e.when}) no es posterior a ${entries[i]!.tag} (${entries[i]!.when})`);
    expect(fueraDeOrden).toEqual([]);
  });

  it('no hay dos migraciones con el mismo número', () => {
    const numeros = entries.map((e) => e.tag.slice(0, 4));
    expect(numeros.length).toBe(new Set(numeros).size);
  });

  it('cada migración tiene su archivo de subida y su reverso escrito a mano', () => {
    const faltan = entries.flatMap((e) => [
      ...(existsSync(resolve(DRIZZLE, `${e.tag}.sql`)) ? [] : [`${e.tag}.sql`]),
      ...(existsSync(resolve(DRIZZLE, 'down', `${e.tag}.down.sql`))
        ? []
        : [`down/${e.tag}.down.sql`]),
    ]);
    expect(faltan).toEqual([]);
  });
});
