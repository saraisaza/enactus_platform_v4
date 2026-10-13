import { sql } from 'drizzle-orm';
import { check, jsonb, pgTable, real, text, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';
import { clients } from './clients';

/**
 * El molde del certificado de un cliente (etapa 6, parte 2).
 *
 * Un diseño hecho afuera —en Canva, PowerPoint— y subido como PDF de una
 * página o como imagen. Encima, la plataforma escribe lo de cada persona en
 * los lugares que el admin marcó arrastrando: nombre, curso, fecha, horas,
 * código, QR y firma.
 *
 * Uno por cliente. `client_id` nulo es el molde de eduXaction: el de quien no
 * tiene cliente, y el de los clientes que no subieron el suyo. Sin ninguno, el
 * certificado sale con el diseño de siempre.
 */
export const certificateTemplates = pgTable(
  'certificate_templates',
  {
    id: uuid().primaryKey().defaultRandom(),
    clientId: uuid().references(() => clients.id, { onDelete: 'cascade' }),

    /** El diseño de fondo, en `certificate-templates/`. */
    backgroundS3Key: text('background_s3_key').notNull(),
    backgroundKind: text().notNull(),
    /**
     * Tamaño de la página en puntos (1/72 de pulgada). En un PDF, el de su
     * primera página; en una imagen, su proporción con 842 pt de ancho (A4).
     */
    pageWidth: real().notNull(),
    pageHeight: real().notNull(),

    /**
     * Dónde va cada dato, en fracciones de la página (0 a 1) para que no
     * dependa de la resolución: `{ nombre: { x, y, w, size, align, color,
     * font, bold }, ..., qr: { x, y, w }, firma: { x, y, w } }`. Lo valida
     * `routes/clients.ts`.
     */
    fields: jsonb().notNull().default({}),

    /** La firma de quien certifica: un PNG, idealmente con fondo transparente. */
    signatureS3Key: text('signature_s3_key'),

    ...timestamps,
  },
  (t) => [
    uniqueIndex('certificate_templates_client_unique')
      .on(t.clientId)
      .where(sql`${t.clientId} is not null`),
    // Uno solo de eduXaction.
    uniqueIndex('certificate_templates_eduxaction_unique')
      .on(sql`(${t.clientId} is null)`)
      .where(sql`${t.clientId} is null`),
    check('certificate_templates_kind', sql`${t.backgroundKind} in ('pdf', 'png', 'jpeg')`),
    check(
      'certificate_templates_keys_folder',
      sql`${t.backgroundS3Key} like 'certificate-templates/%'
          and (${t.signatureS3Key} is null or ${t.signatureS3Key} like 'certificate-templates/%')`,
    ),
    check(
      'certificate_templates_page_positive',
      sql`${t.pageWidth} > 0 and ${t.pageHeight} > 0`,
    ),
  ],
);
