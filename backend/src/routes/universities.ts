import { and, asc, eq, isNull } from 'drizzle-orm';
import { Hono } from 'hono';

import { universities } from '../db/schema';
import { requireAuth } from '../middleware/auth';
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
