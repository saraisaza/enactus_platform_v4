import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  integer,
  pgTable,
  text,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';

/**
 * Cliente de la plataforma: una empresa, o Enactus.
 *
 * Cada cliente puede tener su marca —logo y dos colores— y quien inicia sesión
 * ve la plataforma con la de su cliente (ver `docs/clientes/README.md`). El
 * logo de eduXaction se ve siempre; el del cliente va al lado.
 *
 * Enactus es un cliente más, con necesidades especiales: es el único con
 * laboratorios y Ruta de Impacto ([hasLaboratories]). Lo crea la migración
 * 0013, así que existe en todos los entornos sin que nadie lo dé de alta.
 *
 * Sin logo o sin colores, se usa la marca de eduXaction en lo que falte.
 *
 * Vive en su propio archivo y no importa `users`, por la misma razón que
 * `universities`: `users` va a apuntar acá.
 */
export const clients = pgTable(
  'clients',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),

    /**
     * El logo en S3 (`client-logos/<uuid>.png`). Un PNG ya verificado por el
     * servidor: firma de PNG, peso y medidas (ver `routes/clients.ts`).
     */
    logoS3Key: text('logo_s3_key'),
    /** Medidas del logo en píxeles: la app reserva el espacio antes de bajarlo. */
    logoWidth: integer(),
    logoHeight: integer(),
    /**
     * Placa clara detrás del logo. Un logo oscuro con fondo transparente
     * desaparece sobre el encabezado gris de la plataforma; con la placa se
     * ve. La app la propone al subir el logo y el admin decide.
     */
    logoLightPlate: boolean().notNull().default(false),

    /** `#RRGGBB` en mayúsculas, o nulo para usar el de eduXaction. */
    primaryColor: text(),
    /** `#RRGGBB` en mayúsculas, o nulo para usar el primario. */
    secondaryColor: text(),

    /**
     * Laboratorios y Ruta de Impacto. Solo Enactus, por ahora: el índice
     * `clients_one_with_laboratories` impide que haya dos, porque la
     * migración que asigna las cuentas de Enactus a su cliente lo busca por
     * esta marca. No se cambia desde la API.
     */
    hasLaboratories: boolean().notNull().default(false),

    /**
     * `false` = cliente desactivado. Sus cuentas no pueden iniciar sesión
     * (se aplica cuando las cuentas tengan cliente); su avance no se borra y
     * vuelve tal cual al reactivarlo.
     */
    active: boolean().notNull().default(true),

    ...timestamps,
  },
  (t) => [
    // Dos clientes no pueden llamarse igual, ni con otras mayúsculas: en el
    // desplegable de cuentas serían indistinguibles.
    uniqueIndex('clients_name_lower_unique').on(sql`lower(${t.name})`),
    uniqueIndex('clients_one_with_laboratories')
      .on(t.hasLaboratories)
      .where(sql`${t.hasLaboratories}`),
    check('clients_name_not_blank', sql`length(trim(${t.name})) > 0`),
    check(
      'clients_primary_color_hex',
      sql`${t.primaryColor} is null or ${t.primaryColor} ~ '^#[0-9A-F]{6}$'`,
    ),
    check(
      'clients_secondary_color_hex',
      sql`${t.secondaryColor} is null or ${t.secondaryColor} ~ '^#[0-9A-F]{6}$'`,
    ),
    // El logo va completo o no va: una key sin medidas, o medidas sin key,
    // serían un logo que la app no sabe dibujar.
    check(
      'clients_logo_complete',
      sql`(${t.logoS3Key} is null) = (${t.logoWidth} is null)
          and (${t.logoS3Key} is null) = (${t.logoHeight} is null)`,
    ),
    check(
      'clients_logo_key_folder',
      sql`${t.logoS3Key} is null or ${t.logoS3Key} like 'client-logos/%'`,
    ),
    check(
      'clients_logo_size_positive',
      sql`${t.logoWidth} is null or (${t.logoWidth} > 0 and ${t.logoHeight} > 0)`,
    ),
  ],
);
