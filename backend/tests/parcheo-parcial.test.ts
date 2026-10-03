import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { z } from 'zod';

import { parcial } from '../src/lib/parcial';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Un PATCH cambia lo que se manda y NADA más.
 *
 * En zod 4 `.partial()` sigue aplicando los `.default()` de cada campo, así
 * que todo lo que el cliente no mandaba volvía como `''`, `0`, `false` o `[]`
 * y se escribía encima de lo guardado. Pasaba en diez endpoints. Los casos
 * de abajo son los que se veían desde la aplicación:
 *
 * - guardar la sección «Certificado» del constructor dejaba el curso sin
 *   subtítulo ni descripciones, en nivel básico y con 0 horas;
 * - editar el rol de una persona le borraba teléfono, cédula, carrera y el
 *   texto de su universidad, que es con lo que el asesor la encuentra;
 * - editar un proyecto le quitaba los ODS y lo devolvía a «ideación».
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let adminToken = '';
let lxdToken = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, { ...init, headers: { ...(init.headers ?? {}), ...auth(token) } });
const patch = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PATCH' });

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('parcial()', () => {
  it('quita los valores por defecto y deja todo opcional', () => {
    const esquema = z.object({
      nombre: z.string().min(1),
      notas: z.string().default(''),
      etiquetas: z.array(z.string()).default([]),
      activo: z.boolean().default(true),
    });
    expect(parcial(esquema).parse({ nombre: 'x' })).toEqual({ nombre: 'x' });
    // Las reglas del campo siguen valiendo.
    expect(() => parcial(esquema).parse({ nombre: '' })).toThrow();
  });
});

describe('cada PATCH deja intacto lo que no recibe', () => {
  it('curso: guardar solo el certificado no borra la ficha', async () => {
    const id = seedId('crs_ia_1');
    const [antes] = await sql`select * from courses where id = ${id}`;

    const res = await patch(`/courses/${id}`, lxdToken, {
      generatesCertificate: true,
      certifiedHours: 7,
    });
    expect(res.status).toBe(200);

    const [despues] = await sql`select * from courses where id = ${id}`;
    expect(despues!.certified_hours).toBe(7);
    for (const col of [
      'subtitle',
      'description',
      'full_description',
      'level',
      'estimated_hours',
      'language',
      'is_open_learning',
      'max_students',
      'visible',
    ]) {
      expect(despues![col], col).toEqual(antes![col]);
    }
  });

  it('lección: cambiar el título no la convierte en video', async () => {
    const id = seedId('lia4'); // quiz
    const res = await patch(`/lessons/${id}`, lxdToken, { title: 'Quiz renombrado' });
    expect(res.status).toBe(200);
    const [fila] = await sql`select title, type from lessons where id = ${id}`;
    expect(fila).toEqual({ title: 'Quiz renombrado', type: 'quiz' });
  });

  it('persona: cambiar el nombre no borra teléfono, cédula, carrera ni universidad', async () => {
    const id = seedId('est1');
    const [antes] = await sql`
      select phone, cedula, career, university, university_id from users where id = ${id}`;

    const res = await patch(`/users/${id}`, adminToken, { name: 'Sara N.' });
    expect(res.status).toBe(200);

    const [despues] = await sql`
      select phone, cedula, career, university, university_id from users where id = ${id}`;
    expect(despues).toEqual(antes);
    expect(despues!.phone).not.toBe('');
  });

  it('proyecto: cambiar el nombre no le quita los ODS ni la etapa', async () => {
    const id = seedId('prj1');
    const res = await patch(`/projects/${id}`, adminToken, { name: 'AquaVida 2' });
    expect(res.status).toBe(200);
    const proyecto = (await res.json()) as { stage: string; expoEnabled: boolean; ods: string[] };
    expect(proyecto.stage).toBe('pilot');
    expect(proyecto.expoEnabled).toBe(true);
    expect([...proyecto.ods].sort()).toEqual(['ods_3', 'ods_6']);
  });

  it('equipo: cambiar el nombre no borra la universidad', async () => {
    const id = seedId('grp1');
    const res = await patch(`/groups/${id}`, adminToken, { name: 'Equipo AquaVida 2' });
    expect(res.status).toBe(200);
    const [fila] = await sql`select university from groups where id = ${id}`;
    expect(fila!.university).toBe('Universidad de los Andes');
  });

  it('laboratorio: cambiar el nombre no borra descripción ni objetivos', async () => {
    const id = seedId('lab_ia');
    const [antes] = await sql`select description, objectives from laboratories where id = ${id}`;
    const res = await patch(`/laboratories/${id}`, adminToken, { name: 'Lab IA' });
    expect(res.status).toBe(200);
    const [despues] = await sql`select description, objectives from laboratories where id = ${id}`;
    expect(despues).toEqual(antes);
    expect(despues!.description).not.toBe('');
  });

  it('objetivo: cambiar el texto no lo pasa a «emprendimiento»', async () => {
    const id = seedId('lab_ia_fase1_obj2'); // business
    const res = await patch(`/objectives/${id}`, adminToken, { text: 'Fundamentos de IA' });
    expect(res.status).toBe(200);
    const [fila] = await sql`select category from objectives where id = ${id}`;
    expect(fila!.category).toBe('business');
  });

  it('evidencia: cambiar el título no borra la descripción', async () => {
    const id = seedId('ev1');
    const res = await patch(`/evidences/${id}`, adminToken, { title: 'Otra historia' });
    expect(res.status).toBe(200);
    const [fila] = await sql`select description from evidences where id = ${id}`;
    expect(fila!.description).toContain('AquaVida');
  });

  it('evento: cambiar el título no borra descripción, enlace ni invitados', async () => {
    const creado = await req('/calendar-events', adminToken, json({
      title: 'Sesión de Ruta',
      description: 'Revisión de avances.',
      startsAt: '2026-11-02T15:00:00.000Z',
      type: 'ruta_impacto',
      meetLink: 'https://meet.google.com/abc-defg-hij',
      guests: 'mentor.ia@enactus.co',
      courseId: null,
      laboratoryId: null,
    }));
    expect(creado.status).toBe(201);
    const { id } = (await creado.json()) as { id: string };

    const res = await patch(`/calendar-events/${id}`, adminToken, { title: 'Sesión movida' });
    expect(res.status).toBe(200);
    const [fila] = await sql`
      select description, meet_link, guests from calendar_events where id = ${id}`;
    expect(fila).toEqual({
      description: 'Revisión de avances.',
      meet_link: 'https://meet.google.com/abc-defg-hij',
      guests: 'mentor.ia@enactus.co',
    });
  });
});
