import { and, asc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { auditLog, universities } from '../db/schema';
import { conflict } from '../lib/errors';
import { ADMIN_ROLES, currentUser, requireAuth, requireRole } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

/**
 * El catálogo de universidades de la red.
 *
 * Existe para que NINGÚN formulario vuelva a tener un campo de texto libre
 * para la universidad. Ese campo es el origen de D2: la visibilidad del asesor
 * dependía de comparar cadenas, y un espacio o una tilde lo dejaba sin ver a
 * su gente, sin error y sin log.
 *
 * Lo lee cualquier sesión: es una lista de universidades, no un dato sensible,
 * y el desplegable aparece en varios formularios. Gestionarlas —crear, editar,
 * dar de baja— es de administración y llega con su propio endpoint.
 */
export const universityRoutes = new Hono<AppEnv>();
universityRoutes.use('*', requireAuth);

universityRoutes.get('/', async (c) => {
  const db = c.get('db');

  /**
   * `?incluirInactivas=1` para las pantallas de administración.
   *
   * Por defecto NO vienen las inactivas, y eso importa: «Sin asignar» es una
   * de ellas. Si apareciera en un desplegable, alguien la elegiría —está ahí,
   * parece una opción— y estaríamos volviendo a meter a mano el estado que el
   * reporte de integridad existe para vaciar.
   */
  const incluirInactivas = c.req.query('incluirInactivas') === '1';

  const filas = await db
    .select({
      id: universities.id,
      name: universities.name,
      shortName: universities.shortName,
      city: universities.city,
      country: universities.country,
      active: universities.active,
    })
    .from(universities)
    .where(
      incluirInactivas
        ? isNull(universities.deletedAt)
        : and(isNull(universities.deletedAt), eq(universities.active, true)),
    )
    .orderBy(asc(universities.name));

  return c.json({ data: filas });
});

const columnas = {
  id: universities.id,
  name: universities.name,
  shortName: universities.shortName,
  city: universities.city,
  country: universities.country,
  active: universities.active,
};

const crearBody = z.object({
  name: z
    .string()
    .trim()
    .min(3, 'Escriba el nombre completo de la institución.')
    .max(150, 'El nombre es demasiado largo.')
    // Espacios de más en el medio: «Universidad  del Valle» es la misma.
    .transform((v) => v.replace(/\s+/g, ' ')),
});

/**
 * «Otra (¿cuál?)» del desplegable: agrega una institución al catálogo, o
 * devuelve la que ya estaba.
 *
 * Es la forma de que nadie se quede sin poder inscribirse sin volver a abrir
 * el campo de texto libre (D2): lo que se escribe en «Otra» NO se guarda en la
 * persona; se vuelve una fila del catálogo, y la persona apunta a ella como a
 * cualquier otra. Así un asesor puede quedar asignado a esa institución y ver a
 * su gente, igual que con las 81 de la lista.
 *
 * Antes de crear se busca por `slug` —la misma normalización de las
 * migraciones—: «universidad del valle » o «UNIVERSIDAD DEL VALLE» devuelven la
 * fila que ya existe en vez de crear otra. Lo que la normalización no alcanza
 * («U. del Valle») sí entraría como nueva; eso lo encuentra el bloque 3 del
 * reporte, como en el relleno.
 *
 * Solo Admin y Super Admin: son quienes inscriben, y agregar al catálogo es
 * administrarlo.
 */
universityRoutes.post('/', requireRole(...ADMIN_ROLES), async (c) => {
  const admin = currentUser(c);
  const { name } = crearBody.parse(await c.req.json());
  const db = c.get('db');
  const slug = sql`enactus_normalizar_universidad(${name})`;

  const buscar = () =>
    db
      .select(columnas)
      .from(universities)
      .where(and(isNull(universities.deletedAt), eq(universities.slug, slug)))
      .limit(1);

  const [existente] = await buscar();
  if (existente) {
    if (!existente.active) {
      throw conflict(
        `«${existente.name}» ya está en el catálogo, pero inactiva: no admite ` +
          'inscripciones nuevas. Pídale a quien administra el catálogo que la active.',
      );
    }
    return c.json({ ...existente, existente: true });
  }

  const [creada] = await db
    .insert(universities)
    .values({ name, slug })
    // Dos personas creando la misma a la vez: el índice único sobre `slug`
    // deja entrar una, y la otra recibe la que entró.
    .onConflictDoNothing()
    .returning(columnas);
  if (!creada) {
    const [ganadora] = await buscar();
    return c.json({ ...ganadora!, existente: true });
  }

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'university.create',
    entityType: 'university',
    entityId: creada.id,
    newValue: { name: creada.name },
    ip: c.get('requestIp'),
  });
  return c.json({ ...creada, existente: false }, 201);
});
