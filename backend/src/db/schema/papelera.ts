import { index, jsonb, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

/**
 * La papelera: una copia de cada fila de contenido que se borra, para que
 * nada se pierda para siempre (recomendaciones del 20 de noviembre, «borrado
 * lógico»).
 *
 * Personas, cursos, laboratorios, proyectos, equipos, entregas y el foro ya
 * se borran de forma lógica (`deletedAt`). Las piezas de un curso o de una
 * Ruta —lecciones, módulos, objetivos, términos del glosario— y los moldes de
 * certificado se borraban de verdad. Pasarlas a `deletedAt` obligaba a tocar
 * unas 235 consultas (entre ellas las que calculan el avance de cada
 * estudiante); acá la base guarda la fila entera ANTES de borrarla, con un
 * trigger, y el resto del código sigue igual. Atrapa también lo que se borra
 * en cascada: al borrar un módulo, sus lecciones quedan en la papelera.
 *
 * Los archivos de S3 de lo que está en la papelera no se borran durante
 * [diasEnPapelera] días (`services/storage-cleanup.ts`).
 */
export const papelera = pgTable(
  'papelera',
  {
    id: uuid().primaryKey().defaultRandom(),
    /** La tabla de donde salió: `lessons`, `course_modules`… */
    tabla: text().notNull(),
    /** El `id` de la fila borrada. */
    filaId: text().notNull(),
    /** La fila completa, tal como estaba. */
    datos: jsonb().notNull(),
    borradoEn: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('papelera_tabla_fila_idx').on(t.tabla, t.filaId),
    index('papelera_borrado_en_idx').on(t.borradoEn),
  ],
);

/** Cuánto se guardan los archivos de lo que está en la papelera. */
export const diasEnPapelera = 30;
