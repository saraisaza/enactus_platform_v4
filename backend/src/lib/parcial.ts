import { z } from 'zod';

type SinDefault<T> = T extends z.ZodDefault<infer U> ? U : T;

/**
 * La versión «para PATCH» de un esquema: todos los campos opcionales y
 * **ninguno con valor por defecto**.
 *
 * Existe porque en zod 4 `.partial()` SIGUE aplicando los `.default()`: un
 * campo que no llegó vuelve como `''`, `0`, `false` o `[]`, y el
 * `.set({ ...body })` del handler lo escribe encima de lo que había. Guardar
 * la sección «Certificado» del constructor borraba la descripción, el nivel y
 * las horas del curso; editar el rol de una persona le borraba el teléfono, la
 * ciudad y la universidad; editar un proyecto le quitaba los ODS.
 *
 * Con esto, lo que no se manda queda `undefined`, y Drizzle no escribe una
 * columna `undefined`: queda como estaba.
 */
export function parcial<S extends z.ZodRawShape>(esquema: z.ZodObject<S>) {
  const campos = Object.fromEntries(
    Object.entries(esquema.shape).map(([nombre, campo]) => [
      nombre,
      campo instanceof z.ZodDefault ? campo.unwrap() : campo,
    ]),
  ) as { [K in keyof S]: SinDefault<S[K]> };
  return z.object(campos).partial();
}
