import { and, eq, isNull } from 'drizzle-orm';
import { createMiddleware } from 'hono/factory';

import { users } from '../db/schema';
import { forbidden, unauthorized } from '../lib/errors';
import { verifyAccessToken } from '../lib/jwt';
import type { AppEnv, AuthUser } from './context';

/**
 * Exige sesión activa.
 *
 * Verifica la firma del JWT **y además carga el usuario de la base**. Esa
 * segunda consulta no es redundante: el access token dura 12 horas, así que
 * sin ella una cuenta eliminada, o alguien a quien le acaban de quitar
 * `can_grade`, seguiría teniendo acceso hasta que el token venciera. Los
 * permisos se leen del registro vivo, nunca del claim.
 */
export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const header = c.req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) throw unauthorized('Falta el encabezado Authorization.');

  const claims = await verifyAccessToken(token);
  const db = c.get('db');
  const [user] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, claims.sub), isNull(users.deletedAt)))
    .limit(1);

  if (!user) throw unauthorized('La cuenta ya no existe o fue desactivada.');

  c.set('user', user);
  await next();
});

/** El usuario autenticado. Solo se llama detrás de `requireAuth`. */
export function currentUser(c: { get: (k: 'user') => AuthUser | undefined }): AuthUser {
  const user = c.get('user');
  if (!user) {
    // No es un error de la persona: es un error de montaje de la ruta.
    throw new Error('requireRole/currentUser usados sin requireAuth delante.');
  }
  return user;
}

/** Restringe una ruta a ciertos roles. */
export const requireRole = (...roles: AuthUser['role'][]) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const user = currentUser(c);
    if (!roles.includes(user.role)) {
      throw forbidden(
        `Esta acción es para: ${roles.join(', ')}. Su rol es ${user.role}.`,
      );
    }
    await next();
  });

/** Roles con permiso de crear y editar contenido formativo. */
export const CONTENT_ROLES = ['lxd', 'admin', 'superadmin'] as const;

/** Roles que administran la plataforma. */
export const ADMIN_ROLES = ['admin', 'superadmin'] as const;

/** Roles con acceso de estudiante (un alumni es idéntico a un estudiante). */
export const STUDENT_ROLES = ['student', 'alumni'] as const;

export const isStudentLike = (role: string): boolean =>
  role === 'student' || role === 'alumni';

/**
 * Exige permiso de calificar en el contexto correspondiente.
 *
 * Hoy en Flutter esto es solo un filtro de interfaz: `_LxdGrading` esconde las
 * entregas y `_LxdCertificates` esconde el formulario, pero `saveSubmission` e
 * `issueRutaCertificate` no verifican nada. Acá se verifica de verdad, contra
 * el registro vivo del usuario.
 *
 * Son dos permisos, no uno (decisión confirmada en la Fase 0): en Open
 * Learning el LXD es el docente y califica por defecto; en Enactus la
 * calificación es un acto institucional que el Admin habilita caso por caso.
 *
 * Admin y superadmin califican sin pasar por el permiso: es el caso de escape
 * cuando un LXD deja la organización. Queda en `audit_log`.
 */
export function assertCanGrade(user: AuthUser, isOpenLearning: boolean): void {
  if (user.role === 'admin' || user.role === 'superadmin') return;
  if (user.role !== 'lxd') {
    throw forbidden('Solo un LXD (o un administrador) puede calificar.');
  }
  const allowed = isOpenLearning
    ? user.canGradeOpenLearning
    : user.canGradeEnactus;
  if (!allowed) {
    throw forbidden(
      isOpenLearning
        ? 'Su Admin no le dio permiso de calificar en Open Learning.'
        : 'Su Admin no le dio permiso de calificar en eduXaction.',
    );
  }
}

/**
 * Middleware de calificación para rutas que no dependen del contexto del
 * curso. Cuando el contexto importa (Open Learning vs Enactus) se usa
 * `assertCanGrade` dentro del handler, ya sabiendo de qué curso se trata.
 */
export const requireCanGrade = createMiddleware<AppEnv>(async (c, next) => {
  const user = currentUser(c);
  if (
    user.role !== 'lxd' &&
    user.role !== 'admin' &&
    user.role !== 'superadmin'
  ) {
    throw forbidden('Solo un LXD (o un administrador) puede calificar.');
  }
  if (
    user.role === 'lxd' &&
    !user.canGradeOpenLearning &&
    !user.canGradeEnactus
  ) {
    throw forbidden('Su Admin no le dio permiso de calificar.');
  }
  await next();
});

/**
 * Un estudiante solo puede tocar lo suyo. El resto de los roles pasa según la
 * lista que se le indique.
 *
 * Es la defensa que hoy no existe: `DataProvider.users`, `.submissions` y
 * `.progress` no filtran por nadie, y las pantallas se cuidan por convención.
 */
export function assertSelfOr(
  user: AuthUser,
  targetUserId: string,
  allowedRoles: readonly string[],
): void {
  if (user.id === targetUserId) return;
  if (allowedRoles.includes(user.role)) return;
  throw forbidden('Solo puede ver o modificar sus propios datos.');
}

/**
 * Bloquea a los estudiantes de Open Learning en todo lo que es exclusivo de
 * Enactus: laboratorios, fases, Ruta de Impacto, proyectos, grupos, foro.
 *
 * Devuelve 403, nunca una respuesta vacía: una respuesta vacía haría ver un
 * bug de permisos como si fuera "no hay datos".
 *
 * El tipo de estudiante sale SIEMPRE del registro del usuario, nunca de un
 * parámetro de la petición.
 */
export const requireEnactus = createMiddleware<AppEnv>(async (c, next) => {
  const user = currentUser(c);
  if (isStudentLike(user.role) && user.studentType === 'open_learning') {
    throw forbidden(
      'Su cuenta es de Open Learning: no incluye laboratorios ni Ruta de Impacto.',
    );
  }
  await next();
});
