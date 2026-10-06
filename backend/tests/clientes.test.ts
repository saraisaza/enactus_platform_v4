import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { useMediaStorageForTests } from '../src/lib/media-storage';
import { medidasDePng } from '../src/lib/png';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { drainStorageDeletes } from '../src/services/storage-cleanup';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';
import { FakeMediaStorage } from './helpers/fake-storage';

/**
 * Clientes con marca propia: el panel de administración (etapa 2).
 *
 * Lo que se fija acá:
 * - Enactus existe sin que nadie lo cree, y no se puede apagar con un clic.
 * - Los colores entran como los escribe una persona y salen normalizados.
 * - El logo se verifica MIRANDO EL ARCHIVO, no lo que dijo el navegador: un
 *   JPG renombrado a .png no pasa, ni uno diminuto, ni uno gigante.
 * - Un logo reemplazado se borra de S3, y uno en uso nunca.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let s3: FakeMediaStorage;
let admin = '';
let superadmin = '';

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
  superadmin = (await login(t.app, 'superadmin1@enactus.co', 'Super123')).accessToken;
  s3 = new FakeMediaStorage();
  useMediaStorageForTests(s3);
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  useMediaStorageForTests(null);
  await sql.end();
});

/** Los primeros bytes de un PNG de [ancho]×[alto]: firma + bloque IHDR. */
function png(ancho: number, alto: number): Uint8Array {
  const bytes = new Uint8Array(33);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const vista = new DataView(bytes.buffer);
  vista.setUint32(8, 13);
  bytes.set([0x49, 0x48, 0x44, 0x52], 12); // IHDR
  vista.setUint32(16, ancho);
  vista.setUint32(20, alto);
  return bytes;
}

/** Los primeros bytes de un JPG. */
const JPG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, ...new Array<number>(40).fill(0)]);

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

/** Pide el permiso y "sube" [contenido] como lo haría el navegador. */
async function subirLogo(contenido: Uint8Array): Promise<string> {
  const res = await pedir('/clients/logo-upload-url', 'POST', admin, {
    contentType: 'image/png',
    sizeBytes: contenido.length,
  });
  expect(res.status).toBe(200);
  const { key } = (await res.json()) as { key: string };
  s3.subirArchivo(key, contenido);
  return key;
}

type Cliente = {
  id: string;
  name: string;
  primaryColor: string | null;
  secondaryColor: string | null;
  logoS3Key: string | null;
  logoWidth: number | null;
  logoHeight: number | null;
  logoLightPlate: boolean;
  hasLaboratories: boolean;
  active: boolean;
};

async function crear(cuerpo: Record<string, unknown>): Promise<Cliente> {
  const res = await pedir('/clients', 'POST', admin, cuerpo);
  expect(res.status, await res.clone().text()).toBe(201);
  return (await res.json()) as Cliente;
}

describe('el cliente Enactus', () => {
  it('existe desde la migración, con laboratorios y sin marca propia', async () => {
    const res = await pedir('/clients', 'GET', admin);
    expect(res.status).toBe(200);
    const { data } = (await res.json()) as { data: Cliente[] };
    const enactus = data.find((c) => c.hasLaboratories);
    expect(enactus?.name).toBe('Enactus');
    expect(enactus?.primaryColor).toBeNull();
    expect(enactus?.logoS3Key).toBeNull();
    expect(data[0]?.hasLaboratories, 'Enactus va primero en la lista').toBe(true);
  });

  it('no se puede desactivar desde el panel', async () => {
    const [enactus] = await sql<{ id: string }[]>`
      select id from clients where has_laboratories`;
    const res = await pedir(`/clients/${enactus!.id}`, 'PATCH', admin, { active: false });
    expect(res.status).toBe(409);
    const [fila] = await sql<{ active: boolean }[]>`
      select active from clients where id = ${enactus!.id}`;
    expect(fila!.active).toBe(true);
  });

  it('la base no admite un segundo cliente con laboratorios', async () => {
    await expect(
      sql`insert into clients (name, has_laboratories) values ('Otro con labs', true)`,
    ).rejects.toThrow(/clients_one_with_laboratories/);
  });

  it('pueden ponerle logo y colores, como a cualquier cliente', async () => {
    const [enactus] = await sql<{ id: string }[]>`
      select id from clients where has_laboratories`;
    const res = await pedir(`/clients/${enactus!.id}`, 'PATCH', admin, {
      primaryColor: '#1d4f91',
    });
    expect(res.status).toBe(200);
    expect(((await res.json()) as Cliente).primaryColor).toBe('#1D4F91');
    await sql`update clients set primary_color = null where id = ${enactus!.id}`;
  });
});

describe('quién administra los clientes', () => {
  it('solo admin y superadmin', async () => {
    for (const [email, clave] of [
      ['lxd.ia@enactus.co', 'Lxd123'],
      ['empresa@bancolombia.com', 'Empresa123'],
      ['estudiante1@uniandes.edu.co', 'Est123'],
      ['mentor.ia@enactus.co', 'Mentor123'],
    ] as const) {
      resetRateLimits();
      const token = (await login(t.app, email, clave)).accessToken;
      for (const [ruta, metodo] of [
        ['/clients', 'GET'],
        ['/clients', 'POST'],
        ['/clients/logo-upload-url', 'POST'],
      ] as const) {
        const res = await pedir(ruta, metodo, token, metodo === 'GET' ? undefined : { name: 'X' });
        expect(res.status, `${email}: ${metodo} ${ruta}`).toBe(403);
      }
    }
    expect((await pedir('/clients', 'GET', superadmin)).status).toBe(200);
  });
});

describe('crear y editar', () => {
  it('los colores entran como los escribe una persona y salen normalizados', async () => {
    const c = await crear({
      name: '  Banco   Andino ',
      primaryColor: '1a73e8',
      secondaryColor: '#0b5394',
    });
    expect(c.name).toBe('Banco Andino');
    expect(c.primaryColor).toBe('#1A73E8');
    expect(c.secondaryColor).toBe('#0B5394');
    expect(c.active).toBe(true);
    expect(c.hasLaboratories).toBe(false);

    const [auditoria] = await sql<{ action: string }[]>`
      select action from audit_log where entity_id = ${c.id}`;
    expect(auditoria?.action).toBe('client.create');
  });

  it('sin colores ni logo, es un cliente con la marca de eduXaction', async () => {
    const c = await crear({ name: 'Sin Marca SAS' });
    expect(c.primaryColor).toBeNull();
    expect(c.secondaryColor).toBeNull();
    expect(c.logoS3Key).toBeNull();
  });

  it('un color que no es hexadecimal se rechaza', async () => {
    for (const color of ['azul', '#12345', '#GGGGGG', 'rgb(0,0,0)']) {
      const res = await pedir('/clients', 'POST', admin, { name: `C ${color}`, primaryColor: color });
      expect(res.status, color).toBe(400);
    }
  });

  it('dos clientes no pueden llamarse igual, ni con otras mayúsculas', async () => {
    await crear({ name: 'Ferretería Sol' });
    const res = await pedir('/clients', 'POST', admin, { name: 'FERRETERÍA SOL' });
    expect(res.status).toBe(409);
  });

  it('renombrar a un nombre ocupado tampoco', async () => {
    const a = await crear({ name: 'Cliente A' });
    await crear({ name: 'Cliente B' });
    const res = await pedir(`/clients/${a.id}`, 'PATCH', admin, { name: 'cliente b' });
    expect(res.status).toBe(409);
    // Conservar su propio nombre no es un choque consigo mismo.
    const mismo = await pedir(`/clients/${a.id}`, 'PATCH', admin, { name: 'Cliente A' });
    expect(mismo.status).toBe(200);
  });

  it('editar un campo no borra los que no se mandaron', async () => {
    const c = await crear({ name: 'Parcial SA', primaryColor: '#112233', secondaryColor: '#445566' });
    const res = await pedir(`/clients/${c.id}`, 'PATCH', admin, { name: 'Parcial SAS' });
    const despues = (await res.json()) as Cliente;
    expect(despues.primaryColor).toBe('#112233');
    expect(despues.secondaryColor).toBe('#445566');
    expect(despues.logoLightPlate).toBe(false);
  });

  it('null quita un color: vuelve el de eduXaction', async () => {
    const c = await crear({ name: 'Quita Color', primaryColor: '#112233' });
    const res = await pedir(`/clients/${c.id}`, 'PATCH', admin, { primaryColor: null });
    expect(((await res.json()) as Cliente).primaryColor).toBeNull();
  });

  it('desactivar y reactivar quedan en la bitácora', async () => {
    const c = await crear({ name: 'Temporal Ltda' });
    const off = await pedir(`/clients/${c.id}`, 'PATCH', admin, { active: false });
    expect(((await off.json()) as Cliente).active).toBe(false);
    await pedir(`/clients/${c.id}`, 'PATCH', admin, { active: true });
    const acciones = await sql<{ action: string }[]>`
      select action from audit_log where entity_id = ${c.id} order by created_at`;
    expect(acciones.map((a) => a.action)).toEqual([
      'client.create',
      'client.deactivate',
      'client.activate',
    ]);
  });

  it('un cliente que no existe es 404', async () => {
    const res = await pedir('/clients/00000000-0000-4000-8000-000000000000', 'PATCH', admin, {
      name: 'Nadie',
    });
    expect(res.status).toBe(404);
  });
});

describe('el logo', () => {
  it('el permiso es solo para PNG de hasta 1 MB', async () => {
    const jpg = await pedir('/clients/logo-upload-url', 'POST', admin, {
      contentType: 'image/jpeg',
      sizeBytes: 1000,
    });
    expect(jpg.status).toBe(400);
    const grande = await pedir('/clients/logo-upload-url', 'POST', admin, {
      contentType: 'image/png',
      sizeBytes: 1024 * 1024 + 1,
    });
    expect(grande.status).toBe(413);
  });

  it('un PNG de verdad entra, con sus medidas', async () => {
    const key = await subirLogo(png(640, 200));
    expect(key).toMatch(/^client-logos\/[0-9a-f-]+\.png$/);
    const c = await crear({ name: 'Con Logo SA', logoS3Key: key, logoLightPlate: true });
    expect(c.logoS3Key).toBe(key);
    expect([c.logoWidth, c.logoHeight]).toEqual([640, 200]);
    expect(c.logoLightPlate).toBe(true);
  });

  it('un JPG renombrado a .png no pasa: se mira el archivo, no el nombre', async () => {
    const key = await subirLogo(JPG);
    const res = await pedir('/clients', 'POST', admin, { name: 'Falso PNG', logoS3Key: key });
    expect(res.status).toBe(400);
    expect(await res.text()).toMatch(/no es un PNG/);
  });

  it('uno muy chico se vería borroso, y uno gigante no aporta nada', async () => {
    const chico = await subirLogo(png(120, 60));
    expect((await pedir('/clients', 'POST', admin, { name: 'Chico', logoS3Key: chico })).status)
      .toBe(400);
    const gigante = await subirLogo(png(5000, 800));
    expect((await pedir('/clients', 'POST', admin, { name: 'Gigante', logoS3Key: gigante })).status)
      .toBe(400);
    // El límite de abajo es el lado MAYOR: un logo alto y angosto también vale.
    const vertical = await subirLogo(png(90, 240));
    expect((await pedir('/clients', 'POST', admin, { name: 'Vertical', logoS3Key: vertical })).status)
      .toBe(201);
  });

  it('una key que no subió el panel, o que no llegó, no se acepta', async () => {
    const ajena = await pedir('/clients', 'POST', admin, {
      name: 'Ajena',
      logoS3Key: 'avatars/alguien.png',
    });
    expect(ajena.status).toBe(400);
    const subida = await pedir('/clients', 'POST', admin, {
      name: 'No Llegó',
      logoS3Key: 'client-logos/00000000-0000-4000-8000-000000000000.png',
    });
    expect(subida.status).toBe(409);
  });

  it('al reemplazarlo, el anterior se borra de S3', async () => {
    const primero = await subirLogo(png(400, 400));
    const c = await crear({ name: 'Cambia Logo', logoS3Key: primero });
    const segundo = await subirLogo(png(800, 300));
    const res = await pedir(`/clients/${c.id}`, 'PATCH', admin, { logoS3Key: segundo });
    const despues = (await res.json()) as Cliente;
    expect(despues.logoS3Key).toBe(segundo);
    expect([despues.logoWidth, despues.logoHeight]).toEqual([800, 300]);
    expect(s3.borrados).toContain(primero);
    expect(s3.borrados).not.toContain(segundo);
  });

  it('quitarlo (null) borra el archivo y las medidas', async () => {
    const key = await subirLogo(png(400, 400));
    const c = await crear({ name: 'Quita Logo', logoS3Key: key });
    const res = await pedir(`/clients/${c.id}`, 'PATCH', admin, { logoS3Key: null });
    const despues = (await res.json()) as Cliente;
    expect([despues.logoS3Key, despues.logoWidth, despues.logoHeight]).toEqual([null, null, null]);
    expect(s3.borrados).toContain(key);
  });

  it('la cola de borrado nunca se lleva un logo que algún cliente usa', async () => {
    // Pasa al restaurar un respaldo: el cliente vuelve a apuntar a un logo que
    // ya estaba anotado para borrar.
    const key = await subirLogo(png(400, 400));
    await crear({ name: 'Logo En Uso', logoS3Key: key });
    await sql`insert into storage_pending_deletes (key, reason)
              values (${key}, 'client_logo_replaced')`;
    const resultado = await drainStorageDeletes(t.db);
    expect(resultado.stillInUse).toBeGreaterThanOrEqual(1);
    expect(s3.borrados).not.toContain(key);
  });

  it('la base exige que el logo vaya completo', async () => {
    await expect(
      sql`insert into clients (name, logo_s3_key) values ('Sin medidas', 'client-logos/x.png')`,
    ).rejects.toThrow(/clients_logo_complete/);
    await expect(
      sql`insert into clients (name, primary_color) values ('Mal color', '#1a73e8')`,
    ).rejects.toThrow(/clients_primary_color_hex/);
  });
});

describe('medidasDePng', () => {
  it('lee ancho y alto, y rechaza lo que no es PNG', () => {
    expect(medidasDePng(png(1234, 567))).toEqual({ width: 1234, height: 567 });
    expect(medidasDePng(JPG)).toBeNull();
    expect(medidasDePng(png(10, 10).slice(0, 20))).toBeNull();
    expect(medidasDePng(png(0, 10))).toBeNull();
    // El bloque IHDR en su lugar no alcanza: sin la firma de 8 bytes del
    // principio, no es un PNG.
    const firmaRota = png(400, 400);
    firmaRota[1] = 0x00;
    expect(medidasDePng(firmaRota)).toBeNull();
  });
});

describe('respaldo', () => {
  it('lleva los clientes, y uno viejo que no los trae no los borra', async () => {
    const res = await t.app.request('/admin/backup', { headers: auth(superadmin) });
    const respaldo = (await res.json()) as { version: number; data: Record<string, unknown[]> };
    expect((respaldo.data.clients ?? []).length).toBeGreaterThan(1);

    // Un respaldo de antes de los clientes: el archivo no trae la tabla.
    const { clients: _sinClientes, ...viejo } = respaldo.data;
    const antes = await sql`select id from clients order by id`;
    const restaurar = await t.app.request('/admin/restore', {
      ...json({ version: respaldo.version, data: viejo, confirm: 'REEMPLAZAR TODOS LOS DATOS' }),
      headers: { 'content-type': 'application/json', ...auth(superadmin) },
    });
    expect(restaurar.status, await restaurar.clone().text()).toBe(200);
    expect(await sql`select id from clients order by id`).toEqual(antes);
  });
});
