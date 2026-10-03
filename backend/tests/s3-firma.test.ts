import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

/**
 * La URL de subida que firma `lib/s3.ts`, mirada parámetro por parámetro.
 *
 * Firmar es un cálculo local: no hace falta bucket real ni credenciales
 * válidas, así que esto corre sin AWS. Lo que se prueba es lo que el
 * navegador recibe, que es justo lo que ninguna prueba de la API veía.
 */

let createUploadUrl: typeof import('../src/lib/s3').createUploadUrl;

beforeAll(async () => {
  vi.stubEnv('S3_BUCKET', 'bucket-de-prueba');
  vi.stubEnv('AWS_ACCESS_KEY_ID', 'AKIAPRUEBA');
  vi.stubEnv('AWS_SECRET_ACCESS_KEY', 'secreto-de-prueba');
  vi.stubEnv('AWS_SESSION_TOKEN', '');
  if (!process.env.DATABASE_URL) vi.stubEnv('DATABASE_URL', 'postgres://x');
  if (!process.env.JWT_SECRET) vi.stubEnv('JWT_SECRET', 'x'.repeat(32));
  vi.resetModules();
  ({ createUploadUrl } = await import('../src/lib/s3'));
});

afterAll(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe('URL firmada de subida', () => {
  it('no lleva el checksum de un cuerpo vacío', async () => {
    // Con la SDK por defecto la URL traía `x-amz-checksum-crc32=AAAAAA==`
    // (el CRC32 de cero bytes): S3 rechazaba cualquier archivo real.
    const { uploadUrl } = await createUploadUrl({
      key: 'lesson-resources/prueba.png',
      contentType: 'image/png',
      sizeBytes: 1234,
    });

    const params = [...new URL(uploadUrl).searchParams.keys()].map((k) =>
      k.toLowerCase(),
    );
    expect(params.filter((k) => k.includes('checksum'))).toEqual([]);
  });
});

describe('CORS del bucket de medios', () => {
  // El navegador sube DIRECTO a S3: si el bucket no acepta el origen de la
  // página, el PUT muere en el preflight y la API nunca se entera.
  const cors = JSON.parse(
    readFileSync(join(__dirname, '../infra/s3-cors.json'), 'utf8'),
  ) as {
    CORSRules: Array<{
      AllowedOrigins: string[];
      AllowedMethods: string[];
      AllowedHeaders: string[];
    }>;
  };

  it.each([
    'https://eduxaction.com',
    'https://www.eduxaction.com',
    'https://staging.eduxaction.com',
  ])('acepta PUT con content-type desde %s', (origin) => {
    const regla = cors.CORSRules.find((r) => r.AllowedOrigins.includes(origin));
    expect(regla, `ninguna regla permite ${origin}`).toBeDefined();
    expect(regla!.AllowedMethods).toContain('PUT');
    expect(regla!.AllowedMethods).toContain('GET');
    expect(regla!.AllowedHeaders.map((h) => h.toLowerCase())).toContain(
      'content-type',
    );
  });
});
