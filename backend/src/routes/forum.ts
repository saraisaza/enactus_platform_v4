import { and, asc, eq, inArray, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  auditLog,
  forumLikes,
  forumPosts,
  forumReplies,
  forumReports,
  notifications,
  userBlocks,
  users,
} from '../db/schema';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import {
  MENSAJE_LENGUAJE_NO_PERMITIDO,
  tieneLenguajeNoPermitido,
} from '../lib/moderacion';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  ADMIN_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * Foro de la comunidad: el único espacio que NO está aislado por laboratorio,
 * universidad ni empresa.
 *
 * Lo comparten Admin, Super Admin, Asesores y estudiantes/alumni **Enactus**.
 * Los de Open Learning no participan — no son parte de la comunidad Enactus.
 * Es la regla de `DataProvider.canAccessForum`, ahora del lado del servidor.
 */
export const forumRoutes = new Hono<AppEnv>();
forumRoutes.use('*', requireAuth);

function assertForumAccess(user: AuthUser): void {
  if (isStudentLike(user.role)) {
    if (user.studentType === 'enactus') return;
    throw forbidden(
      'El foro es de la comunidad Enactus: su cuenta es de Open Learning.',
    );
  }
  if (user.role === 'admin' || user.role === 'superadmin' || user.role === 'advisor') {
    return;
  }
  throw forbidden('Su rol no tiene acceso al foro.');
}

forumRoutes.use('*', async (c, next) => {
  assertForumAccess(currentUser(c));
  await next();
});

const postBody = z.object({
  body: z.string().trim().min(1, 'La publicación no puede estar vacía.'),
  category: z
    .enum(['question', 'progress', 'resource', 'announcement'])
    .default('question'),
});

const replyBody = z.object({
  body: z.string().trim().min(1, 'La respuesta no puede estar vacía.'),
});

const isModerator = (role: string) => role === 'admin' || role === 'superadmin';

/**
 * Lo que alguien publica pasa antes por el filtro de lenguaje (App Store, guía
 * 1.2: filtrar lo ofensivo ANTES de que se publique). Ver `lib/moderacion.ts`.
 */
function assertLenguajePermitido(texto: string): void {
  if (tieneLenguajeNoPermitido(texto)) {
    throw badRequest(MENSAJE_LENGUAJE_NO_PERMITIDO);
  }
}

/**
 * Condición «el autor no está bloqueado por quien mira», para las consultas
 * crudas con alias. Quien bloquea deja de ver lo que publica y responde la otra
 * persona; para el resto del foro no cambia nada.
 */
const noBloqueado = (quienMira: string, autor: ReturnType<typeof sql>) =>
  sql`not exists (select 1 from user_blocks b
                   where b.blocker_id = ${quienMira} and b.blocked_id = ${autor})`;

forumRoutes.get('/', async (c) => {
  const query = paginationSchema
    .extend({ category: z.string().optional() })
    .parse(c.req.query());
  const db = c.get('db');
  const user = currentUser(c);

  // OJO: esta consulta usa el alias `p`, así que la condición NO puede venir
  // de un helper de Drizzle (`isNull(forumPosts.deletedAt)` genera
  // `"forum_posts"."deleted_at"`, que no resuelve contra el alias). Se escribe
  // con el alias a mano, y el `count` de abajo usa la versión de Drizzle
  // porque ahí sí consulta la tabla sin alias.
  const categoria = query.category;
  const filtroCrudo = categoria
    ? sql`p.deleted_at is null and p.category::text = ${categoria}
          and ${noBloqueado(user.id, sql`p.author_id`)}`
    : sql`p.deleted_at is null and ${noBloqueado(user.id, sql`p.author_id`)}`;

  const filters = [
    isNull(forumPosts.deletedAt),
    noBloqueado(user.id, sql`${forumPosts.authorId}`),
  ];
  if (categoria) {
    filters.push(sql`${forumPosts.category}::text = ${categoria}`);
  }
  const where = and(...filters);

  const rows = await db.execute<{
    id: string;
    authorId: string;
    authorName: string;
    authorRole: string;
    body: string;
    category: string;
    pinned: boolean;
    createdAt: string;
    replyCount: number;
    likeCount: number;
    likedByMe: boolean;
  }>(sql`
    select p.id, p.author_id as "authorId", u.name as "authorName", u.role::text as "authorRole", p.body,
           p.category::text as category, p.pinned, p.created_at as "createdAt",
           (select count(*)::int from forum_replies r
             where r.post_id = p.id and r.deleted_at is null
               and ${noBloqueado(user.id, sql`r.author_id`)}) as "replyCount",
           (select count(*)::int from forum_likes l where l.post_id = p.id) as "likeCount",
           exists (select 1 from forum_likes l
                    where l.post_id = p.id and l.user_id = ${user.id}) as "likedByMe"
      from forum_posts p
      join users u on u.id = p.author_id
     where ${filtroCrudo}
     order by p.pinned desc, p.created_at desc
     limit ${query.pageSize} offset ${(query.page - 1) * query.pageSize}
  `);

  const [total] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(forumPosts)
    .where(where);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

/**
 * Cifras del encabezado del foro.
 *
 * Eran agregados del cliente: recorrían TODAS las publicaciones y TODOS los
 * usuarios en memoria. Contra la API eso ni se puede pedir, y además son dos
 * consultas de agregación que Postgres resuelve mejor.
 */
forumRoutes.get('/stats', async (c) => {
  const db = c.get('db');

  const [activos] = await db.execute<{ count: number }>(sql`
    select count(distinct p.author_id)::int as count
      from forum_posts p
     where p.deleted_at is null
       and p.created_at > now() - interval '7 days'
  `);

  // Equipos con más publicaciones, resuelto desde el grupo real de cada
  // autor. Solo cuenta autores con equipo: LXD, Mentor y Asesor no tienen.
  const equipos = await db.execute<{
    groupId: string;
    groupName: string;
    count: number;
  }>(sql`
    select g.id as "groupId", g.name as "groupName", count(*)::int as count
      from forum_posts p
      join group_members gm on gm.user_id = p.author_id
      join groups g on g.id = gm.group_id
     where p.deleted_at is null and g.deleted_at is null
     group by g.id, g.name
     order by count desc, g.name
     limit 3
  `);

  return c.json({
    activeUsersThisWeek: activos?.count ?? 0,
    mostActiveTeams: equipos,
  });
});

// ---------------------------------------------------------------------------
// Bloqueos y reportes (App Store, guía 1.2)
//
// Van ANTES de `/:id`: si no, «blocks» y «reports» se tomarían por un id.
// ---------------------------------------------------------------------------

/** A quién bloqueó la persona de la sesión, para poder desbloquear. */
forumRoutes.get('/blocks', async (c) => {
  const user = currentUser(c);
  const filas = await c
    .get('db')
    .select({
      userId: userBlocks.blockedId,
      name: users.name,
      createdAt: userBlocks.createdAt,
    })
    .from(userBlocks)
    .innerJoin(users, eq(users.id, userBlocks.blockedId))
    .where(eq(userBlocks.blockerId, user.id))
    .orderBy(asc(users.name));
  return c.json({ data: filas });
});

const blockBody = z.object({ userId: z.uuid() });

/**
 * Bloquear a alguien: deja de ver lo que publica y responde. La otra persona no
 * se entera ni pierde nada. Bloquear dos veces no es un error.
 *
 * Al equipo que modera no se le puede bloquear: sus anuncios son del foro
 * entero, y lo que publique se puede reportar como lo de cualquiera.
 */
forumRoutes.post('/blocks', async (c) => {
  const user = currentUser(c);
  const { userId } = blockBody.parse(await c.req.json());
  if (userId === user.id) throw badRequest('No puede bloquearse a sí mismo.');

  const db = c.get('db');
  const [otra] = await db
    .select({ id: users.id, role: users.role })
    .from(users)
    .where(and(eq(users.id, userId), isNull(users.deletedAt)))
    .limit(1);
  if (!otra) throw notFound('No encontramos esa persona.');
  if (isModerator(otra.role)) {
    throw conflict(
      'No se puede bloquear al equipo que modera el foro. Si algo de lo que ' +
        'publicó le parece inadecuado, repórtelo.',
    );
  }

  await db
    .insert(userBlocks)
    .values({ blockerId: user.id, blockedId: userId })
    .onConflictDoNothing();
  return c.json({ userId, blocked: true }, 201);
});

forumRoutes.delete('/blocks/:userId', async (c) => {
  const user = currentUser(c);
  await c
    .get('db')
    .delete(userBlocks)
    .where(
      and(
        eq(userBlocks.blockerId, user.id),
        eq(userBlocks.blockedId, c.req.param('userId')),
      ),
    );
  return c.body(null, 204);
});

/**
 * La cola de moderación: los reportes sin atender, del más antiguo al más
 * reciente, con el texto reportado a la vista para decidir sin ir a buscarlo.
 */
forumRoutes.get('/reports', requireRole(...ADMIN_ROLES), async (c) => {
  const filas = await c.get('db').execute<{
    id: string;
    postId: string;
    replyId: string | null;
    reason: string;
    createdAt: string;
    reporterName: string;
    body: string;
    authorId: string;
    authorName: string;
    contentRemoved: boolean;
  }>(sql`
    select fr.id, fr.post_id as "postId", fr.reply_id as "replyId", fr.reason,
           fr.created_at as "createdAt", quien.name as "reporterName",
           coalesce(r.body, p.body) as body,
           coalesce(r.author_id, p.author_id) as "authorId",
           autor.name as "authorName",
           (p.deleted_at is not null or r.deleted_at is not null) as "contentRemoved"
      from forum_reports fr
      join forum_posts p on p.id = fr.post_id
      left join forum_replies r on r.id = fr.reply_id
      join users quien on quien.id = fr.reporter_id
      join users autor on autor.id = coalesce(r.author_id, p.author_id)
     where fr.resolved_at is null
     order by fr.created_at
  `);
  return c.json({ data: filas });
});

const resolveBody = z.object({ action: z.enum(['remove', 'dismiss']) });

/**
 * Atender un reporte: quitar el contenido (`remove`) o dejarlo (`dismiss`).
 *
 * La decisión es sobre el CONTENIDO, no sobre un reporte suelto: cierra todos
 * los pendientes de lo mismo, para que tres personas que reportaron lo mismo
 * no dejen tres tareas. Quitar una publicación cierra también los reportes de
 * sus respuestas, que dejaron de verse con ella.
 */
forumRoutes.post(
  '/reports/:reportId/resolve',
  requireRole(...ADMIN_ROLES),
  async (c) => {
    const admin = currentUser(c);
    const { action } = resolveBody.parse(await c.req.json());
    const db = c.get('db');
    const [reporte] = await db
      .select()
      .from(forumReports)
      .where(eq(forumReports.id, c.req.param('reportId')))
      .limit(1);
    if (!reporte) throw notFound('No se encontró el reporte.');
    if (reporte.resolvedAt) throw conflict('Ese reporte ya fue atendido.');

    const ahora = new Date();
    const resolution = action === 'remove' ? 'removed' : 'dismissed';
    const mismoContenido = reporte.replyId
      ? eq(forumReports.replyId, reporte.replyId)
      : action === 'remove'
        ? undefined
        : isNull(forumReports.replyId);

    await db.transaction(async (tx) => {
      if (action === 'remove') {
        if (reporte.replyId) {
          await tx
            .update(forumReplies)
            .set({ deletedAt: ahora, updatedAt: ahora })
            .where(
              and(eq(forumReplies.id, reporte.replyId), isNull(forumReplies.deletedAt)),
            );
        } else {
          await tx
            .update(forumPosts)
            .set({ deletedAt: ahora, updatedAt: ahora })
            .where(and(eq(forumPosts.id, reporte.postId), isNull(forumPosts.deletedAt)));
        }
      }
      await tx
        .update(forumReports)
        .set({ resolution, resolvedBy: admin.id, resolvedAt: ahora, updatedAt: ahora })
        .where(
          and(
            eq(forumReports.postId, reporte.postId),
            mismoContenido,
            isNull(forumReports.resolvedAt),
          ),
        );
      await tx.insert(auditLog).values({
        actorId: admin.id,
        action: action === 'remove' ? 'forum.content_removed' : 'forum.report_dismissed',
        entityType: reporte.replyId ? 'forum_reply' : 'forum_post',
        entityId: reporte.replyId ?? reporte.postId,
        newValue: { reportId: reporte.id, reason: reporte.reason },
        ip: c.get('requestIp'),
      });
    });

    return c.json({ id: reporte.id, resolution });
  },
);

forumRoutes.get('/:id', async (c) => {
  const db = c.get('db');
  const user = currentUser(c);
  const [post] = await db
    .select()
    .from(forumPosts)
    .where(
      and(
        eq(forumPosts.id, c.req.param('id')),
        isNull(forumPosts.deletedAt),
        noBloqueado(user.id, sql`${forumPosts.authorId}`),
      ),
    )
    .limit(1);
  if (!post) throw notFound('No se encontró la publicación.');

  const replies = await db.execute<{
    id: string;
    authorId: string;
    authorName: string;
    authorRole: string;
    body: string;
    createdAt: string;
  }>(sql`
    select r.id, r.author_id as "authorId", u.name as "authorName",
           u.role::text as "authorRole", r.body, r.created_at as "createdAt"
      from forum_replies r
      join users u on u.id = r.author_id
     where r.post_id = ${post.id} and r.deleted_at is null
       and ${noBloqueado(user.id, sql`r.author_id`)}
     order by r.created_at
  `);

  return c.json({ ...post, replies });
});

forumRoutes.post('/', async (c) => {
  const user = currentUser(c);
  const body = postBody.parse(await c.req.json());
  assertLenguajePermitido(body.body);
  const [created] = await c
    .get('db')
    .insert(forumPosts)
    .values({ ...body, authorId: user.id })
    .returning();
  return c.json(created, 201);
});

forumRoutes.post('/:id/replies', async (c) => {
  const user = currentUser(c);
  const { body } = replyBody.parse(await c.req.json());
  assertLenguajePermitido(body);
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));

  const [created] = await db
    .insert(forumReplies)
    .values({ postId: post.id, authorId: user.id, body })
    .returning();
  return c.json(created, 201);
});

/**
 * Un apoyo por persona por publicación.
 *
 * Con la tabla `forum_likes` esto es un INSERT o un DELETE. Hoy en Flutter es
 * leer-modificar-escribir el post entero (`ForumPost.likedBy`), que con dos
 * personas dando like a la vez pierde uno de los dos.
 */
forumRoutes.post('/:id/like', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));

  const existing = await db
    .select()
    .from(forumLikes)
    .where(and(eq(forumLikes.postId, post.id), eq(forumLikes.userId, user.id)))
    .limit(1);

  if (existing.length > 0) {
    await db
      .delete(forumLikes)
      .where(and(eq(forumLikes.postId, post.id), eq(forumLikes.userId, user.id)));
  } else {
    await db.insert(forumLikes).values({ postId: post.id, userId: user.id });
  }

  const [count] = await db
    .select({ value: sql<number>`count(*)::int` })
    .from(forumLikes)
    .where(eq(forumLikes.postId, post.id));

  return c.json({ liked: existing.length === 0, likeCount: count?.value ?? 0 });
});

const reportBody = z.object({
  /** Sin `replyId` se reporta la publicación; con él, esa respuesta. */
  replyId: z.uuid().optional(),
  reason: z.string().trim().max(500).default(''),
});

/**
 * Reportar una publicación o una respuesta (App Store, guía 1.2).
 *
 * Reportar dos veces lo mismo no suma ni falla: responde 200 en vez de 201. Al
 * equipo que modera le llega una notificación, porque la guía no pide solo
 * recibir reportes sino atenderlos a tiempo.
 */
forumRoutes.post('/:id/report', async (c) => {
  const user = currentUser(c);
  const { replyId, reason } = reportBody.parse(await c.req.json());
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));

  let autorId = post.authorId;
  if (replyId) {
    const [reply] = await db
      .select({ authorId: forumReplies.authorId })
      .from(forumReplies)
      .where(
        and(
          eq(forumReplies.id, replyId),
          eq(forumReplies.postId, post.id),
          isNull(forumReplies.deletedAt),
        ),
      )
      .limit(1);
    if (!reply) throw notFound('No se encontró la respuesta.');
    autorId = reply.authorId;
  }
  if (autorId === user.id) {
    throw badRequest('No puede reportar lo que usted mismo publicó; puede borrarlo.');
  }

  const [creado] = await db
    .insert(forumReports)
    .values({ postId: post.id, replyId: replyId ?? null, reporterId: user.id, reason })
    .onConflictDoNothing()
    .returning({ id: forumReports.id });
  if (!creado) return c.json({ reported: true, duplicate: true });

  const moderadores = await db
    .select({ id: users.id })
    .from(users)
    .where(and(inArray(users.role, [...ADMIN_ROLES]), isNull(users.deletedAt)));
  if (moderadores.length > 0) {
    await db.insert(notifications).values(
      moderadores.map((m) => ({
        userId: m.id,
        title: 'Nuevo reporte en el foro',
        body: 'Alguien reportó contenido del foro. Revíselo en Foro › Reportes.',
      })),
    );
  }
  return c.json({ reported: true, duplicate: false }, 201);
});

/** El autor borra su respuesta; Admin y Super Admin, cualquiera. */
forumRoutes.delete('/:id/replies/:replyId', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));
  const [reply] = await db
    .select({ id: forumReplies.id, authorId: forumReplies.authorId })
    .from(forumReplies)
    .where(
      and(
        eq(forumReplies.id, c.req.param('replyId')),
        eq(forumReplies.postId, post.id),
        isNull(forumReplies.deletedAt),
      ),
    )
    .limit(1);
  if (!reply) throw notFound('No se encontró la respuesta.');
  if (reply.authorId !== user.id && !isModerator(user.role)) {
    throw forbidden('Solo puede borrar sus propias respuestas.');
  }
  const ahora = new Date();
  await db
    .update(forumReplies)
    .set({ deletedAt: ahora, updatedAt: ahora })
    .where(eq(forumReplies.id, reply.id));
  return c.body(null, 204);
});

/** Fijar es moderación: solo Admin y Super Admin. */
forumRoutes.post('/:id/pin', async (c) => {
  const user = currentUser(c);
  if (!isModerator(user.role)) {
    throw forbidden('Solo un administrador puede fijar publicaciones.');
  }
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));
  const [updated] = await db
    .update(forumPosts)
    .set({ pinned: !post.pinned, updatedAt: new Date() })
    .where(eq(forumPosts.id, post.id))
    .returning();
  return c.json(updated);
});

/** El autor borra lo suyo; Admin y Super Admin, cualquiera. */
forumRoutes.delete('/:id', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const post = await loadPost(db, c.req.param('id'));
  if (post.authorId !== user.id && !isModerator(user.role)) {
    throw forbidden('Solo puede borrar sus propias publicaciones.');
  }
  await db
    .update(forumPosts)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(forumPosts.id, post.id));
  return c.body(null, 204);
});

async function loadPost(db: AppEnv['Variables']['db'], id: string) {
  const [row] = await db
    .select()
    .from(forumPosts)
    .where(and(eq(forumPosts.id, id), isNull(forumPosts.deletedAt)))
    .limit(1);
  if (!row) throw notFound('No se encontró la publicación.');
  return row;
}
