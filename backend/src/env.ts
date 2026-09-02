import 'dotenv/config';
import { z } from 'zod';

/**
 * Configuración validada al arrancar. Si falta algo, el proceso muere acá con
 * un mensaje claro, en vez de fallar más adelante con un `undefined`.
 *
 * Los secretos NUNCA vienen del repositorio: en local salen de `backend/.env`
 * (que está en .gitignore) y en AWS de Secrets Manager, inyectados como
 * variables de entorno de la Lambda.
 */
const schema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'production'])
    .default('development'),
  DATABASE_URL: z.string().min(1, 'Falta DATABASE_URL'),
  TEST_DATABASE_URL: z.string().optional(),

  JWT_SECRET: z
    .string()
    .min(32, 'JWT_SECRET debe tener al menos 32 caracteres'),
  ACCESS_TOKEN_TTL: z.string().default('12h'),
  REFRESH_TOKEN_TTL: z.string().default('30d'),

  AWS_REGION: z.string().default('us-east-1'),
  S3_BUCKET: z.string().default(''),
  CLOUDFRONT_DOMAIN: z.string().default(''),
  CLOUDFRONT_KEY_PAIR_ID: z.string().default(''),
  CLOUDFRONT_PRIVATE_KEY: z.string().default(''),

  CORS_ORIGIN: z.string().default('http://localhost:8080'),
  PORT: z.coerce.number().int().positive().default(3000),

  /**
   * Cuántos proxies de confianza hay DELANTE de la aplicación.
   *
   * De este número depende de qué entrada de `x-forwarded-for` se saca la IP
   * del cliente, y de esa IP dependen los dos límites de peticiones. Ponerlo
   * mal no rompe nada visible — simplemente el límite deja de frenar, en
   * silencio.
   *
   * `0` (el default) significa "no hay proxy": se ignora `x-forwarded-for`
   * por completo y se usa la IP de la conexión, que el cliente no puede
   * falsificar. Es el único valor seguro cuando no se sabe.
   *
   * Con CloudFront → API Gateway → Lambda son 2. Ver "Cómo se cuenta la IP
   * del cliente" en RUNBOOK.md, que incluye cómo verificarlo contra el
   * despliegue real en vez de suponerlo.
   */
  TRUSTED_PROXY_HOPS: z.coerce.number().int().min(0).max(4).default(0),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  const detail = parsed.error.issues
    .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
    .join('\n');
  throw new Error(`Configuración inválida:\n${detail}`);
}

export const env = parsed.data;

/**
 * La base contra la que corre el proceso actual. En tests apunta a
 * `TEST_DATABASE_URL` para no tocar nunca los datos de desarrollo.
 */
export const databaseUrl =
  env.NODE_ENV === 'test' && env.TEST_DATABASE_URL
    ? env.TEST_DATABASE_URL
    : env.DATABASE_URL;
