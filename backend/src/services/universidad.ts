import { and, eq, isNull } from 'drizzle-orm';

import type { Database } from '../db/client';
import { universities } from '../db/schema';
import { conflict, notFound } from '../lib/errors';

/**
 * Resolver una universidad para escribirla, durante la convivencia de
 * `university_id` con la columna de texto (R2).
 *
 * **Escritura doble, y no es transitoria por descuido.** Mientras las lecturas
 * sigan yendo por texto —hasta R3— escribir solo el id dejaría al estudiante
 * con universidad y aun así invisible para su asesor: el `id` estaría puesto y
 * el texto vacío, y la comparación que decide la visibilidad mira el texto.
 *
 * Y al revés, escribir solo el texto —lo de hoy— deja el `id` sin poner, y
 * entonces R3 lo haría desaparecer. Las dos columnas tienen que decir lo
 * mismo en todo momento; esa es la condición literal para poder desplegar R3
 * (bloque 6 del reporte).
 *
 * Cuando R4 borre la columna de texto, esta función pierde la mitad de su
 * trabajo y se queda solo validando que la universidad exista y esté activa.
 */
export interface UniversidadResuelta {
  universityId: string;
  university: string;
}

export async function resolverUniversidad(
  db: Database,
  universityId: string | null,
): Promise<UniversidadResuelta | { universityId: null; university: '' }> {
  // `null` explícito = quitarle la universidad. Se limpian las dos columnas,
  // por lo mismo de arriba: dejar el texto puesto con el id vacío haría que
  // hoy siga visible y mañana no.
  if (!universityId) return { universityId: null, university: '' };

  const [fila] = await db
    .select({
      id: universities.id,
      name: universities.name,
      active: universities.active,
    })
    .from(universities)
    .where(and(eq(universities.id, universityId), isNull(universities.deletedAt)))
    .limit(1);

  if (!fila) throw notFound('No encontramos esa universidad.');

  // Una universidad inactiva no admite asignaciones NUEVAS, pero lo que ya
  // está asignado sigue funcionando: por eso se valida al escribir y no al
  // leer. «Sin asignar» es inactiva, así que esto también impide que alguien
  // mande a alguien ahí a propósito desde un formulario.
  if (!fila.active) {
    throw conflict(
      `La universidad ${fila.name} está inactiva y no admite asignaciones nuevas.`,
    );
  }

  return { universityId: fila.id, university: fila.name };
}
