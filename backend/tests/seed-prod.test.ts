import { drizzle } from 'drizzle-orm/postgres-js';
import type { Sql } from 'postgres';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import * as schema from '../src/db/schema';
import {
  contrasenasCompartidas,
  seedProduccion,
  type CredencialCreada,
  type CuentaInicial,
} from '../src/db/seed-prod';
import { makeTestClient, resetTestDatabase } from './helpers/db';

/**
 * El seed de producción: lo mínimo para que la plataforma exista.
 *
 * Existe porque la revisión previa al lanzamiento encontró que **no había
 * ninguno**. Solo estaba `db:seed`, que siembra datos de demostración —
 * estudiantes inventados, entregas, foro y cuentas con contraseñas de ejemplo
 * (`Admin123`)— y que además **no se negaba a correr en producción**, aunque
 * `db:reset` sí lo hacía. Entre una base real con estudiantes reales y esa
 * contaminación había un `NODE_ENV` mal puesto en una terminal.
 *
 * Lo que se cuida acá es sobre todo lo que NO tiene que aparecer.
 */

let sql: Sql;

const conBase = async () => {
  await resetTestDatabase();
  sql = makeTestClient();
  return drizzle(sql, { schema, casing: 'snake_case' });
};

beforeEach(async () => {
  if (sql) await sql.end();
});

afterAll(async () => {
  if (sql) await sql.end();
});

const ADMINS: CuentaInicial[] = [
  { name: 'Persona Uno', email: 'uno@enactuscolombia.org', role: 'superadmin' },
  { name: 'Persona Dos', email: 'dos@enactuscolombia.org', role: 'superadmin' },
];

describe('seed:prod', () => {
  it('deja SOLO super admins, 6 laboratorios y los catálogos', async () => {
    const db = await conBase();
    await seedProduccion(db, ADMINS);

    const usuarios = await db.select().from(schema.users);
    expect(usuarios).toHaveLength(2);
    expect(usuarios.every((u) => u.role === 'superadmin')).toBe(true);

    expect(await db.select().from(schema.laboratories)).toHaveLength(6);
    expect(await db.select().from(schema.phases)).toHaveLength(18);
    expect(await db.select().from(schema.odsGoals)).toHaveLength(17);
    expect(await db.select().from(schema.competencies)).toHaveLength(12);
  });

  it('NO deja nada de demostración', async () => {
    // La lista es explícita a propósito: si mañana alguien agrega una llamada
    // del seed de demo acá por comodidad, esta prueba lo dice.
    const db = await conBase();
    await seedProduccion(db, ADMINS);

    for (const [nombre, tabla] of [
      ['proyectos', schema.projects],
      ['grupos', schema.groups],
      ['cursos', schema.courses],
      ['entregas', schema.submissions],
      ['evidencias', schema.evidences],
      ['publicaciones de foro', schema.forumPosts],
      ['notificaciones', schema.notifications],
      ['certificados', schema.certificates],
    ] as const) {
      const filas = await db.select().from(tabla);
      expect(filas, `quedaron ${nombre} en una base de producción`).toHaveLength(0);
    }
  });

  it('las fases quedan vacías y sin fecha límite', async () => {
    // El seed de demo pone plazos vencidos a propósito, para ver las alertas.
    // En producción eso serían avisos de atraso el día uno.
    const db = await conBase();
    await seedProduccion(db, ADMINS);

    const fases = await db.select().from(schema.phases);
    expect(fases.every((f) => f.deadline === null)).toBe(true);
    expect(fases.every((f) => f.description === '')).toBe(true);
  });

  it('los laboratorios no quedan con patrocinador', async () => {
    // El de demo cuelga `lab_ia` de Bancolombia. Un patrocinador inventado en
    // producción le da a esa empresa alcance sobre estudiantes reales.
    const db = await conBase();
    await seedProduccion(db, ADMINS);

    const labs = await db.select().from(schema.laboratories);
    expect(labs.every((l) => l.sponsorCompanyId === null)).toBe(true);
  });

  it('cada admin recibe una contraseña distinta, larga y aleatoria', async () => {
    const db = await conBase();
    const credenciales = await seedProduccion(db, ADMINS);

    expect(credenciales).toHaveLength(2);
    expect(credenciales[0]!.password).not.toBe(credenciales[1]!.password);
    for (const c of credenciales) {
      expect(c.password.length).toBeGreaterThanOrEqual(20);
      // Nada que se parezca a las de demostración.
      expect(c.password).not.toMatch(/^(Admin|Super|Est|Lxd)\d+$/);
    }
  });

  it('la contraseña se guarda hasheada, nunca en claro', async () => {
    const db = await conBase();
    const [credencial] = await seedProduccion(db, [ADMINS[0]!]);

    const [usuario] = await db.select().from(schema.users);
    expect(usuario!.passwordHash).not.toBe(credencial!.password);
    expect(usuario!.passwordHash).toMatch(/^\$2[aby]\$/);
  });

  it('la contraseña generada sirve para entrar', async () => {
    // Sin esto, el seed podría generar credenciales que no funcionan y nadie
    // se enteraría hasta el día del lanzamiento.
    const { verifyPassword } = await import('../src/lib/password');
    const db = await conBase();
    const [credencial] = await seedProduccion(db, [ADMINS[0]!]);

    const [usuario] = await db.select().from(schema.users);
    expect(await verifyPassword(credencial!.password, usuario!.passwordHash)).toBe(true);
  });
});

describe('roles y contraseñas elegidas', () => {
  it('crea admins además de superadmins, con el rol que dice el archivo', async () => {
    // El equipo real no es solo superadmins: hay una cuenta de arranque y
    // varias de administración. Si todas quedaran como superadmin, cualquiera
    // de ellas podría restaurar un respaldo encima de la base entera.
    const db = await conBase();
    await seedProduccion(db, [
      { name: 'Sistemas', email: 'sistemas@ejemplo.org', role: 'superadmin' },
      { name: 'Una', email: 'una@ejemplo.org', role: 'admin' },
      { name: 'Otra', email: 'otra@ejemplo.org', role: 'admin' },
    ]);

    const usuarios = await db.select().from(schema.users);
    const porRol = usuarios.reduce<Record<string, number>>((acc, u) => {
      acc[u.role] = (acc[u.role] ?? 0) + 1;
      return acc;
    }, {});
    expect(porRol).toEqual({ superadmin: 1, admin: 2 });
  });

  it('respeta la contraseña elegida y la marca como tal', async () => {
    const db = await conBase();
    const [credencial] = await seedProduccion(db, [
      {
        name: 'Sistemas',
        email: 'sistemas@ejemplo.org',
        role: 'superadmin',
        password: 'UnaClaveLargaDeVerdad2026$',
      },
    ]);

    expect(credencial!.password).toBe('UnaClaveLargaDeVerdad2026$');
    expect(credencial!.elegida).toBe(true);
  });

  it('la contraseña elegida sirve para entrar', async () => {
    const { verifyPassword } = await import('../src/lib/password');
    const db = await conBase();
    await seedProduccion(db, [
      {
        name: 'Sistemas',
        email: 'sistemas@ejemplo.org',
        role: 'superadmin',
        password: 'UnaClaveLargaDeVerdad2026$',
      },
    ]);

    const [usuario] = await db.select().from(schema.users);
    expect(
      await verifyPassword('UnaClaveLargaDeVerdad2026$', usuario!.passwordHash),
    ).toBe(true);
  });

  it('mezcla elegidas y generadas sin confundirlas', async () => {
    const db = await conBase();
    const credenciales = await seedProduccion(db, [
      { name: 'Con clave', email: 'con@ejemplo.org', role: 'superadmin', password: 'ClaveElegida2026$' },
      { name: 'Sin clave', email: 'sin@ejemplo.org', role: 'admin' },
    ]);

    expect(credenciales.find((c) => c.email === 'con@ejemplo.org')!.elegida).toBe(true);
    const generada = credenciales.find((c) => c.email === 'sin@ejemplo.org')!;
    expect(generada.elegida).toBe(false);
    expect(generada.password.length).toBeGreaterThanOrEqual(20);
  });
});

describe('aviso de contraseñas compartidas', () => {
  const cred = (email: string, password: string): CredencialCreada => ({
    email,
    role: 'admin',
    password,
    elegida: true,
  });

  it('agrupa las cuentas que comparten contraseña', () => {
    // Una clave compartida borra la diferencia entre esas cuentas: una
    // filtración las compromete todas a la vez, y ninguna puede sostener
    // después que no fue ella.
    const grupos = contrasenasCompartidas([
      cred('una@ejemplo.org', 'LaMismaClave2026$'),
      cred('otra@ejemplo.org', 'LaMismaClave2026$'),
      cred('tercera@ejemplo.org', 'LaMismaClave2026$'),
      cred('sola@ejemplo.org', 'UnaClavePropia2026$'),
    ]);

    expect(grupos).toHaveLength(1);
    expect(grupos[0]).toHaveLength(3);
    expect(grupos[0]).not.toContain('sola@ejemplo.org');
  });

  it('no avisa cuando cada cuenta tiene la suya', () => {
    expect(
      contrasenasCompartidas([
        cred('una@ejemplo.org', 'ClavePropiaUna2026$'),
        cred('otra@ejemplo.org', 'ClavePropiaOtra2026$'),
      ]),
    ).toHaveLength(0);
  });
});
