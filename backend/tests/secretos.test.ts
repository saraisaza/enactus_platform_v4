import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * El cargador de configuración desde S3.
 *
 * Es código que solo corre en producción —en local la configuración sale de
 * `backend/.env`— así que un fallo suyo se descubriría en el primer arranque
 * en frío, con la plataforma ya publicada. De ahí que se pruebe con más
 * cuidado del que su tamaño sugiere.
 *
 * Lo que más importa: que **falle ruidosamente**. Arrancar con la
 * configuración a medias haría que la API firmara tokens con un `JWT_SECRET`
 * vacío o se conectara a la base equivocada, y ninguna de las dos cosas se ve
 * hasta que es tarde.
 */

const enviar = vi.fn();
vi.mock('@aws-sdk/client-s3', () => ({
  S3Client: class {
    send = enviar;
  },
  GetObjectCommand: class {
    constructor(public input: unknown) {}
  },
}));

const CONFIG_COMPLETA = {
  DATABASE_URL: 'postgres://usuario:clave@host:5432/enactus_prod?sslmode=verify-full',
  JWT_SECRET: 'a'.repeat(64),
  CORS_ORIGIN: 'https://eduxaction.com',
  NODE_ENV: 'production',
  TRUSTED_PROXY_HOPS: '2',
};

const respuestaCon = (texto: string) => ({
  Body: { transformToString: () => Promise.resolve(texto) },
});

const entornoOriginal = { ...process.env };

async function cargar() {
  const modulo = await import('../src/lib/secretos');
  modulo.olvidarSecretos();
  return modulo;
}

beforeEach(() => {
  enviar.mockReset();
  vi.resetModules();
  for (const nombre of Object.keys(CONFIG_COMPLETA)) delete process.env[nombre];
  process.env.SECRETS_BUCKET = 'enactus-secretos';
  process.env.SECRETS_KEY = 'prod/runtime.json';
});

afterEach(() => {
  process.env = { ...entornoOriginal };
});

describe('lectura', () => {
  it('vuelca la configuración en el entorno', async () => {
    enviar.mockResolvedValue(respuestaCon(JSON.stringify(CONFIG_COMPLETA)));
    const { cargarSecretos } = await cargar();
    await cargarSecretos();

    expect(process.env.JWT_SECRET).toBe(CONFIG_COMPLETA.JWT_SECRET);
    expect(process.env.TRUSTED_PROXY_HOPS).toBe('2');
  });

  it('lee UNA sola vez por contenedor', async () => {
    // Leerlo en cada invocación agregaría un viaje a S3 a cada petición de
    // cada persona, para traer siempre lo mismo.
    enviar.mockResolvedValue(respuestaCon(JSON.stringify(CONFIG_COMPLETA)));
    const { cargarSecretos } = await cargar();

    await cargarSecretos();
    await cargarSecretos();
    await cargarSecretos();
    expect(enviar).toHaveBeenCalledTimes(1);
  });

  it('dos arranques en paralelo comparten la misma lectura', async () => {
    // Se guarda la promesa, no el resultado: si no, dos invocaciones
    // concurrentes durante el arranque en frío dispararían dos lecturas.
    enviar.mockResolvedValue(respuestaCon(JSON.stringify(CONFIG_COMPLETA)));
    const { cargarSecretos } = await cargar();

    await Promise.all([cargarSecretos(), cargarSecretos(), cargarSecretos()]);
    expect(enviar).toHaveBeenCalledTimes(1);
  });

  it('sin las variables de S3 no hace nada: es el caso de local', async () => {
    delete process.env.SECRETS_BUCKET;
    delete process.env.SECRETS_KEY;
    const { cargarSecretos } = await cargar();

    await cargarSecretos();
    expect(enviar).not.toHaveBeenCalled();
  });

  it('lo que ya está en el entorno gana', async () => {
    // Permite corregir un valor suelto desde la consola de Lambda sin tocar
    // el secreto — que es lo que uno quiere a las 2 de la mañana.
    process.env.CORS_ORIGIN = 'https://otro-dominio.com';
    enviar.mockResolvedValue(respuestaCon(JSON.stringify(CONFIG_COMPLETA)));
    const { cargarSecretos } = await cargar();

    await cargarSecretos();
    expect(process.env.CORS_ORIGIN).toBe('https://otro-dominio.com');
    expect(process.env.JWT_SECRET).toBe(CONFIG_COMPLETA.JWT_SECRET);
  });
});

describe('falla ruidosamente, nunca a medias', () => {
  it('si S3 no responde, revienta', async () => {
    enviar.mockRejectedValue(new Error('AccessDenied'));
    const { cargarSecretos } = await cargar();

    await expect(cargarSecretos()).rejects.toThrow(/No pude leer la configuración/);
    expect(process.env.JWT_SECRET).toBeUndefined();
  });

  it('si falta una clave, dice cuál y no arranca', async () => {
    const { JWT_SECRET: _, ...incompleta } = CONFIG_COMPLETA;
    enviar.mockResolvedValue(respuestaCon(JSON.stringify(incompleta)));
    const { cargarSecretos } = await cargar();

    await expect(cargarSecretos()).rejects.toThrow(/le faltan: JWT_SECRET/);
  });

  it('si el contenido no es JSON, revienta SIN mostrarlo', async () => {
    // El contenido de ese objeto es exactamente el secreto: incluirlo en el
    // mensaje lo mandaría a los logs de CloudWatch.
    const basura = 'esto-no-es-json-pero-podria-ser-una-clave-privada';
    enviar.mockResolvedValue(respuestaCon(basura));
    const { cargarSecretos } = await cargar();

    await expect(cargarSecretos()).rejects.toThrow(/no es JSON válido/);
    await expect(cargarSecretos()).rejects.not.toThrow(
      new RegExp(basura.slice(0, 20)),
    );
  });

  it('el mensaje de error nunca lleva un valor de la configuración', async () => {
    enviar.mockResolvedValue(respuestaCon(JSON.stringify({ DATABASE_URL: 'x' })));
    const { cargarSecretos } = await cargar();

    const fallo = await cargarSecretos().catch((e: Error) => e.message);
    expect(fallo).toContain('le faltan');
    expect(fallo).not.toContain(CONFIG_COMPLETA.JWT_SECRET);
  });
});
