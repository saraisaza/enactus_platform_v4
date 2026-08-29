import { and, asc, count, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { groupMembers, groups, projectOds, projects } from '../db/schema';
import { forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema, parseInclude } from '../lib/pagination';
import {
  ADMIN_ROLES,
  currentUser,
  requireAuth,
  requireEnactus,
  requireRole,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';

/**
 * Proyectos y equipos. Ambos son territorio Enactus: un estudiante de Open
 * Learning no participa en proyectos ni pertenece a un equipo.
 */
export const projectRoutes = new Hono<AppEnv>();
projectRoutes.use('*', requireAuth, requireEnactus);

export const groupRoutes = new Hono<AppEnv>();
groupRoutes.use('*', requireAuth, requireEnactus);

const projectBody = z.object({
  name: z.string().trim().min(1, 'El nombre es obligatorio.'),
  description: z.string().trim().default(''),
  problem: z.string().trim().default(''),
  solution: z.string().trim().default(''),
  community: z.string().trim().default(''),
  stage: z
    .enum(['ideation', 'validation', 'prototype', 'pilot', 'scaling', 'national_expo'])
    .default('ideation'),
  impactIndicators: z.string().trim().default(''),
  expoEnabled: z.boolean().default(false),
  ods: z.array(z.string().trim()).default([]),
});

const groupBody = z.object({
  name: z.string().trim().min(1, 'El nombre es obligatorio.'),
  projectId: z.uuid(),
  university: z.string().trim().default(''),
  advisorId: z.uuid().nullable().optional(),
});

const memberBody = z.object({
  members: z
    .array(
      z.object({
        userId: z.uuid(),
        roleInProject: z
          .enum([
            'leader',
            'research',
            'finance',
            'communications',
            'design',
            'operations',
            'member',
          ])
          .default('member'),
      }),
    )
    .default([]),
});

// ---------------------------------------------------------------------------
// Proyectos
// ---------------------------------------------------------------------------

projectRoutes.get('/', async (c) => {
  const query = paginationSchema.extend({ include: z.string().optional() }).parse(
    c.req.query(),
  );
  const db = c.get('db');
  const where = isNull(projects.deletedAt);

  const [rows, [total]] = await Promise.all([
    db
      .select()
      .from(projects)
      .where(where)
      .orderBy(asc(projects.name))
      .limit(query.pageSize)
      .offset((query.page - 1) * query.pageSize),
    db.select({ value: count() }).from(projects).where(where),
  ]);

  const include = parseInclude(query.include);
  const data = include.has('ods')
    ? await Promise.all(rows.map(async (p) => ({ ...p, ods: await odsOf(db, p.id) })))
    : rows;

  return c.json(paginated(data, total?.value ?? 0, query));
});

projectRoutes.get('/:id', async (c) => {
  const db = c.get('db');
  const [project] = await db
    .select()
    .from(projects)
    .where(and(eq(projects.id, c.req.param('id')), isNull(projects.deletedAt)))
    .limit(1);
  if (!project) throw notFound('No se encontró el proyecto.');

  // Integrantes CON su rol dentro del proyecto: la brecha de modelo que
  // detectó la auditoría de frontend y que el esquema cerró.
  const team = await db.execute<{
    group_id: string;
    group_name: string;
    user_id: string;
    name: string;
    role_in_project: string;
    university: string;
    career: string;
    avatar_s3_key: string | null;
  }>(sql`
    select g.id as group_id, g.name as group_name,
           u.id as user_id, u.name, gm.role_in_project,
           u.university, u.career, u.avatar_s3_key
      from groups g
      join group_members gm on gm.group_id = g.id
      join users u on u.id = gm.user_id
     where g.project_id = ${project.id} and g.deleted_at is null
       and u.deleted_at is null
     order by gm.role_in_project, u.name
  `);

  return c.json({
    ...project,
    ods: await odsOf(db, project.id),
    team,
  });
});

projectRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const body = projectBody.parse(await c.req.json());
  const db = c.get('db');
  const { ods, ...fields } = body;

  const [created] = await db.insert(projects).values(fields).returning();
  await replaceOds(db, created!.id, ods);
  return c.json({ ...created, ods }, 201);
});

/**
 * El Asesor EDITA proyectos pero no los crea (decisión C.4): es lo que hace
 * hoy su portal, que tiene `_editProject` pero ningún botón de "nuevo".
 */
projectRoutes.patch('/:id', async (c) => {
  const user = currentUser(c);
  assertCanEditProject(user);
  const body = projectBody.partial().parse(await c.req.json());
  const db = c.get('db');
  const { ods, ...fields } = body;

  const [updated] = await db
    .update(projects)
    .set({ ...fields, updatedAt: new Date() })
    .where(and(eq(projects.id, c.req.param('id')), isNull(projects.deletedAt)))
    .returning();
  if (!updated) throw notFound('No se encontró el proyecto.');

  if (ods) await replaceOds(db, updated.id, ods);
  return c.json({ ...updated, ods: await odsOf(db, updated.id) });
});

projectRoutes.delete('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const db = c.get('db');
  const [updated] = await db
    .update(projects)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(projects.id, c.req.param('id')), isNull(projects.deletedAt)))
    .returning({ id: projects.id });
  if (!updated) throw notFound('No se encontró el proyecto.');
  return c.body(null, 204);
});

function assertCanEditProject(user: AuthUser): void {
  if (user.role === 'admin' || user.role === 'superadmin' || user.role === 'advisor') {
    return;
  }
  throw forbidden('Solo un administrador o el asesor pueden editar un proyecto.');
}

async function odsOf(db: AppEnv['Variables']['db'], projectId: string) {
  const rows = await db
    .select({ code: projectOds.odsCode })
    .from(projectOds)
    .where(eq(projectOds.projectId, projectId));
  return rows.map((r) => r.code);
}

async function replaceOds(
  db: AppEnv['Variables']['db'],
  projectId: string,
  codes: string[],
) {
  await db.delete(projectOds).where(eq(projectOds.projectId, projectId));
  if (codes.length > 0) {
    await db
      .insert(projectOds)
      .values(codes.map((odsCode) => ({ projectId, odsCode })));
  }
}

// ---------------------------------------------------------------------------
// Equipos
// ---------------------------------------------------------------------------

groupRoutes.get('/', async (c) => {
  const query = paginationSchema.parse(c.req.query());
  const db = c.get('db');
  const where = isNull(groups.deletedAt);

  const [rows, [total]] = await Promise.all([
    db
      .select()
      .from(groups)
      .where(where)
      .orderBy(asc(groups.name))
      .limit(query.pageSize)
      .offset((query.page - 1) * query.pageSize),
    db.select({ value: count() }).from(groups).where(where),
  ]);

  return c.json(paginated(rows, total?.value ?? 0, query));
});

groupRoutes.get('/:id', async (c) => {
  const db = c.get('db');
  const [group] = await db
    .select()
    .from(groups)
    .where(and(eq(groups.id, c.req.param('id')), isNull(groups.deletedAt)))
    .limit(1);
  if (!group) throw notFound('No se encontró el equipo.');

  const members = await db.execute<{
    user_id: string;
    name: string;
    role_in_project: string;
  }>(sql`
    select u.id as user_id, u.name, gm.role_in_project
      from group_members gm
      join users u on u.id = gm.user_id
     where gm.group_id = ${group.id} and u.deleted_at is null
     order by u.name
  `);

  return c.json({ ...group, members });
});

groupRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const body = groupBody.parse(await c.req.json());
  const db = c.get('db');
  const [created] = await db
    .insert(groups)
    .values({ ...body, advisorId: body.advisorId ?? null })
    .returning();
  return c.json(created, 201);
});

groupRoutes.patch('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const body = groupBody.partial().parse(await c.req.json());
  const db = c.get('db');
  const [updated] = await db
    .update(groups)
    .set({ ...body, updatedAt: new Date() })
    .where(and(eq(groups.id, c.req.param('id')), isNull(groups.deletedAt)))
    .returning();
  if (!updated) throw notFound('No se encontró el equipo.');
  return c.json(updated);
});

/**
 * Reemplaza los integrantes del equipo, cada uno con su rol dentro del
 * proyecto. Un solo endpoint en vez de altas y bajas sueltas: así el equipo
 * nunca queda a medias entre dos llamadas.
 */
groupRoutes.put('/:id/members', requireRole(...ADMIN_ROLES), async (c) => {
  const { members } = memberBody.parse(await c.req.json());
  const db = c.get('db');
  const groupId = c.req.param('id');

  const [group] = await db
    .select({ id: groups.id })
    .from(groups)
    .where(and(eq(groups.id, groupId), isNull(groups.deletedAt)))
    .limit(1);
  if (!group) throw notFound('No se encontró el equipo.');

  await db.transaction(async (tx) => {
    await tx.delete(groupMembers).where(eq(groupMembers.groupId, groupId));
    if (members.length > 0) {
      await tx
        .insert(groupMembers)
        .values(members.map((m) => ({ groupId, ...m })));
    }
  });

  const rows = await db
    .select()
    .from(groupMembers)
    .where(eq(groupMembers.groupId, groupId));
  return c.json(rows);
});

groupRoutes.delete('/:id', requireRole(...ADMIN_ROLES), async (c) => {
  const db = c.get('db');
  const [updated] = await db
    .update(groups)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(groups.id, c.req.param('id')), isNull(groups.deletedAt)))
    .returning({ id: groups.id });
  if (!updated) throw notFound('No se encontró el equipo.');
  return c.body(null, 204);
});
