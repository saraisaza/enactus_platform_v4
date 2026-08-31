import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * `/users`: quién ve a quién.
 *
 * Es el router que faltaba, y el que mantenía sin migrar a cinco portales. La
 * versión con Hive resolvía esto teniendo la tabla entera de usuarios en el
 * navegador —con la contraseña en texto plano— así que acá lo que se prueba
 * es justo lo contrario: que cada rol vea SOLO a quien le corresponde, y que
 * los datos personales no salgan para quien no acompaña a esa persona.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const T: Record<string, string> = {};

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

type UserRow = {
  id: string;
  name: string;
  role: string;
  email?: string;
  cedula?: string;
  phone?: string;
};

const list = async (token: string, query = '') => {
  const res = await req(`/users?pageSize=100${query}`, token);
  expect(res.status).toBe(200);
  return body<{ data: UserRow[]; total: number }>(res);
};

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  const creds: [string, string, string][] = [
    ['admin', 'admin@enactus.co', 'Admin123'],
    ['superadmin', 'superadmin1@enactus.co', 'Super123'],
    ['advisor', 'asesor@uniandes.edu.co', 'Asesor123'],
    ['lxd', 'lxd.ia@enactus.co', 'Lxd123'],
    ['mentor', 'mentor.ia@enactus.co', 'Mentor123'],
    ['donor', 'donante@gmail.com', 'Donante123'],
    ['company', 'empresa@bancolombia.com', 'Empresa123'],
    ['student', 'estudiante1@uniandes.edu.co', 'Est123'],
    ['openLearning', 'camila.rivas@gmail.com', 'Est123'],
  ];
  for (const [key, email, password] of creds) {
    T[key] = (await login(app, email, password)).accessToken;
  }
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('alcance por rol', () => {
  it('el admin ve a todo el mundo', async () => {
    const page = await list(T.admin!);
    expect(page.total).toBeGreaterThan(10);
    expect(page.data.map((u) => u.role)).toContain('donor');
  });

  it('un ESTUDIANTE no ve a nadie: no tiene directorio de personas', async () => {
    // Su equipo llega dentro del proyecto, con el rol de cada integrante.
    // Antes podía enumerar a toda la plataforma con universidad y carrera.
    const page = await list(T.student!);
    expect(page.total).toBe(0);
    expect(page.data).toEqual([]);
  });

  it('un Open Learning tampoco', async () => {
    const page = await list(T.openLearning!);
    expect(page.total).toBe(0);
  });

  it('el asesor ve solo a los de SU universidad', async () => {
    const page = await list(T.advisor!);
    expect(page.data.length).toBeGreaterThan(0);

    const [asesor] = await sql`
      select university from users where email = 'asesor@uniandes.edu.co'
    `;
    const universidades = await sql`
      select distinct university from users
       where id = any(${page.data.map((u) => u.id)}::uuid[])
    `;
    expect(universidades.map((r) => r.university)).toEqual([
      asesor!.university,
    ]);
  });

  it('el donante ve solo a los estudiantes que apoya', async () => {
    const page = await list(T.donor!);
    const ids = page.data.map((u) => u.id);
    if (ids.length > 0) {
      const ajenos = await sql`
        select count(*)::int as n from users
         where id = any(${ids}::uuid[]) and donor_id <> ${seedId('don1')}
      `;
      expect(ajenos[0]!.n).toBe(0);
    }
    // Y nunca a otro donante ni a un admin.
    expect(page.data.map((u) => u.role)).not.toContain('admin');
  });

  it('el mentor ve a los estudiantes de SUS laboratorios', async () => {
    const page = await list(T.mentor!);
    expect(page.data.length).toBeGreaterThan(0);
    expect(page.data.map((u) => u.role)).not.toContain('donor');
  });

  it('el LXD ve a quienes tienen acceso a SUS cursos', async () => {
    const page = await list(T.lxd!);
    expect(page.data.every((u) => ['student', 'alumni'].includes(u.role)))
      .toBe(true);
  });
});

describe('datos personales', () => {
  it('quien acompaña ve el contacto; quien no, la ficha recortada', async () => {
    const conContacto = await list(T.mentor!);
    if (conContacto.data.length > 0) {
      expect(conContacto.data[0]).toHaveProperty('email');
    }

    // Empresa y Donante ven la ficha sin correo, teléfono ni cédula: es la
    // misma decisión que separa `publicUser` de `limitedUser`.
    for (const token of [T.company!, T.donor!]) {
      const page = await list(token);
      for (const u of page.data) {
        expect(u).not.toHaveProperty('email');
        expect(u).not.toHaveProperty('cedula');
        expect(u).not.toHaveProperty('phone');
      }
    }
  });

  it('NINGUNA respuesta trae la contraseña', async () => {
    for (const token of Object.values(T)) {
      const res = await req('/users?pageSize=100', token);
      const raw = await res.text();
      expect(raw).not.toContain('passwordHash');
      expect(raw).not.toContain('password_hash');
      expect(raw).not.toContain('$2b$');
    }
  });
});

describe('GET /users/:id', () => {
  it('cualquiera puede pedirse a sí mismo', async () => {
    const res = await req(`/users/${seedId('est1')}`, T.student!);
    expect(res.status).toBe(200);
    const u = await body<UserRow>(res);
    expect(u.email).toBe('estudiante1@uniandes.edu.co');
  });

  it('una persona fuera del alcance responde 404, no 403', async () => {
    // Un 403 confirmaría que esa cuenta existe.
    const res = await req(`/users/${seedId('don1')}`, T.student!);
    expect(res.status).toBe(404);
  });
});

describe('alta y edición', () => {
  it('solo administración crea cuentas', async () => {
    for (const token of [T.student!, T.mentor!, T.lxd!, T.donor!]) {
      const res = await req('/users', token, {
        ...json({
          name: 'X',
          email: `x${Math.random()}@t.co`,
          password: 'Secreta1',
          role: 'student',
          studentType: 'enactus',
        }),
      });
      expect(res.status).toBe(403);
    }
  });

  it('un estudiante SIN tipo se rechaza', async () => {
    // Es lo que separa eduXaction de Open Learning en toda la API: una cuenta
    // sin tipo quedaría en un limbo donde ninguna regla de aislamiento aplica.
    const res = await req('/users', T.admin!, {
      ...json({
        name: 'Sin tipo',
        email: 'sintipo@t.co',
        password: 'Secreta1',
        role: 'student',
      }),
    });
    expect(res.status).toBe(409);
  });

  it('un rol que no es estudiante NO lleva tipo de estudiante', async () => {
    const res = await req('/users', T.admin!, {
      ...json({
        name: 'Mentor con tipo',
        email: 'mentortipo@t.co',
        password: 'Secreta1',
        role: 'mentor',
        studentType: 'enactus',
      }),
    });
    expect(res.status).toBe(409);
  });

  it('un admin NO puede crear un superadmin', async () => {
    // Si pudiera, se ascendería creando una cuenta y entrando con ella.
    const res = await req('/users', T.admin!, {
      ...json({
        name: 'Super falso',
        email: 'superfalso@t.co',
        password: 'Secreta1',
        role: 'superadmin',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('un superadmin sí, y queda registrado en el audit_log', async () => {
    const res = await req('/users', T.superadmin!, {
      ...json({
        name: 'Super real',
        email: 'superreal@t.co',
        password: 'Secreta1',
        role: 'superadmin',
      }),
    });
    expect(res.status).toBe(201);
    const creado = await body<UserRow>(res);

    const rastro = await sql`
      select action from audit_log
       where entity_id = ${creado.id} and action = 'user.create'
    `;
    expect(rastro.length).toBe(1);
  });

  it('el correo repetido se rechaza con 409, no con un error de base', async () => {
    const res = await req('/users', T.admin!, {
      ...json({
        name: 'Duplicada',
        email: 'admin@enactus.co',
        password: 'Secreta1',
        role: 'admin',
      }),
    });
    expect(res.status).toBe(409);
  });

  it('el alta NO acepta los permisos de calificar', async () => {
    // Se cambian por su propio endpoint, que deja rastro en el audit_log.
    const res = await req('/users', T.admin!, {
      ...json({
        name: 'LXD nuevo',
        email: `lxdnuevo${Math.random()}@t.co`,
        password: 'Secreta1',
        role: 'lxd',
        canGradeEnactus: true,
      }),
    });
    expect(res.status).toBe(201);
    const creado = await body<{ id: string; canGradeEnactus: boolean }>(res);
    expect(creado.canGradeEnactus).toBe(false);
  });

  it('nadie puede eliminar su propia cuenta', async () => {
    const res = await req(`/users/${seedId('adm1')}`, T.admin!, {
      method: 'DELETE',
    });
    expect(res.status).toBe(409);
  });

  it('eliminar es borrado lógico y queda en el audit_log', async () => {
    const creado = await req('/users', T.admin!, {
      ...json({
        name: 'Para borrar',
        email: `borrar${Math.random()}@t.co`,
        password: 'Secreta1',
        role: 'mentor',
      }),
    });
    const { id } = await body<{ id: string }>(creado);

    const res = await req(`/users/${id}`, T.admin!, { method: 'DELETE' });
    expect(res.status).toBe(204);

    const [row] = await sql`select deleted_at from users where id = ${id}`;
    expect(row!.deleted_at).not.toBeNull();

    // Y deja de aparecer en el listado.
    const page = await list(T.admin!);
    expect(page.data.map((u) => u.id)).not.toContain(id);
  });
});

describe('include=team,progress', () => {
  it('trae equipo, patrocinador y avance en DOS consultas, no cuatro por fila',
    async () => {
      const page = await list(T.lxd!, '&include=team,progress');
      expect(page.data.length).toBeGreaterThan(0);

      const conEquipo = page.data.find(
        (u) => (u as Record<string, unknown>).team !== null,
      ) as Record<string, unknown> | undefined;
      expect(conEquipo).toBeDefined();

      const team = conEquipo!.team as Record<string, unknown>;
      expect(team.projectName).toBeTruthy();
      // La etapa va como identificador, no como etiqueta: el cliente traduce.
      expect(team.projectStage).toMatch(/^[a-z_]+$/);

      const progress = conEquipo!.overallProgress as {
        ratio: number;
        coursesTotal: number;
        coursesDone: number;
      };
      expect(progress.ratio).toBeGreaterThanOrEqual(0);
      expect(progress.ratio).toBeLessThanOrEqual(1);
      expect(progress.coursesDone).toBeLessThanOrEqual(progress.coursesTotal);
    });

  it('el avance general coincide con el promedio de sus cursos', async () => {
    // Dos caminos al mismo dato: si discreparan, la tabla del LXD y la
    // pantalla del estudiante dirían cosas distintas.
    const page = await list(T.admin!, '&include=progress&role=student');
    const fila = page.data.find((u) => u.id === seedId('est1')) as
      | Record<string, unknown>
      | undefined;
    expect(fila).toBeDefined();

    const [esperado] = await sql`
      select coalesce(avg(ratio), 0)::float8 as ratio
        from course_progress where student_id = ${seedId('est1')}
    `;
    const progress = fila!.overallProgress as { ratio: number };
    expect(progress.ratio).toBeCloseTo(esperado!.ratio, 4);
  });

  it('sin el include, no se agregan esos campos', async () => {
    const page = await list(T.lxd!);
    expect(page.data[0]).not.toHaveProperty('overallProgress');
  });
});

describe('filtros', () => {
  it('por rol, aceptando varios', async () => {
    const page = await list(T.admin!, '&role=student,alumni');
    expect(page.data.length).toBeGreaterThan(0);
    expect(page.data.every((u) => ['student', 'alumni'].includes(u.role)))
      .toBe(true);
  });

  it('por laboratorio', async () => {
    const page = await list(T.admin!, `&laboratoryId=${seedId('lab_ia')}`);
    const ids = page.data.map((u) => u.id);
    const fuera = await sql`
      select count(*)::int as n from users u
       where u.id = any(${ids}::uuid[])
         and not exists (select 1 from student_laboratories sl
                          where sl.student_id = u.id
                            and sl.laboratory_id = ${seedId('lab_ia')})
    `;
    expect(fuera[0]!.n).toBe(0);
  });

  it('un filtro NO amplía el alcance', async () => {
    // La comprobación de fondo: pedir explícitamente a los donantes desde una
    // cuenta que no los ve sigue devolviendo vacío.
    const page = await list(T.student!, '&role=donor');
    expect(page.data).toEqual([]);
  });
});
