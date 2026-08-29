import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Seguimiento de un curso.
 *
 * Lo que la tabla muestra por estudiante sale de UNA consulta con SQL crudo, y
 * el SQL crudo no lo revisa TypeScript: un nombre de columna equivocado
 * compila, pasa el lint y revienta en tiempo de ejecución. Estas pruebas son
 * lo único que lo atrapa.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const T: Record<string, string> = {};
const CURSO = seedId('crs_ia_1');

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

type StudentRow = {
  id: string;
  name: string;
  progress: { completedLessons: number; totalLessons: number; ratio: number };
  avgGrade: number | null;
  gradedCount: number;
  pendingCount: number;
  lastActivityAt: string | null;
  note: string;
};

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  const creds: [string, string, string][] = [
    ['admin', 'admin@enactus.co', 'Admin123'],
    ['lxd', 'lxd.ia@enactus.co', 'Lxd123'],
    ['otroLxd', 'lxd.agua@enactus.co', 'Lxd123'],
    ['mentor', 'mentor.ia@enactus.co', 'Mentor123'],
    ['advisor', 'asesor@uniandes.edu.co', 'Asesor123'],
    ['student', 'estudiante1@uniandes.edu.co', 'Est123'],
    ['donor', 'donante@gmail.com', 'Donante123'],
  ];
  for (const [key, email, password] of creds) {
    T[key] = (await login(app, email, password)).accessToken;
  }
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('GET /courses/:id/students', () => {
  it('trae avance, nota, última actividad y comentario en una sola consulta',
    async () => {
      const res = await req(`/courses/${CURSO}/students`, T.lxd!);
      expect(res.status).toBe(200);
      const b = await body<{ students: StudentRow[] }>(res);

      expect(b.students.length).toBeGreaterThan(0);
      const alumna = b.students[0]!;
      expect(alumna.name).toBeTruthy();
      // Las cuatro cosas que la tabla muestra, sin una petición por fila.
      expect(alumna.progress.totalLessons).toBeGreaterThan(0);
      expect(alumna).toHaveProperty('avgGrade');
      expect(alumna).toHaveProperty('lastActivityAt');
      expect(alumna).toHaveProperty('note');
    });

  it('el avance coincide con el que devuelve el endpoint del estudiante',
    async () => {
      // Dos caminos distintos hacia el mismo dato: si discrepan, la tabla del
      // LXD y la pantalla del estudiante dirían cosas diferentes.
      const tabla = await body<{ students: StudentRow[] }>(
        await req(`/courses/${CURSO}/students`, T.lxd!),
      );
      const fila = tabla.students.find((s) => s.id === seedId('est1'));
      expect(fila).toBeDefined();

      const propio = await body<{ completedLessons: number; ratio: number }>(
        await req(`/students/${seedId('est1')}/course-progress/${CURSO}`, T.admin!),
      );
      expect(fila!.progress.completedLessons).toBe(propio.completedLessons);
      expect(fila!.progress.ratio).toBeCloseTo(propio.ratio, 4);
    });

  it('`avgGrade` es null cuando nadie tiene nota, no 0', async () => {
    // "Nadie tiene nota todavía" y "todos sacaron cero" son cosas distintas.
    const b = await body<{ students: StudentRow[] }>(
      await req(`/courses/${CURSO}/students`, T.lxd!),
    );
    const sinNota = b.students.find((s) => s.gradedCount === 0);
    if (sinNota) expect(sinNota.avgGrade).toBeNull();
  });

  it('el mentor del laboratorio también lo ve', async () => {
    const res = await req(`/courses/${CURSO}/students`, T.mentor!);
    expect(res.status).toBe(200);
  });

  it('el asesor de la universidad también', async () => {
    const res = await req(`/courses/${CURSO}/students`, T.advisor!);
    expect(res.status).toBe(200);
  });

  it('OTRO LXD recibe 404, no 403', async () => {
    // Un 403 confirmaría que el curso existe.
    const res = await req(`/courses/${CURSO}/students`, T.otroLxd!);
    expect(res.status).toBe(404);
  });

  it('un estudiante NO ve cómo va el resto de la clase', async () => {
    const res = await req(`/courses/${CURSO}/students`, T.student!);
    expect(res.status).toBe(404);
  });

  it('un donante tampoco', async () => {
    const res = await req(`/courses/${CURSO}/students`, T.donor!);
    expect(res.status).toBe(404);
  });
});

describe('GET /courses/:id/stats', () => {
  it('las cifras cuadran con la lista de estudiantes', async () => {
    const stats = await body<{
      enrolled: number;
      completed: number;
      avgProgress: number;
      avgGrade: number | null;
      pending: number;
    }>(await req(`/courses/${CURSO}/stats`, T.lxd!));

    const lista = await body<{ students: StudentRow[] }>(
      await req(`/courses/${CURSO}/students`, T.lxd!),
    );

    expect(stats.enrolled).toBe(lista.students.length);
    expect(stats.completed).toBe(
      lista.students.filter((s) => s.progress.ratio >= 1).length,
    );
    expect(stats.avgProgress).toBeGreaterThanOrEqual(0);
    expect(stats.avgProgress).toBeLessThanOrEqual(1);
  });

  it('mismo alcance que la lista: otro LXD no las ve', async () => {
    expect((await req(`/courses/${CURSO}/stats`, T.otroLxd!)).status).toBe(404);
  });
});

describe('PUT /courses/:id/students/:studentId/note', () => {
  const ruta = `/courses/${CURSO}/students/${seedId('est1')}/note`;

  it('el LXD escribe y reemplaza: una nota por estudiante y curso', async () => {
    const primera = await req(ruta, T.lxd!, {
      ...json({ note: 'Va muy bien con los fundamentos.' }),
      method: 'PUT',
    });
    expect(primera.status).toBe(200);

    const segunda = await req(ruta, T.lxd!, {
      ...json({ note: 'Ya entregó el proyecto final.' }),
      method: 'PUT',
    });
    expect(segunda.status).toBe(200);

    const filas = await sql`
      select note from staff_notes
       where student_id = ${seedId('est1')} and course_id = ${CURSO}
    `;
    // Una sola fila: reemplaza, no acumula.
    expect(filas.length).toBe(1);
    expect(filas[0]!.note).toBe('Ya entregó el proyecto final.');
  });

  it('la nota aparece en la tabla de seguimiento', async () => {
    const b = await body<{ students: StudentRow[] }>(
      await req(`/courses/${CURSO}/students`, T.lxd!),
    );
    const fila = b.students.find((s) => s.id === seedId('est1'));
    expect(fila!.note).toBe('Ya entregó el proyecto final.');
  });

  it('el ESTUDIANTE nunca la ve: no hay endpoint que se la devuelva', async () => {
    // Es un comentario privado del equipo docente. Se comprueba por los dos
    // lados: no puede leer la tabla, y su propio curso no la trae.
    expect((await req(`/courses/${CURSO}/students`, T.student!)).status).toBe(404);

    const suCurso = await req(`/courses/${CURSO}?include=modules,lessons`, T.student!);
    const raw = await suCurso.text();
    expect(raw).not.toContain('Ya entregó el proyecto final');
    expect(raw).not.toContain('staffNote');
  });

  it('el asesor acompaña pero no escribe en el cuaderno del curso', async () => {
    const res = await req(ruta, T.advisor!, {
      ...json({ note: 'Del asesor' }),
      method: 'PUT',
    });
    expect(res.status).toBe(403);
  });

  it('no se puede dejar una nota sobre alguien que no cursa esto', async () => {
    // Si no, quedaría colgando de un par (estudiante, curso) que no existe.
    const res = await req(
      `/courses/${CURSO}/students/${seedId('est3')}/note`,
      T.lxd!,
      { ...json({ note: 'x' }), method: 'PUT' },
    );
    expect(res.status).toBe(404);
  });

  it('otro LXD no escribe en un curso ajeno', async () => {
    const res = await req(ruta, T.otroLxd!, {
      ...json({ note: 'Intruso' }),
      method: 'PUT',
    });
    expect(res.status).toBe(404);
  });
});
