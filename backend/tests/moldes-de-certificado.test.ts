import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { useMediaStorageForTests } from '../src/lib/media-storage';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';
import { FakeMediaStorage } from './helpers/fake-storage';

/**
 * Moldes de certificado (etapa 6, parte 2).
 *
 * El admin sube el diseño de cada cliente —un PDF de una página o una imagen—
 * y marca dónde va cada dato. Cada certificado se imprime con el molde de su
 * cliente emisor; sin molde propio, con el de eduXaction; sin ninguno, con el
 * diseño de siempre. Y el molde lo pide solo quien puede ver ese certificado.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let s3: FakeMediaStorage;
let admin = '';
let andino = '';

const PDF = new TextEncoder().encode('%PDF-1.7\n%âãÏÓ\n1 0 obj');
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13]);
const JPG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);

const CAMPOS = {
  nombre: { x: 0.1, y: 0.4, w: 0.8, size: 0.06, align: 'center', font: 'display', bold: true },
  curso: { x: 0.1, y: 0.55, w: 0.8, size: 0.035 },
  fecha: { x: 0.08, y: 0.85, w: 0.3, size: 0.02, align: 'left' },
  qr: { x: 0.85, y: 0.8, w: 0.1 },
  firma: { x: 0.4, y: 0.75, w: 0.2 },
};

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

/** Pide el permiso y «sube» [contenido] como lo haría el navegador. */
async function subir(use: 'background' | 'signature', contentType: string, contenido: Uint8Array) {
  const res = await pedir('/clients/certificate-template-upload-url', 'POST', admin, {
    use, contentType, sizeBytes: contenido.length,
  });
  expect(res.status, await res.clone().text()).toBe(200);
  const { key } = (await res.json()) as { key: string };
  s3.subirArchivo(key, contenido);
  return key;
}

async function guardar(owner: string, cuerpo: Record<string, unknown>) {
  return pedir(`/clients/${owner}/certificate-template`, 'PUT', admin, cuerpo);
}

/** Una persona que termina un curso de Open Learning y recibe su certificado. */
async function certificadoDe(correo: string, clientId: string | null) {
  const crear = async (ruta: string, cuerpo: unknown) =>
    (await (await pedir(ruta, 'POST', admin, cuerpo)).json()) as { id: string };
  const curso = await crear('/courses', { name: `Curso ${correo}`, isOpenLearning: true });
  const modulo = await crear(`/courses/${curso.id}/modules`, { title: 'M' });
  const leccion = await crear(`/modules/${modulo.id}/lessons`, { title: 'L', type: 'resource' });
  await sql`update courses set status = 'published' where id = ${curso.id}`;
  const persona = await crear('/users', {
    name: correo, email: correo, password: 'Clave123', role: 'student',
    studentType: 'open_learning', ...(clientId ? { clientId } : {}),
  });
  await pedir(`/users/${persona.id}/courses`, 'PUT', admin, { ids: [curso.id] });
  const token = (await login(t.app, correo, 'Clave123')).accessToken;
  await pedir(`/progress/lessons/${leccion.id}/complete`, 'POST', token);
  const [cert] = await sql<{ id: string; issuerClientId: string | null }[]>`
    select id, issuer_client_id as "issuerClientId" from certificates
     where student_id = ${persona.id}`;
  return { cert: cert!, token };
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
  s3 = new FakeMediaStorage();
  useMediaStorageForTests(s3);
  const res = await pedir('/clients', 'POST', admin, { name: 'Banco Andino' });
  andino = ((await res.json()) as { id: string }).id;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  useMediaStorageForTests(null);
  await sql.end();
});

describe('subir y guardar un molde', () => {
  it('un PDF, con la firma: queda guardado con sus posiciones', async () => {
    const fondo = await subir('background', 'application/pdf', PDF);
    const firma = await subir('signature', 'image/png', PNG);
    const res = await guardar(andino, {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595,
      fields: CAMPOS, signatureS3Key: firma,
    });
    expect(res.status, await res.clone().text()).toBe(200);
    const { template } = (await res.json()) as {
      template: { backgroundKind: string; fields: Record<string, { color?: string }> };
    };
    expect(template.backgroundKind).toBe('pdf');
    // Lo que no se dijo toma su valor por omisión.
    expect(template.fields.curso!.color).toBe('#1F1F1F');

    const leido = await pedir(`/clients/${andino}/certificate-template`, 'GET', admin);
    expect(((await leido.json()) as { template: unknown }).template).toMatchObject({
      backgroundS3Key: fondo, signatureS3Key: firma, pageWidth: 842,
    });
  });

  it('el tipo sale del archivo, no de lo que diga la petición', async () => {
    // Se pide permiso «como PDF» pero lo que llega es un JPG: se guarda JPG.
    const fondo = await subir('background', 'application/pdf', JPG);
    const res = await guardar('eduxaction', {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595, fields: CAMPOS,
    });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { template: { backgroundKind: string } }).template.backgroundKind)
      .toBe('jpeg');
  });

  it('rechaza lo que no es un molde', async () => {
    // Un archivo que no es PDF, PNG ni JPG.
    const raro = await subir('background', 'image/png', new TextEncoder().encode('hola mundo'));
    expect((await guardar(andino, {
      backgroundS3Key: raro, pageWidth: 842, pageHeight: 595, fields: CAMPOS,
    })).status).toBe(400);
    // Una firma que no es PNG.
    const fondo = await subir('background', 'image/png', PNG);
    const firmaJpg = await subir('signature', 'image/png', JPG);
    expect((await guardar(andino, {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595, fields: CAMPOS,
      signatureS3Key: firmaJpg,
    })).status).toBe(400);
    // Sin el nombre no hay certificado.
    const { nombre: _sinNombre, ...sinNombre } = CAMPOS;
    expect((await guardar(andino, {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595, fields: sinNombre,
    })).status).toBe(400);
    // Posiciones fuera de la página, o un dato que no existe.
    expect((await guardar(andino, {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595,
      fields: { ...CAMPOS, nombre: { ...CAMPOS.nombre, x: 1.4 } },
    })).status).toBe(400);
    expect((await guardar(andino, {
      backgroundS3Key: fondo, pageWidth: 842, pageHeight: 595,
      fields: { ...CAMPOS, cedula: { x: 0, y: 0, w: 0.1, size: 0.02 } },
    })).status).toBe(400);
    // Una key de otra carpeta.
    expect((await guardar(andino, {
      backgroundS3Key: 'client-logos/x.png', pageWidth: 842, pageHeight: 595, fields: CAMPOS,
    })).status).toBe(400);
    // Un permiso de subida de un tipo que no sirve.
    expect((await pedir('/clients/certificate-template-upload-url', 'POST', admin, {
      use: 'background', contentType: 'application/msword', sizeBytes: 100,
    })).status).toBe(400);
  });

  it('reemplazar el fondo suelta el anterior para borrarlo', async () => {
    const [antes] = await sql<{ key: string }[]>`
      select background_s3_key as key from certificate_templates where client_id = ${andino}`;
    const nuevo = await subir('background', 'image/png', PNG);
    expect((await guardar(andino, {
      backgroundS3Key: nuevo, pageWidth: 842, pageHeight: 595, fields: CAMPOS,
    })).status).toBe(200);
    expect(s3.borrados).toContain(antes!.key);
  });

  it('solo la administración', async () => {
    const est = (await login(t.app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
    expect((await pedir(`/clients/${andino}/certificate-template`, 'GET', est)).status).toBe(403);
  });
});

describe('con qué molde se imprime cada certificado', () => {
  it('el de su cliente emisor; sin molde propio, el de eduXaction', async () => {
    const deAndino = await certificadoDe('ana@andino.co', andino);
    expect(deAndino.cert.issuerClientId).toBe(andino);
    const molde = await pedir(`/certificates/${deAndino.cert.id}/template`, 'GET', deAndino.token);
    expect(molde.status).toBe(200);
    expect(((await molde.json()) as { template: { clientId: string } }).template.clientId)
      .toBe(andino);

    // Sin cliente: el de eduXaction (lo guardó la prueba de arriba).
    const sinCliente = await certificadoDe('libre@correo.co', null);
    const suyo = await pedir(`/certificates/${sinCliente.cert.id}/template`, 'GET', sinCliente.token);
    expect(((await suyo.json()) as { template: { clientId: string | null } }).template.clientId)
      .toBeNull();
  });

  it('sin ningún molde, el diseño de siempre', async () => {
    expect((await pedir('/clients/eduxaction/certificate-template', 'DELETE', admin)).status)
      .toBe(204);
    const sinCliente = await certificadoDe('otra@correo.co', null);
    const res = await pedir(`/certificates/${sinCliente.cert.id}/template`, 'GET', sinCliente.token);
    expect(((await res.json()) as { template: unknown }).template).toBeNull();
  });

  it('el molde de un certificado ajeno no se entrega', async () => {
    const deAndino = await certificadoDe('beto@andino.co', andino);
    const otro = await certificadoDe('carla@correo.co', null);
    expect((await pedir(`/certificates/${deAndino.cert.id}/template`, 'GET', otro.token)).status)
      .toBe(404);
  });
});
