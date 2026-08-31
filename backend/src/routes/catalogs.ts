import { asc } from 'drizzle-orm';
import { Hono } from 'hono';

import { competencies, odsGoals } from '../db/schema';
import { requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

/**
 * Los catálogos fijos: competencias Enactus y ODS.
 *
 * Existen como endpoint porque el constructor de cursos necesita dibujar una
 * ficha por cada uno, y esas listas ya viven en PostgreSQL como claves ajenas
 * de verdad (`course_competencies`, `course_ods`). Copiarlas otra vez a una
 * constante de Dart dejaría dos fuentes que se van separando en silencio: una
 * competencia agregada en la base no aparecería en el editor, y una escrita a
 * mano en el cliente sería rechazada por la clave ajena recién al guardar.
 *
 * Son dos tablas de 12 y 17 filas que no cambian entre despliegues: el cliente
 * las pide una vez por sesión.
 */
export const catalogRoutes = new Hono<AppEnv>();
catalogRoutes.use('*', requireAuth);

catalogRoutes.get('/', async (c) => {
  const db = c.get('db');
  const [competencyList, odsList] = await Promise.all([
    db
      .select({ code: competencies.code, name: competencies.name })
      .from(competencies)
      .orderBy(asc(competencies.name)),
    db
      .select({
        code: odsGoals.code,
        number: odsGoals.number,
        title: odsGoals.title,
      })
      .from(odsGoals)
      .orderBy(asc(odsGoals.number)),
  ]);

  return c.json({ competencies: competencyList, ods: odsList });
});
