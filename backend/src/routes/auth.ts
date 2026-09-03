import { and, eq, isNull, sql as raw } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import type { Database } from '../db/client';
import { refreshTokens, users } from '../db/schema';
import { publicUser } from '../lib/dto';
import { badRequest, tooManyRequests, unauthorized } from '../lib/errors';
import {
  generateRefreshToken,
  hashRefreshToken,
  signAccessToken,
  ttlToMs,
} from '../lib/jwt';
import { verifyPassword } from '../lib/password';
import { requireAuth, currentUser } from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';
import {
  anotarIntento,
  esperaPendiente,
  olvidarIntentos,
  rateLimit,
} from '../middleware/rate-limit';
import { env } from '../env';

const loginSchema = z.object({
  email: z.string().trim().min(1, 'El correo es obligatorio.'),
  password: z.string().min(1, 'La contraseña es obligatoria.'),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Falta el refresh token.'),
});

export const authRoutes = new Hono<AppEnv>();

/**
 * Límite de intentos de login: 10 por IP+correo cada 5 minutos.
 *
 * Se agrupa por IP **y** correo para que un atacante que prueba contraseñas
 * contra una cuenta conocida se frene, sin bloquear a toda una universidad
 * que sale por la misma IP.
 *
 * Este es el PRIMER candado y por sí solo no alcanza: vale lo que valga la
 * IP, y la IP vale lo que valga la configuración de `TRUSTED_PROXY_HOPS`. Si
 * ese número queda mal puesto el día del despliegue, este límite se vuelve
 * decorativo sin que nadie se entere. El segundo candado, abajo, no depende
 * de la IP.
 */
authRoutes.use(
  '/login',
  rateLimit({
    max: 10,
    windowMs: 5 * 60 * 1000,
    keyOf: (c, body) => {
      const email =
        typeof body === 'object' && body !== null && 'email' in body
          ? String(body.email).toLowerCase()
          : '';
      return `login:${c.get('requestIp')}:${email}`;
    },
  }),
);

/**
 * Segundo candado: intentos FALLIDOS por correo, sin mirar la IP.
 *
 * 20 fallos cada 15 minutos. Un atacante que rota IPs —falsificando la
 * cabecera o alquilando proxies, que es barato— pasa por encima del límite de
 * arriba sin despeinarse; este lo frena igual, porque la cuenta atacada es la
 * misma y esa no la puede rotar.
 *
 * Dos decisiones que lo hacen usable y no un candado contra los propios
 * usuarios:
 *
 * - **Solo cuenta lo que falla.** Quien sabe su contraseña nunca suma al
 *   contador, por más gente que haya intentando entrar a esa cuenta.
 * - **Entrar bien lo borra.** El dueño de la cuenta la reabre para sí mismo.
 *
 * Queda un costo que hay que decir en voz alta: alguien puede quemarle los 20
 * fallos a una cuenta conocida y dejar a esa persona sin entrar por 15
 * minutos. Es un bloqueo dirigido y molesto, pero acotado en el tiempo y sin
 * pérdida de datos — al lado de "fuerza bruta ilimitada contra el admin", que
 * es lo que había, se elige este.
 */
const MAX_FALLOS_POR_CORREO = 20;
const VENTANA_FALLOS_MS = 15 * 60 * 1000;
const claveFallos = (email: string) => `login-fallos:${email.trim().toLowerCase()}`;

authRoutes.post('/login', async (c) => {
  const { email, password } = loginSchema.parse(await c.req.json());
  const db = c.get('db');

  const clave = claveFallos(email);
  const espera = esperaPendiente(clave, MAX_FALLOS_POR_CORREO, VENTANA_FALLOS_MS);
  if (espera !== null) {
    throw tooManyRequests(
      'Demasiados intentos fallidos contra esta cuenta. Espere unos minutos.',
      { retryAfterSeconds: espera },
    );
  }

  const [user] = await db
    .select()
    .from(users)
    .where(
      and(
        raw`lower(${users.email}) = lower(${email})`,
        isNull(users.deletedAt),
      ),
    )
    .limit(1);

  // Mismo mensaje exista o no la cuenta: si dijéramos "ese correo no existe"
  // estaríamos regalando un enumerador de usuarios.
  const invalid = unauthorized('Correo o contraseña incorrectos.');
  if (!user) {
    // Se compara igual contra un hash falso para que el tiempo de respuesta
    // no delate si la cuenta existe.
    await verifyPassword(password, '$2b$10$invalidinvalidinvalidinvalidinvalidinvalidinvalidinvalidi');
    // Se anota aunque la cuenta no exista: si solo contáramos los fallos
    // contra cuentas reales, la diferencia entre "se frenó" y "no se frenó"
    // sería un enumerador de usuarios tan bueno como el mensaje distinto que
    // ya evitamos arriba.
    anotarIntento(clave, VENTANA_FALLOS_MS);
    throw invalid;
  }
  if (!(await verifyPassword(password, user.passwordHash))) {
    anotarIntento(clave, VENTANA_FALLOS_MS);
    throw invalid;
  }

  // Entró bien: el contador de fallos de esta cuenta se borra.
  olvidarIntentos(clave);

  const tokens = await issueTokens(db, c.get('requestIp'), user.id, user.role);
  // Campos explícitos: `tokens` trae además `refreshTokenId`, que es interno
  // y no tiene por qué salir en la respuesta.
  //
  // El usuario va con la MISMA forma que `/auth/me` —equipo y patrocinador
  // incluidos— y no con `publicUser` a secas: si no, recién entrada la
  // persona a su portal, el perfil se vería sin equipo ni proyecto hasta que
  // algo volviera a pedir `/auth/me`.
  return c.json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresIn: tokens.expiresIn,
    user: await meResponse(db, user),
  });
});

/**
 * Refresh con rotación: el token usado se marca como reemplazado y se emite
 * uno nuevo. Si llega un token YA revocado, es señal de que alguien está
 * reusando uno robado, así que se revoca la cadena entera del usuario y hay
 * que volver a iniciar sesión.
 */
authRoutes.post('/refresh', async (c) => {
  const { refreshToken } = refreshSchema.parse(await c.req.json());
  const db = c.get('db');
  const hash = hashRefreshToken(refreshToken);

  const [stored] = await db
    .select()
    .from(refreshTokens)
    .where(eq(refreshTokens.tokenHash, hash))
    .limit(1);

  if (!stored) throw unauthorized('Refresh token inválido.');

  if (stored.revokedAt) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date(), updatedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.userId, stored.userId),
          isNull(refreshTokens.revokedAt),
        ),
      );
    throw unauthorized(
      'Ese refresh token ya se había usado. Por seguridad se cerraron todas las sesiones.',
    );
  }

  if (stored.expiresAt.getTime() <= Date.now()) {
    throw unauthorized('El refresh token expiró. Inicie sesión de nuevo.');
  }

  const [user] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, stored.userId), isNull(users.deletedAt)))
    .limit(1);
  if (!user) throw unauthorized('La cuenta ya no existe.');

  const tokens = await issueTokens(db, c.get('requestIp'), user.id, user.role);
  await db
    .update(refreshTokens)
    .set({
      revokedAt: new Date(),
      replacedBy: tokens.refreshTokenId,
      updatedAt: new Date(),
    })
    .where(eq(refreshTokens.id, stored.id));

  // Misma forma que en el login: renovar la sesión no puede devolver un
  // usuario más pobre que el que ya tenía el cliente.
  return c.json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresIn: tokens.expiresIn,
    user: await meResponse(db, user),
  });
});

authRoutes.post('/logout', async (c) => {
  const parsed = refreshSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) throw badRequest('Falta el refresh token.');
  const db = c.get('db');
  await db
    .update(refreshTokens)
    .set({ revokedAt: new Date(), updatedAt: new Date() })
    .where(
      and(
        eq(refreshTokens.tokenHash, hashRefreshToken(parsed.data.refreshToken)),
        isNull(refreshTokens.revokedAt),
      ),
    );
  // Siempre 204, exista o no el token: cerrar sesión nunca falla.
  return c.body(null, 204);
});

/**
 * Usuario de la sesión.
 *
 * Para estudiantes y alumni incluye dos cosas que solo la propia persona
 * puede ver de sí misma:
 *
 * - `team`: `groupId`, `projectId` y el rol dentro del proyecto. Antes eso
 *   salía de `AppUser.extra['groupId']`, una denormalización de Hive; ahora es
 *   un JOIN y viene con el propio usuario, así la pantalla no tiene que
 *   adivinar a qué equipo pertenece quien mira.
 * - `sponsorName`: el nombre de la empresa que lo patrocina. `companyId` por sí
 *   solo no sirve para mostrarlo, y no existe —ni debería— un endpoint que le
 *   permita a un estudiante leer el perfil de otra cuenta para resolverlo.
 */
authRoutes.get('/me', requireAuth, async (c) => {
  return c.json(await meResponse(c.get('db'), currentUser(c)));
});

/**
 * El cuerpo de `/auth/me`, compartido por GET y PATCH.
 *
 * PATCH devuelve exactamente la misma forma a propósito: si devolviera solo
 * `publicUser`, guardar el teléfono borraría el equipo del modelo en el
 * cliente y la pantalla de perfil se quedaría sin proyecto hasta recargar.
 */
async function meResponse(db: Database, user: AuthUser) {
  const base = publicUser(user);
  if (user.role !== 'student' && user.role !== 'alumni') return base;

  const [team] = await db.execute<{
    groupId: string;
    groupName: string;
    projectId: string;
    projectName: string;
    roleInProject: string;
  }>(raw`
    select g.id as "groupId", g.name as "groupName",
           pr.id as "projectId", pr.name as "projectName",
           gm.role_in_project as "roleInProject"
      from group_members gm
      join groups g on g.id = gm.group_id and g.deleted_at is null
      join projects pr on pr.id = g.project_id and pr.deleted_at is null
     where gm.user_id = ${user.id}
     limit 1
  `);

  let sponsorName: string | null = null;
  if (user.companyId) {
    const [sponsor] = await db
      .select({ name: users.companyName })
      .from(users)
      .where(and(eq(users.id, user.companyId), isNull(users.deletedAt)))
      .limit(1);
    sponsorName = sponsor?.name || null;
  }

  return { ...base, team: team ?? null, sponsorName };
}

const profileSchema = z.object({
  name: z.string().trim().min(1, 'El nombre es obligatorio.').optional(),
  phone: z.string().trim().optional(),
  cedula: z.string().trim().optional(),
  city: z.string().trim().optional(),
  career: z.string().trim().optional(),
  profile: z.record(z.string(), z.unknown()).optional(),
  // Solo una key bajo `avatars/`, que es donde `POST /files/upload-url` deja
  // los avatares. Sin esta restricción alguien podría apuntar su foto de
  // perfil a la key de una entrega ajena y leerla desde el visor de avatares.
  avatarS3Key: z
    .string()
    .trim()
    .regex(/^avatars\//, 'La foto de perfil debe venir de una subida de avatar.')
    .nullable()
    .optional(),
});

/**
 * Editar el PROPIO perfil.
 *
 * Deliberadamente acotado: no acepta `role`, `studentType`, `university`,
 * `canGrade*` ni las relaciones. Esos los cambia un administrador — si
 * estuvieran acá, cualquiera podría ascenderse mandando un campo de más.
 */
authRoutes.patch('/me', requireAuth, async (c) => {
  const user = currentUser(c);
  const body = profileSchema.parse(await c.req.json());
  const db = c.get('db');

  const [updated] = await db
    .update(users)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(users.id, user.id))
    .returning();

  return c.json(await meResponse(db, updated!));
});

/** Emite el par de tokens y guarda el refresh hasheado. */
async function issueTokens(db: Database, ip: string, userId: string, role: string) {
  const accessToken = await signAccessToken({ sub: userId, role });
  const { token, hash } = generateRefreshToken();
  const expiresAt = new Date(Date.now() + ttlToMs(env.REFRESH_TOKEN_TTL));

  const [row] = await db
    .insert(refreshTokens)
    .values({ userId, tokenHash: hash, expiresAt, ip })
    .returning({ id: refreshTokens.id });

  return {
    accessToken,
    refreshToken: token,
    refreshTokenId: row?.id ?? null,
    expiresIn: Math.floor(ttlToMs(env.ACCESS_TOKEN_TTL) / 1000),
  };
}
