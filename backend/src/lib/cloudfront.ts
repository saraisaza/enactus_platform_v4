import { createSign } from 'node:crypto';

import { env } from '../env';
import { AppError } from './errors';

/**
 * Reproducción de video propio: URL firmada de CloudFront.
 *
 * Un video subido a S3 NUNCA se sirve con una URL firmada de S3 (lo impide
 * `assertNotVideo` en `services/file-access.ts`). La razón es de costo, no de
 * estilo: la salida de S3 se cobra desde el primer byte y la de CloudFront
 * trae 1 TB al mes. Servir un curso en video desde S3 es la forma más cara de
 * hacerlo.
 *
 * Acá se firma con la *canned policy* de CloudFront, que es la más simple de
 * las dos que acepta: un recurso, una fecha de vencimiento, nada más. La
 * *custom policy* agrega rango de IP y comodines en la ruta; ninguno de los
 * dos aporta algo acá y su política va en la query, lo que alarga la URL sin
 * ganancia.
 *
 * Esta función **no decide quién puede ver qué**. Eso vive en
 * `services/file-access.ts`, contra la fila que referencia la key. Firmar sin
 * ese paso equivale a publicar la distribución.
 */

/**
 * Vigencia de la URL de reproducción: corta a propósito.
 *
 * Una URL firmada es un permiso que viaja suelto —sin token y sin sesión—, así
 * que quien tenga el enlace ve el video hasta que venza. Cinco minutos alcanzan
 * de sobra para que el reproductor empiece: CloudFront valida la firma al
 * abrir la conexión, no durante la reproducción, así que un video de una hora
 * se ve entero con una URL de cinco minutos.
 */
export const VIDEO_URL_TTL_SECONDS = 300;

export type CloudFrontConfig = {
  domain: string;
  keyPairId: string;
  privateKey: string;
};

/**
 * La configuración, o `null` si falta algo.
 *
 * Los tres valores van juntos: con dominio pero sin llave no se puede firmar,
 * y devolver una URL sin firma daría un 403 de CloudFront que desde el cliente
 * se ve como "el video no carga".
 */
export function cloudFrontConfig(): CloudFrontConfig | null {
  const domain = env.CLOUDFRONT_DOMAIN.trim();
  const keyPairId = env.CLOUDFRONT_KEY_PAIR_ID.trim();
  const privateKey = normalizePrivateKey(env.CLOUDFRONT_PRIVATE_KEY);
  if (!domain || !keyPairId || !privateKey) return null;
  return { domain, keyPairId, privateKey };
}

/** Qué falta configurar, para poder decirlo en el 503 en vez de "no anda". */
export function missingCloudFrontVars(): string[] {
  const faltan: string[] = [];
  if (!env.CLOUDFRONT_DOMAIN.trim()) faltan.push('CLOUDFRONT_DOMAIN');
  if (!env.CLOUDFRONT_KEY_PAIR_ID.trim()) faltan.push('CLOUDFRONT_KEY_PAIR_ID');
  if (!normalizePrivateKey(env.CLOUDFRONT_PRIVATE_KEY)) {
    faltan.push('CLOUDFRONT_PRIVATE_KEY');
  }
  return faltan;
}

/**
 * Una llave privada en una variable de entorno llega casi siempre con los
 * saltos de línea escapados (`\n` literal): Secrets Manager, `.env` y la
 * consola de Lambda lo hacen todos. Sin deshacer ese escape, `createSign`
 * falla con un error de PEM que no dice nada útil.
 */
function normalizePrivateKey(raw: string): string {
  return raw.includes('\\n') ? raw.replace(/\\n/g, '\n').trim() : raw.trim();
}

/**
 * Base64 de CloudFront: el estándar usa `+`, `=` y `/`, que en una query
 * significan otra cosa. CloudFront define su propio reemplazo — no es
 * base64url, tiene su propia tabla.
 */
function toCloudFrontBase64(buffer: Buffer): string {
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/=/g, '_')
    .replace(/\//g, '~');
}

/**
 * Firma una URL de CloudFront con canned policy. **Función pura**: recibe toda
 * su configuración, así que se puede probar con un par de llaves generado en
 * la propia prueba y verificar la firma de verdad contra la pública.
 */
export function signCloudFrontUrl(
  config: CloudFrontConfig,
  input: { key: string; expiresAtEpochSeconds: number },
): string {
  // Cada segmento va codificado por separado: la key lleva barras que son
  // separadores de ruta reales, no parte del nombre.
  const path = input.key
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
  const resource = `https://${config.domain}/${path}`;

  // El JSON va EXACTAMENTE así, sin espacios: CloudFront firma y verifica la
  // cadena literal, no el objeto. Un espacio de más invalida la firma.
  const policy =
    `{"Statement":[{"Resource":"${resource}",` +
    `"Condition":{"DateLessThan":{"AWS:EpochTime":${input.expiresAtEpochSeconds}}}}]}`;

  const signature = createSign('RSA-SHA1')
    .update(policy)
    .sign(config.privateKey);

  const query = new URLSearchParams({
    Expires: String(input.expiresAtEpochSeconds),
  });
  // La firma y el id NO pasan por URLSearchParams: ya vienen codificados con
  // la tabla de CloudFront, y volver a escaparlos rompería la verificación.
  return (
    `${resource}?${query.toString()}` +
    `&Signature=${toCloudFrontBase64(signature)}` +
    `&Key-Pair-Id=${config.keyPairId}`
  );
}

/**
 * URL de reproducción para una key de video ya autorizada.
 *
 * Sin CloudFront configurado responde 503 diciendo qué variable falta, con el
 * mismo criterio que S3: es preferible a devolver una URL que el reproductor
 * va a rechazar con un error que no explica nada.
 */
export function createVideoUrl(input: { key: string }): {
  url: string;
  expiresInSeconds: number;
} {
  const config = cloudFrontConfig();
  if (!config) {
    throw new AppError(
      503,
      'cdn_not_configured',
      'La reproducción de video no está configurada en este entorno (falta ' +
        `${missingCloudFrontVars().join(', ')}).`,
      { missing: missingCloudFrontVars() },
    );
  }

  const expiresAtEpochSeconds =
    Math.floor(Date.now() / 1000) + VIDEO_URL_TTL_SECONDS;

  try {
    return {
      url: signCloudFrontUrl(config, { key: input.key, expiresAtEpochSeconds }),
      expiresInSeconds: VIDEO_URL_TTL_SECONDS,
    };
  } catch (error) {
    // Una llave mal formada es un problema de configuración del entorno, no
    // del pedido: 503 y no 500, igual que con las credenciales de S3 vencidas.
    const detail = error instanceof Error ? error.message : String(error);
    throw new AppError(
      503,
      'cdn_unavailable',
      'No pudimos preparar el video: la llave de firma de CloudFront no es ' +
        'válida. Avisá al equipo técnico.',
      { detail },
    );
  }
}
