import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Lo que piden los paneles nuevos (2026-11-23): el de la empresa aliada
 * muestra el avance por laboratorio y sus últimos certificados.
 *
 * - `GET /users?include=labs` trae los laboratorios de cada persona.
 * - `GET /certificates` a una empresa le da los de los estudiantes de los
 *   laboratorios que patrocina, y nada más.
 */
let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
const tok: Record<string, string> = {};
const LAB_IA = seedId('lab_ia'); // lo patrocina Bancolombia (emp1)
const EST1 = seedId('est1'); // cursa lab_ia
const EST3 = seedId('est3'); // no cursa lab_ia

const pedir = (ruta: string, token: string) =>
  t.app.request(ruta, { headers: auth(token) });

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  for (const [clave, correo, clave2] of [
    ['empresa', 'empresa@bancolombia.com', 'Empresa123'],
    ['admin', 'admin@enactus.co', 'Admin123'],
  ] as const) {
    tok[clave] = (await login(t.app, correo, clave2)).accessToken;
  }
  // Dos certificados de Ruta puestos a mano (el candado exige la Ruta
  // completa; acá solo importa quién los ve).
  await sql.begin(async (tx) => {
    await tx`alter table certificates disable trigger certificates_require_complete_ruta`;
    for (const [codigo, persona] of [['PANEL-1', EST1], ['PANEL-3', EST3]] as const) {
      await tx`insert into certificates (code, student_id, laboratory_id,
                 student_name_snapshot, laboratory_name_snapshot,
                 issuer_name_snapshot, requirements_snapshot)
               values (${codigo}, ${persona}, ${LAB_IA}, 'Persona', 'Lab',
                       'Equipo', '{}'::jsonb)`;
    }
    await tx`alter table certificates enable trigger certificates_require_complete_ruta`;
  });
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('el panel de la empresa aliada', () => {
  it('ve los certificados de los estudiantes de los laboratorios que patrocina', async () => {
    const res = await pedir('/certificates', tok.empresa!);
    expect(res.status).toBe(200);
    const { data } = (await res.json()) as { data: { code: string }[] };
    const codigos = data.map((c) => c.code);
    expect(codigos).toContain('PANEL-1');
    expect(codigos, 'est3 no cursa un laboratorio suyo').not.toContain('PANEL-3');
  });

  it('`include=labs` dice en qué laboratorios está cada persona', async () => {
    const res = await pedir('/users?pageSize=100&include=labs', tok.admin!);
    const { data } = (await res.json()) as {
      data: { id: string; laboratoryIds?: string[] }[];
    };
    const est1 = data.find((u) => u.id === EST1)!;
    expect(est1.laboratoryIds).toContain(LAB_IA);
    // Sin pedirlo, no viene.
    const sin = await pedir('/users?pageSize=100', tok.admin!);
    const filas = ((await sin.json()) as { data: Record<string, unknown>[] }).data;
    expect(filas.find((u) => u.id === EST1)).not.toHaveProperty('laboratoryIds');
  });
});
