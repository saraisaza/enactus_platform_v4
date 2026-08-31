import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Métricas de impacto, BuscaTalento y avisos.
 *
 * Las tres cosas que le faltaban al servidor para que ningún portal siguiera
 * bloqueado. Comparten un riesgo: son las lecturas que **más ensanchan** lo
 * que alguien ve —un panel con toda la red, un directorio con todos los
 * estudiantes, un aviso que llega a cualquiera— así que se prueban sobre todo
 * por el lado de quién NO debería.
 *
 * Las métricas además se comprueban contra un cálculo independiente en SQL, no
 * contra el número que devuelven: si la consulta del endpoint estuviera mal,
 * compararla consigo misma no diría nada.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let adminToken = '';
let donorToken = '';
let companyToken = '';
let lxdToken = '';
let mentorToken = '';
let est1Token = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  donorToken = (await login(app, 'donante@gmail.com', 'Donante123')).accessToken;
  companyToken = (await login(app, 'empresa@bancolombia.com', 'Empresa123'))
    .accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  mentorToken = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;
  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------
// Métricas de impacto
// ---------------------------------------------------------------------------

type Metrics = {
  counts: Record<string, number | undefined>;
  hoursByCompetency: { code: string; name: string; hours: number }[];
  odsCompletionRate: {
    code: string;
    number: number;
    rate: number;
    completed: number;
    total: number;
  }[];
  sponsoredHoursByCompany: {
    companyId: string;
    companyName: string;
    hours: number;
  }[];
};

describe('GET /admin/metrics', () => {
  it('devuelve las tres métricas juntas', async () => {
    const res = await req('/admin/metrics', adminToken);
    expect(res.status).toBe(200);
    const m = await body<Metrics>(res);

    expect(Array.isArray(m.hoursByCompetency)).toBe(true);
    expect(Array.isArray(m.odsCompletionRate)).toBe(true);
    expect(Array.isArray(m.sponsoredHoursByCompany)).toBe(true);
  });

  it('los conteos coinciden con la base, sin techo de paginación', async () => {
    // Es la razón por la que están en el servidor: contar la lista del cliente
    // dejaría de crecer al llegar a los 100 de una página, y el panel
    // mostraría un número que parece bien y está mal.
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));

    const [esperado] = await sql<
      { cursos: number; laboratorios: number; universidades: number }[]
    >`
      select (select count(*)::int from courses where deleted_at is null) as cursos,
             (select count(*)::int from laboratories where deleted_at is null) as laboratorios,
             (select count(distinct university)::int from users
               where university <> '' and deleted_at is null) as universidades
    `;
    expect(m.counts.courses).toBe(esperado!.cursos);
    expect(m.counts.laboratories).toBe(esperado!.laboratorios);
    expect(m.counts.universities).toBe(esperado!.universidades);
  });

  it('los conteos excluyen lo borrado lógicamente', async () => {
    const antes = await body<Metrics>(await req('/admin/metrics', adminToken));
    const [curso] = await sql<{ id: string }[]>`
      select id from courses where deleted_at is null limit 1
    `;
    await sql`update courses set deleted_at = now() where id = ${curso!.id}`;

    const despues = await body<Metrics>(await req('/admin/metrics', adminToken));
    expect(despues.counts.courses).toBe(antes.counts.courses! - 1);

    await sql`update courses set deleted_at = null where id = ${curso!.id}`;
  });

  it('las horas por competencia coinciden con el cálculo directo', async () => {
    // Comprobación independiente: se recalcula acá en SQL en vez de comparar
    // la respuesta consigo misma.
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));
    if (m.hoursByCompetency.length === 0) return;

    const primera = m.hoursByCompetency[0]!;
    const [esperado] = await sql<{ hours: number }[]>`
      select round(sum(
               (case when c.certified_hours > 0
                     then c.certified_hours else c.estimated_hours end) * cp.ratio
             ), 1)::float8 as hours
        from course_progress cp
        join courses c on c.id = cp.course_id and c.deleted_at is null
        join course_competencies cc on cc.course_id = c.id
       where cc.competency_code = ${primera.code}
    `;
    expect(primera.hours).toBeCloseTo(esperado!.hours, 1);
  });

  it('vienen ordenadas de mayor a menor', async () => {
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));
    const horas = m.hoursByCompetency.map((h) => h.hours);
    expect([...horas].sort((a, b) => b - a)).toEqual(horas);
  });

  it('las horas se PONDERAN por el avance, no se cuentan enteras', async () => {
    // Un curso de 10 horas que alguien lleva al 40% aporta 4, no 10.
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));
    if (m.hoursByCompetency.length === 0) return;

    const [sinPonderar] = await sql<{ hours: number }[]>`
      select sum(case when c.certified_hours > 0
                      then c.certified_hours else c.estimated_hours end)::float8 as hours
        from course_progress cp
        join courses c on c.id = cp.course_id and c.deleted_at is null
        join course_competencies cc on cc.course_id = c.id
       where cc.competency_code = ${m.hoursByCompetency[0]!.code}
    `;
    // Con avance parcial en el seed, ponderar tiene que dar MENOS.
    expect(m.hoursByCompetency[0]!.hours).toBeLessThan(sinPonderar!.hours);
  });

  it('la cobertura de ODS trae los crudos además de la tasa', async () => {
    // Un 100% sobre dos personas y otro sobre doscientas no son la misma
    // noticia, y la barra sola no lo distingue.
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));
    for (const ods of m.odsCompletionRate) {
      expect(ods.total).toBeGreaterThan(0);
      expect(ods.completed).toBeLessThanOrEqual(ods.total);
      expect(ods.rate).toBeCloseTo(ods.completed / ods.total, 3);
    }
  });

  it('las horas patrocinadas cuentan el patrocinio del laboratorio', async () => {
    // Una empresa patrocina de dos formas: el curso directo o su laboratorio.
    // Si solo contara el directo, un laboratorio patrocinado no sumaría nada.
    const m = await body<Metrics>(await req('/admin/metrics', adminToken));
    const [lab] = await sql<{ n: string }[]>`
      select count(*) as n from laboratories
       where sponsor_company_id is not null and deleted_at is null
    `;
    if (Number(lab!.n) > 0) {
      expect(m.sponsoredHoursByCompany.length).toBeGreaterThan(0);
    }
  });

  it('un LXD no ve el panel de métricas', async () => {
    expect((await req('/admin/metrics', lxdToken)).status).toBe(403);
  });

  it('una empresa tampoco', async () => {
    expect((await req('/admin/metrics', companyToken)).status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// BuscaTalento
// ---------------------------------------------------------------------------

type Talento = {
  id: string;
  name: string;
  university: string;
  team: { projectName: string } | null;
  laboratories: { id: string; name: string }[];
  completedObjectives: { entrepreneurship: number; business: number };
  certificates: number;
  overallProgress: { ratio: number; coursesTotal: number };
};

describe('GET /talent', () => {
  it('un donante ve a TODOS los estudiantes Enactus, no solo a los suyos', async () => {
    // Es el único listado con alcance más ancho que `/users`, y a propósito:
    // la pantalla existe para descubrir a alguien que todavía no conoce.
    const res = await req('/talent?pageSize=100', donorToken);
    expect(res.status).toBe(200);
    const page = await body<{ data: Talento[]; total: number }>(res);

    const [esperado] = await sql<{ n: string }[]>`
      select count(*) as n from users
       where deleted_at is null and student_type = 'enactus'
         and role in ('student', 'alumni')
    `;
    expect(page.total).toBe(Number(esperado!.n));

    // Y son más de los que ve por `/users`.
    const suyos = await body<{ total: number }>(
      await req('/users?pageSize=100', donorToken),
    );
    expect(page.total).toBeGreaterThan(suyos.total);
  });

  it('una empresa también', async () => {
    expect((await req('/talent', companyToken)).status).toBe(200);
  });

  it('NO expone datos de contacto', async () => {
    // El perfil profesional sí; el correo, el teléfono y la cédula no. Para
    // hablarles está `POST /notifications`, que no entrega el correo de nadie.
    const raw = await (await req('/talent?pageSize=100', donorToken)).text();
    expect(raw).not.toContain('@uniandes.edu.co');
    expect(raw).not.toContain('cedula');
    expect(raw).not.toContain('phone');
  });

  it('no aparecen los de Open Learning', async () => {
    const page = await body<{ data: Talento[] }>(
      await req('/talent?pageSize=100', donorToken),
    );
    const ols = await sql<{ id: string }[]>`
      select id from users where student_type = 'open_learning'
    `;
    const ids = page.data.map((t) => t.id);
    for (const ol of ols) expect(ids).not.toContain(ol.id);
  });

  it('trae el perfil completo en UNA consulta', async () => {
    const page = await body<{ data: Talento[] }>(
      await req('/talent?pageSize=100', donorToken),
    );
    const est1 = page.data.find((t) => t.id === seedId('est1'));
    expect(est1).toBeDefined();

    expect(est1!.university).not.toBe('');
    expect(est1!.team?.projectName).toBeTruthy();
    expect(est1!.laboratories.length).toBeGreaterThan(0);
    expect(est1!.overallProgress.coursesTotal).toBeGreaterThan(0);
    expect(est1!.completedObjectives).toHaveProperty('business');
  });

  it('ordena primero a quienes cumplieron objetivos EMPRESARIALES', async () => {
    const page = await body<{ data: Talento[] }>(
      await req('/talent?pageSize=100', donorToken),
    );
    const business = page.data.map((t) => t.completedObjectives.business);
    expect([...business].sort((a, b) => b - a)).toEqual(business);
  });

  it('un mentor no entra a BuscaTalento', async () => {
    expect((await req('/talent', mentorToken)).status).toBe(403);
  });

  it('un estudiante tampoco', async () => {
    expect((await req('/talent', est1Token)).status).toBe(403);
  });

  it('sin sesión, 401', async () => {
    expect((await app.request('/talent')).status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// Avisos
// ---------------------------------------------------------------------------

describe('POST /notifications', () => {
  const enviar = (token: string, userIds: string[], title = 'Aviso') =>
    req('/notifications', token, json({ userIds, title, body: 'Detalle' }));

  it('el admin le puede avisar a cualquiera', async () => {
    const res = await enviar(adminToken, [seedId('est1')]);
    expect(res.status).toBe(201);
    const b = await body<{ sent: number }>(res);
    expect(b.sent).toBe(1);

    const [row] = await sql<{ n: string }[]>`
      select count(*) as n from notifications
       where user_id = ${seedId('est1')} and title = 'Aviso'
    `;
    expect(Number(row!.n)).toBeGreaterThan(0);
  });

  it('llega a la bandeja de quien lo recibe', async () => {
    await enviar(adminToken, [seedId('est1')], 'Para la bandeja');
    const page = await body<{ data: { title: string }[] }>(
      await req('/notifications', est1Token),
    );
    expect(page.data.map((n) => n.title)).toContain('Para la bandeja');
  });

  it('un donante le puede escribir a un estudiante Enactus que NO apoya', async () => {
    // Es el alcance de BuscaTalento: sin él, la pantalla ofrecería contactar a
    // alguien que después no puede contactar.
    const [ajeno] = await sql<{ id: string }[]>`
      select id from users
       where student_type = 'enactus' and role = 'student'
         and (donor_id is null or donor_id <> ${seedId('don1')})
         and deleted_at is null
       limit 1
    `;
    const res = await enviar(donorToken, [ajeno!.id]);
    expect(res.status).toBe(201);
  });

  it('pero NO a un mentor', async () => {
    const [mentor] = await sql<{ id: string }[]>`
      select id from users where role = 'mentor' and deleted_at is null limit 1
    `;
    const res = await enviar(donorToken, [mentor!.id]);
    expect(res.status).toBe(403);
  });

  it('ni a un Open Learning', async () => {
    const [ol] = await sql<{ id: string }[]>`
      select id from users where student_type = 'open_learning' limit 1
    `;
    const res = await enviar(donorToken, [ol!.id]);
    expect(res.status).toBe(403);
  });

  it('un mentor le escribe a los estudiantes de SUS laboratorios', async () => {
    const res = await enviar(mentorToken, [seedId('est1')]);
    expect(res.status).toBe(201);
  });

  it('un estudiante no le escribe a nadie', async () => {
    const res = await enviar(est1Token, [seedId('est2')]);
    expect(res.status).toBe(403);
  });

  it('si un solo destinatario está fuera de alcance, no se manda NINGUNO', async () => {
    // A medias sería peor: la mitad recibe el aviso y quien lo mandó cree que
    // falló entero.
    const [mentor] = await sql<{ id: string }[]>`
      select id from users where role = 'mentor' and deleted_at is null limit 1
    `;
    const [antes] = await sql<{ n: string }[]>`
      select count(*) as n from notifications where title = 'Parcial'
    `;
    const res = await enviar(donorToken, [seedId('est1'), mentor!.id], 'Parcial');
    expect(res.status).toBe(403);
    const [despues] = await sql<{ n: string }[]>`
      select count(*) as n from notifications where title = 'Parcial'
    `;
    expect(Number(despues!.n)).toBe(Number(antes!.n));
  });

  it('el 403 no dice QUIÉNES estaban fuera de alcance', async () => {
    // Decirlo convertiría el endpoint en una forma de enumerar la plataforma.
    const [mentor] = await sql<{ id: string }[]>`
      select id from users where role = 'mentor' and deleted_at is null limit 1
    `;
    const raw = await (await enviar(donorToken, [mentor!.id])).text();
    expect(raw).not.toContain(mentor!.id);
  });

  it('un id inexistente es 403 incluso para el admin', async () => {
    // El admin se salta el ALCANCE, no la EXISTENCIA: sin esa distinción el id
    // inventado llegaba al insert y reventaba contra la clave ajena — un 500
    // donde correspondía un 403.
    const res = await enviar(adminToken, [
      seedId('est1'),
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(res.status).toBe(403);
  });

  it('y a una cuenta borrada tampoco se le escribe', async () => {
    const [borrada] = await sql<{ id: string }[]>`
      select id from users where deleted_at is not null limit 1
    `;
    if (!borrada) return; // el seed puede no tener ninguna
    const res = await enviar(adminToken, [borrada.id]);
    expect(res.status).toBe(403);
  });

  it('sin título es 400', async () => {
    const res = await req(
      '/notifications',
      adminToken,
      json({ userIds: [seedId('est1')], title: '  ' }),
    );
    expect(res.status).toBe(400);
  });

  it('sin destinatarios, también', async () => {
    const res = await enviar(adminToken, []);
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// Una empresa da de alta a SU equipo formador
// ---------------------------------------------------------------------------

describe('POST /users desde una cuenta de empresa', () => {
  const alta = (token: string, extra: Record<string, unknown>) =>
    req(
      '/users',
      token,
      json({
        name: 'Cuenta de prueba',
        email: `prueba-${Math.random().toString(36).slice(2)}@empresa.com`,
        password: 'Prueba123',
        ...extra,
      }),
    );

  it('crea un LXD y queda atado a la empresa', async () => {
    // El amarre es la mitad del permiso: sin él, una empresa podría crear una
    // cuenta suelta y usarla para ver lo que su alcance no le permite.
    const res = await alta(companyToken, { role: 'lxd' });
    expect(res.status).toBe(201);
    const creado = await body<{ id: string }>(res);

    const [row] = await sql<{ company_id: string | null; role: string }[]>`
      select company_id, role from users where id = ${creado.id}
    `;
    expect(row!.role).toBe('lxd');
    expect(row!.company_id).not.toBeNull();
  });

  it('y un mentor', async () => {
    expect((await alta(companyToken, { role: 'mentor' })).status).toBe(201);
  });

  it('ignora el companyId que venga en el formulario', async () => {
    // Aunque pida atarla a otra empresa, queda atada a la suya.
    const [otra] = await sql<{ id: string }[]>`
      select id from users where role = 'company' and deleted_at is null
       order by created_at desc limit 1
    `;
    const res = await alta(companyToken, {
      role: 'mentor',
      companyId: otra!.id,
    });
    expect(res.status).toBe(201);
    const creado = await body<{ id: string }>(res);

    const [row] = await sql<{ company_id: string }[]>`
      select company_id from users where id = ${creado.id}
    `;
    const [empresa] = await sql<{ id: string }[]>`
      select id from users where email = 'empresa@bancolombia.com'
    `;
    expect(row!.company_id).toBe(empresa!.id);
  });

  it('NO crea estudiantes', async () => {
    const res = await alta(companyToken, {
      role: 'student',
      studentType: 'enactus',
    });
    expect(res.status).toBe(403);
  });

  it('NO crea otra empresa', async () => {
    expect((await alta(companyToken, { role: 'company' })).status).toBe(403);
  });

  it('NO crea administradores', async () => {
    expect((await alta(companyToken, { role: 'admin' })).status).toBe(403);
    expect((await alta(companyToken, { role: 'superadmin' })).status).toBe(403);
  });

  it('un donante no crea cuentas de ningún tipo', async () => {
    expect((await alta(donorToken, { role: 'mentor' })).status).toBe(403);
  });

  it('un LXD tampoco', async () => {
    expect((await alta(lxdToken, { role: 'mentor' })).status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// include=reviews
// ---------------------------------------------------------------------------

describe('GET /users?include=reviews', () => {
  it('trae cuántas entregas revisó cada mentor', async () => {
    const res = await req(
      '/users?role=mentor&include=reviews&pageSize=100',
      adminToken,
    );
    expect(res.status).toBe(200);
    const page = await body<{ data: { id: string; reviewsCount: number }[] }>(res);
    expect(page.data.length).toBeGreaterThan(0);

    for (const mentor of page.data) {
      const [esperado] = await sql<{ n: string }[]>`
        select count(*) as n from submissions
         where reviewed_by = ${mentor.id} and reviewed_at is not null
           and deleted_at is null
      `;
      expect(mentor.reviewsCount).toBe(Number(esperado!.n));
    }
  });

  it('sin el include, no se agrega el campo', async () => {
    const page = await body<{ data: Record<string, unknown>[] }>(
      await req('/users?role=mentor&pageSize=100', adminToken),
    );
    expect(page.data[0]).not.toHaveProperty('reviewsCount');
  });
});

// ---------------------------------------------------------------------------
// Galería de la portada
// ---------------------------------------------------------------------------

describe('Galería de la página principal', () => {
  let imagenId = '';

  it('agrega una imagen con key de site-gallery/', async () => {
    const res = await req(
      '/site-content/gallery',
      adminToken,
      json({ s3Key: `site-gallery/prueba-${Date.now()}.png` }),
    );
    expect(res.status).toBe(201);
    const creada = await body<{ id: string }>(res);
    imagenId = creada.id;
  });

  it('aparece en la lectura pública, con su id para administrarla', async () => {
    const res = await app.request('/site-content');
    expect(res.status).toBe(200);
    const b = await body<{
      galleryImages: string[];
      gallery: { id: string; url: string }[];
    }>(res);
    // Sin S3 configurado la galería viene vacía: lo que se prueba es la forma.
    expect(Array.isArray(b.galleryImages)).toBe(true);
    expect(Array.isArray(b.gallery)).toBe(true);
  });

  it('RECHAZA una key de otra carpeta', async () => {
    // La portada se ve sin sesión: publicar acá el adjunto de una entrega lo
    // haría firmable para cualquiera que entrara.
    const res = await req(
      '/site-content/gallery',
      adminToken,
      json({ s3Key: 'submissions/privado.pdf' }),
    );
    expect(res.status).toBe(400);
  });

  it('la misma imagen dos veces es 409, no una fila repetida', async () => {
    const key = `site-gallery/repetida-${Date.now()}.png`;
    expect(
      (await req('/site-content/gallery', adminToken, json({ s3Key: key })))
        .status,
    ).toBe(201);
    expect(
      (await req('/site-content/gallery', adminToken, json({ s3Key: key })))
        .status,
    ).toBe(409);
  });

  it('un LXD no toca la galería de la portada', async () => {
    const res = await req(
      '/site-content/gallery',
      lxdToken,
      json({ s3Key: 'site-gallery/suya.png' }),
    );
    expect(res.status).toBe(403);
  });

  it('la quita', async () => {
    const res = await req(`/site-content/gallery/${imagenId}`, adminToken, {
      method: 'DELETE',
    });
    expect(res.status).toBe(204);
  });

  it('quitar una que no existe es 404', async () => {
    const res = await req(
      '/site-content/gallery/11111111-1111-4111-8111-111111111111',
      adminToken,
      { method: 'DELETE' },
    );
    expect(res.status).toBe(404);
  });
});
