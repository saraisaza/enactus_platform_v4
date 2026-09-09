import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { auth, json, login, makeTestApp } from './helpers/app';
import { resetTestDatabase, seedTestDatabase } from './helpers/db';

/**
 * Segunda red para las reglas que colgaban de un solo hilo.
 *
 * La auditoría de mutaciones (`AUDITORIA_PRUEBAS.md`) clasificó cinco reglas
 * como **débiles**: al romperlas se ponía roja **una sola** prueba. La regla
 * era correcta y estaba cubierta, pero por un único caso — si alguien borra o
 * debilita esa prueba, la regla se queda sin red y nada avisa.
 *
 * Las cinco caen en permisos o en ingreso, que es donde salen más caras. Estas
 * pruebas las cubren **por otro camino**, no repitiendo la que ya existe:
 * copiar la aserción daría dos pruebas que fallan por lo mismo, y eso no es
 * una segunda red — es la misma red dibujada dos veces.
 *
 * | Regla | Lo que ya existía | Por dónde entra esta |
 * |---|---|---|
 * | M4/M5 `can_grade` | el middleware sobre una ruta **sintética** | el endpoint **real**, y que no se escriba nota |
 * | M9 no cambiarse el rol | la respuesta de `PATCH /auth/me` | la **fila en la base** y la autoridad efectiva |
 * | M10 empresa solo crea lxd/mentor | el código de estado | que **no quede fila creada** |
 */

const { app, sql } = makeTestApp();

beforeAll(async () => {
  await resetTestDatabase();
  await seedTestDatabase();
}, 120_000);

afterAll(async () => {
  await sql.end();
});

const CLAVES = {
  lxd: ['lxd.ia@enactus.co', 'Lxd123'],
  empresa: ['empresa@bancolombia.com', 'Empresa123'],
  estudiante: ['estudiante1@uniandes.edu.co', 'Est123'],
} as const;

describe('M4/M5 · calificar sin permiso, contra el endpoint de verdad', () => {
  /**
   * La prueba que ya existía monta una ruta de mentira (`test.post('/calificar',
   * …)`) para ejercitar `requireCanGrade` aislado. Eso demuestra que el
   * middleware funciona — no que esté **enganchado** a
   * `POST /submissions/:id/grade`. Si alguien lo quitara de esa ruta, aquella
   * prueba seguiría verde.
   */
  it('un LXD sin can_grade recibe 403 en POST /submissions/:id/grade', async () => {
    const [correo, clave] = CLAVES.lxd;
    const lxd = await login(app, correo, clave);

    const [entrega] = await sql<{ id: string; grade: number | null }[]>`
      select id, grade from submissions order by created_at limit 1`;
    expect(entrega, 'el sembrado tiene que traer al menos una entrega').toBeDefined();

    await sql`update users set can_grade_enactus = false,
                               can_grade_open_learning = false
               where email = ${correo}`;

    try {
      const res = await app.request(`/submissions/${entrega!.id}/grade`, {
        ...json({ grade: 5, feedback: 'no debería entrar' }),
        headers: {
          ...(json({}).headers as Record<string, string>),
          ...auth(lxd.accessToken),
        },
      });
      expect(res.status).toBe(403);

      // Lo que de verdad importa: que NO haya quedado escrita la nota. Un 403
      // con la nota escrita seria peor que un 200 honesto.
      const [despues] = await sql<{ grade: number | null }[]>`
        select grade from submissions where id = ${entrega!.id}`;
      expect(despues!.grade).toBe(entrega!.grade);
    } finally {
      await sql`update users set can_grade_enactus = true,
                                 can_grade_open_learning = true
                 where email = ${correo}`;
    }
  });
});

describe('M4/M5 · emitir certificado de Ruta sin permiso', () => {
  /**
   * El barrido de guardias encontró que `requireCanGrade` se podía quitar de
   * `POST /certificates/ruta` sin que ninguna prueba se pusiera roja — el
   * mismo hueco que en `/submissions/:id/grade`, en el otro endpoint que
   * protege.
   *
   * No lo cubre el barrido general de `guardias-en-rutas-reales.test.ts`
   * porque el riesgo aquí no es un estudiante —a ese lo frena igual— sino un
   * **LXD al que le quitaron el permiso**. Eso hay que probarlo con un LXD.
   */
  it('un LXD sin can_grade no puede emitir un certificado de Ruta', async () => {
    const [correo, clave] = CLAVES.lxd;
    const lxd = await login(app, correo, clave);

    const antes = await sql<{ n: number }[]>`select count(*)::int as n from certificates`;

    await sql`update users set can_grade_enactus = false,
                               can_grade_open_learning = false
               where email = ${correo}`;
    try {
      const res = await app.request('/certificates/ruta', {
        ...json({ studentId: '00000000-0000-4000-8000-000000000000' }),
        headers: {
          ...(json({}).headers as Record<string, string>),
          ...auth(lxd.accessToken),
        },
      });
      expect(res.status).toBe(403);

      // Y no se emitió nada. Un certificado es un documento que sale de la
      // plataforma: si se emite mal, el 403 llega tarde.
      const despues = await sql<{ n: number }[]>`select count(*)::int as n from certificates`;
      expect(despues[0]!.n).toBe(antes[0]!.n);
    } finally {
      await sql`update users set can_grade_enactus = true,
                                 can_grade_open_learning = true
                 where email = ${correo}`;
    }
  });
});

describe('M9 · nadie se sube el rol a sí mismo', () => {
  /**
   * `profileSchema` no declara `role`, y zod **descarta** las claves que no
   * conoce en vez de rechazarlas. Es decir: la regla se sostiene por la FORMA
   * del esquema, no por una comprobación explícita. Basta con que alguien
   * agregue `.passthrough()` —o incluya `role` "para que el admin pueda
   * editarlo"— para que la escalada quede abierta sin que nada chille.
   *
   * Por eso esta prueba no mira la respuesta: mira la fila en la base y la
   * autoridad que el token consigue de verdad.
   */
  it('mandar role en PATCH /auth/me no cambia la fila ni da poderes', async () => {
    const [correo, clave] = CLAVES.estudiante;
    const sesion = await login(app, correo, clave);

    const [antes] = await sql<{ role: string }[]>`
      select role from users where email = ${correo}`;
    expect(antes!.role).toBe('student');

    const res = await app.request('/auth/me', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(sesion.accessToken) },
      body: JSON.stringify({ name: 'Nombre Nuevo', role: 'superadmin' }),
    });
    expect(res.status).toBe(200);

    // 1. La fila no cambió de rol —aunque el nombre sí, que es lo permitido.
    const [despues] = await sql<{ role: string; name: string }[]>`
      select role, name from users where email = ${correo}`;
    expect(despues!.role).toBe('student');
    expect(despues!.name).toBe('Nombre Nuevo');

    // 2. Y el token no consiguió autoridad. Se comprueba aparte porque los
    //    permisos se leen del registro vivo: un cambio que no toca la fila
    //    tampoco puede tocar esto.
    //
    //    Se usa `POST /users`, que sí exige rol de administración. `GET /users`
    //    NO sirve para esto: a un estudiante le responde 200 con lista vacía
    //    —el alcance le devuelve `null`— así que un 200 ahí no significa que
    //    haya ganado nada. Es buen diseño y una trampa para quien escriba la
    //    prueba.
    const crear = await app.request('/users', {
      ...json({ name: 'X', email: 'x@ejemplo.test', password: 'unaClaveLarga1', role: 'admin' }),
      headers: {
        ...(json({}).headers as Record<string, string>),
        ...auth(sesion.accessToken),
      },
    });
    expect(crear.status).toBe(403);

    // Y sigue sin ver a nadie, que es lo que le toca a un estudiante.
    const listar = await app.request('/users', { headers: auth(sesion.accessToken) });
    expect(listar.status).toBe(200);
    const cuerpo = (await listar.json()) as { items?: unknown[] } | unknown[];
    const lista = Array.isArray(cuerpo) ? cuerpo : (cuerpo.items ?? []);
    expect(lista.length).toBe(0);
  });
});

describe('M10 · una empresa solo crea lxd y mentor', () => {
  /**
   * La prueba que existía comprobaba el código de estado. Esta comprueba que
   * **no quedó fila**: un 403 que igual crea la cuenta es peor que un 200,
   * porque nadie va a ir a mirar.
   */
  it('los roles prohibidos no dejan ninguna cuenta creada', async () => {
    const [correo, clave] = CLAVES.empresa;
    const empresa = await login(app, correo, clave);

    for (const rol of ['admin', 'superadmin', 'student', 'company', 'advisor', 'donor']) {
      const email = `intento-${rol}@ejemplo.test`;
      // `studentType` va SOLO en los roles de estudiante, y es obligatorio ahí.
      //
      // No es un detalle: `assertStudentType` corre ANTES del guardia de
      // empresa y responde 409 si falta. Sin esto, el caso `student` daba 409
      // y la prueba lo daba por bueno **sin haber llegado nunca al guardia que
      // dice probar**. Es el mismo error que esta suite existe para encontrar,
      // cometido dentro de la propia prueba.
      const cuerpo: Record<string, unknown> = {
        name: `Intento ${rol}`,
        email,
        password: 'unaClaveLarga1',
        role: rol,
      };
      if (rol === 'student' || rol === 'alumni') cuerpo.studentType = 'enactus';

      const res = await app.request('/users', {
        ...json(cuerpo),
        headers: {
          ...(json({}).headers as Record<string, string>),
          ...auth(empresa.accessToken),
        },
      });
      // 403 para TODOS. El guardia de empresa es `forbidden()`, y el de
      // «solo un superadmin crea administración» también.
      //
      // El 409 que aparecía antes no era ninguno de los dos: era
      // `assertStudentType` rechazando un `student` sin tipo, mucho antes de
      // llegar a la autorización. Dos reglas distintas que se veían iguales
      // desde fuera.
      expect(res.status, `crear ${rol} desde una empresa`).toBe(403);

      const filas = await sql<{ id: string }[]>`
        select id from users where email = ${email}`;
      expect(filas.length, `no debe quedar cuenta ${rol}`).toBe(0);
    }
  });

  it('los dos roles permitidos sí se crean, y atados a la empresa', async () => {
    const [correo, clave] = CLAVES.empresa;
    const empresa = await login(app, correo, clave);

    for (const rol of ['lxd', 'mentor']) {
      const email = `permitido-${rol}@ejemplo.test`;
      const res = await app.request('/users', {
        ...json({ name: `Permitido ${rol}`, email, password: 'unaClaveLarga1', role: rol }),
        headers: {
          ...(json({}).headers as Record<string, string>),
          ...auth(empresa.accessToken),
        },
      });
      expect(res.status, `crear ${rol} desde una empresa`).toBeLessThan(300);

      const [fila] = await sql<{ role: string; company_id: string | null }[]>`
        select role, company_id from users where email = ${email}`;
      expect(fila!.role).toBe(rol);
      // La cuenta queda atada a la empresa que la creó, no suelta.
      expect(fila!.company_id).not.toBeNull();
    }
  });
});
