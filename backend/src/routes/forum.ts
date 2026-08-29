import { and, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { forumLikes, forumPosts, forumReplies } from '../db/schema';
import { forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import { currentUser, isStudentLike, requireAuth } from '../middleware/auth';
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
      'El foro es de la comunidad Enactus: tu cuenta es de Open Learning.',
    );
  }
  if (user.role === 'admin' || user.role === 'superadmin' || user.role === 'advisor') {
    return;
  }
  throw forbidden('Tu rol no tiene acceso al foro.');
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
    ? sql`p.deleted_at is null and p.category::text = ${categoria}`
    : sql`p.deleted_at is null`;

  const filters = [isNull(forumPosts.deletedAt)];
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
             where r.post_id = p.id and r.deleted_at is null) as "replyCount",
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

forumRoutes.get('/:id', async (c) => {
  const db = c.get('db');
  const [post] = await db
    .select()
    .from(forumPosts)
    .where(and(eq(forumPosts.id, c.req.param('id')), isNull(forumPosts.deletedAt)))
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
     order by r.created_at
  `);

  return c.json({ ...post, replies });
});

forumRoutes.post('/', async (c) => {
  const user = currentUser(c);
  const body = postBody.parse(await c.req.json());
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
    throw forbidden('Solo podés borrar tus propias publicaciones.');
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
