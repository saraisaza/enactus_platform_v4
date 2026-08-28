import { createHash, randomBytes } from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';

import { env } from '../env';
import { unauthorized } from './errors';

/**
 * JWT propio con `jose`: sin dependencias transitivas, funciona igual en Node
 * y en el runtime de Lambda, y usa Web Crypto en vez de la API vieja de Node.
 *
 * El access token dura 12 h, igual que la sesión del `AuthProvider` de Flutter
 * (`sessionDuration = Duration(hours: 12)`), para que el cambio de backend no
 * cambie el comportamiento que la gente ya conoce.
 */

const secret = new TextEncoder().encode(env.JWT_SECRET);
const ISSUER = 'enactus-platform';

export interface AccessTokenClaims {
  /** Id del usuario. */
  sub: string;
  role: string;
}

export async function signAccessToken(
  claims: AccessTokenClaims,
): Promise<string> {
  return new SignJWT({ role: claims.role })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(claims.sub)
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(env.ACCESS_TOKEN_TTL)
    .sign(secret);
}

/**
 * Firma un token con una expiración explícita. Solo lo usan las pruebas, para
 * poder generar un token ya vencido sin esperar 12 horas.
 */
export async function signAccessTokenWithExpiry(
  claims: AccessTokenClaims,
  expiresAt: Date,
): Promise<string> {
  return new SignJWT({ role: claims.role })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(claims.sub)
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
    .sign(secret);
}

export async function verifyAccessToken(
  token: string,
): Promise<AccessTokenClaims> {
  try {
    const { payload } = await jwtVerify(token, secret, { issuer: ISSUER });
    const sub = payload.sub;
    const role = payload.role;
    if (typeof sub !== 'string' || typeof role !== 'string') {
      throw unauthorized('El token no tiene la forma esperada.');
    }
    return { sub, role };
  } catch (error) {
    if (error instanceof Error && error.name === 'JWTExpired') {
      throw unauthorized('La sesión expiró. Iniciá sesión de nuevo.');
    }
    throw unauthorized('Token inválido.');
  }
}

/**
 * Refresh token: 256 bits aleatorios. En la base se guarda solo su SHA-256,
 * así que filtrar la tabla `refresh_tokens` no permite iniciar sesión con
 * ella — el valor original solo lo tiene el cliente.
 */
export function generateRefreshToken(): { token: string; hash: string } {
  const token = randomBytes(32).toString('base64url');
  return { token, hash: hashRefreshToken(token) };
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Convierte '30d' / '12h' / '45m' a milisegundos. */
export function ttlToMs(ttl: string): number {
  const match = /^(\d+)([smhd])$/.exec(ttl);
  if (!match) throw new Error(`TTL inválido: ${ttl}`);
  const value = Number(match[1]);
  const unit = match[2];
  const factor =
    unit === 's' ? 1_000 : unit === 'm' ? 60_000 : unit === 'h' ? 3_600_000 : 86_400_000;
  return value * factor;
}
