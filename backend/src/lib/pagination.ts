import { z } from 'zod';

/**
 * Paginación uniforme para todos los listados.
 *
 * Hoy el cliente lee `DataProvider.courses` y recibe TODO de una vez, porque
 * Hive es local y no cuesta nada. Contra una API eso no escala ni es sano:
 * cada listado se pagina, y el cliente sabe cuántas páginas hay.
 */
export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

export type Pagination = z.infer<typeof paginationSchema>;

export interface Page<T> {
  data: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export function paginated<T>(
  data: T[],
  total: number,
  { page, pageSize }: Pagination,
): Page<T> {
  return {
    data,
    page,
    pageSize,
    total,
    totalPages: total === 0 ? 0 : Math.ceil(total / pageSize),
  };
}

/** `?include=modules,lessons` → Set{'modules','lessons'} */
export function parseInclude(raw: string | undefined): Set<string> {
  if (!raw) return new Set();
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}
