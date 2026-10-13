import { eq, isNull } from 'drizzle-orm';
import { z } from 'zod';

import type { Database } from '../db/client';
import { certificateTemplates } from '../db/schema';
import { badRequest, conflict, payloadTooLarge } from '../lib/errors';
import { mediaStorage } from '../lib/media-storage';
import { createDownloadUrl, isStorageConfigured } from '../lib/s3';

/**
 * Los moldes de certificado (etapa 6, parte 2): qué se acepta y cuál se usa.
 *
 * Un molde es un fondo —PDF de una página, PNG o JPG— y dónde va cada dato. Las
 * posiciones van en fracciones de la página (0 a 1): el mismo molde sirve para
 * la vista previa en pantalla y para el PDF, a cualquier resolución.
 */

export const CARPETA_MOLDES = 'certificate-templates/';
export const MAX_FONDO_BYTES = 8 * 1024 * 1024;
export const MAX_FIRMA_BYTES = 1024 * 1024;

/** Tipo declarado al pedir permiso de subida → extensión de la key. */
export const TIPOS_DE_FONDO: Record<string, 'pdf' | 'png' | 'jpeg'> = {
  'application/pdf': 'pdf',
  'image/png': 'png',
  'image/jpeg': 'jpeg',
};

const fraccion = z.number().min(0).max(1);

/** Un dato escrito: dónde, de qué tamaño y cómo. */
const campoDeTexto = z
  .object({
    x: fraccion,
    y: fraccion,
    /** Ancho de la caja en que se alinea el texto. */
    w: z.number().gt(0).max(1),
    /** Tamaño de la letra, como fracción del alto de la página. */
    size: z.number().min(0.005).max(0.2),
    align: z.enum(['left', 'center', 'right']).default('center'),
    color: z
      .string()
      .regex(/^#[0-9A-Fa-f]{6}$/, 'El color tiene que ser #RRGGBB.')
      .transform((s) => s.toUpperCase())
      .default('#1F1F1F'),
    font: z.enum(['sans', 'display']).default('sans'),
    bold: z.boolean().default(false),
  })
  .strict();

/** Un dato dibujado (el QR, la firma): dónde y de qué ancho. */
const campoDeImagen = z
  .object({ x: fraccion, y: fraccion, w: z.number().gt(0).max(1) })
  .strict();

export const camposDelMolde = z
  .object({
    nombre: campoDeTexto,
    curso: campoDeTexto,
    fecha: campoDeTexto.optional(),
    horas: campoDeTexto.optional(),
    codigo: campoDeTexto.optional(),
    qr: campoDeImagen.optional(),
    firma: campoDeImagen.optional(),
  })
  .strict();

export const moldeBody = z.object({
  backgroundS3Key: z.string().trim().min(1),
  pageWidth: z.number().positive().max(5000),
  pageHeight: z.number().positive().max(5000),
  fields: camposDelMolde,
  signatureS3Key: z.string().trim().min(1).nullable().default(null),
});

/** Lo que un archivo dice ser, por sus primeros bytes. */
function tipoPorContenido(inicio: Uint8Array): 'pdf' | 'png' | 'jpeg' | null {
  const es = (firma: number[]) => firma.every((b, i) => inicio[i] === b);
  if (es([0x25, 0x50, 0x44, 0x46, 0x2d])) return 'pdf'; // %PDF-
  if (es([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'png';
  if (es([0xff, 0xd8, 0xff])) return 'jpeg';
  return null;
}

/**
 * Comprueba un archivo YA subido: que esté en la carpeta de moldes, que exista,
 * que pese lo permitido y que sea lo que dice ser —mirando sus bytes, no lo
 * que declaró el navegador—. Devuelve su tipo.
 */
export async function verificarArchivoDeMolde(
  key: string,
  uso: 'fondo' | 'firma',
): Promise<'pdf' | 'png' | 'jpeg'> {
  if (!key.startsWith(CARPETA_MOLDES) || key.includes('..')) {
    throw badRequest('El archivo tiene que subirse desde el editor del certificado.');
  }
  const storage = mediaStorage();
  const tamano = await storage.objectSize(key);
  if (tamano === null) {
    throw conflict('El archivo no llegó al almacenamiento. Súbalo de nuevo.');
  }
  const maximo = uso === 'fondo' ? MAX_FONDO_BYTES : MAX_FIRMA_BYTES;
  if (tamano > maximo) {
    throw payloadTooLarge(
      `El archivo pesa ${(tamano / 1024 / 1024).toFixed(1)} MB y el máximo es ${maximo / 1024 / 1024} MB.`,
      { maxBytes: maximo },
    );
  }
  const inicio = await storage.readObjectStart(key, 8);
  const tipo = inicio ? tipoPorContenido(inicio) : null;
  if (uso === 'firma' && tipo !== 'png') {
    throw badRequest('La firma tiene que ser un PNG, idealmente con fondo transparente.');
  }
  if (!tipo) {
    throw badRequest('El molde tiene que ser un PDF, un PNG o un JPG. Expórtelo de nuevo.');
  }
  return tipo;
}

type FilaMolde = typeof certificateTemplates.$inferSelect;

/** El molde de [clientId]; `null` = el de eduXaction. */
export async function moldeDe(db: Database, clientId: string | null): Promise<FilaMolde | null> {
  const [fila] = await db
    .select()
    .from(certificateTemplates)
    .where(
      clientId
        ? eq(certificateTemplates.clientId, clientId)
        : isNull(certificateTemplates.clientId),
    )
    .limit(1);
  return fila ?? null;
}

/**
 * El molde con que se imprime un certificado: el de su cliente emisor; si no
 * subió uno, el de eduXaction; si tampoco hay, ninguno (el diseño de siempre).
 */
export async function moldeParaCertificado(
  db: Database,
  issuerClientId: string | null,
): Promise<FilaMolde | null> {
  if (issuerClientId) {
    const propio = await moldeDe(db, issuerClientId);
    if (propio) return propio;
  }
  return moldeDe(db, null);
}

/** El molde como lo recibe la app: con los enlaces firmados de sus archivos. */
export async function moldeParaLaApp(molde: FilaMolde) {
  const firmar = async (key: string | null) =>
    key && isStorageConfigured() ? (await createDownloadUrl({ key })).url : null;
  return {
    clientId: molde.clientId,
    backgroundKind: molde.backgroundKind,
    pageWidth: molde.pageWidth,
    pageHeight: molde.pageHeight,
    fields: molde.fields,
    backgroundS3Key: molde.backgroundS3Key,
    signatureS3Key: molde.signatureS3Key,
    backgroundUrl: await firmar(molde.backgroundS3Key),
    signatureUrl: await firmar(molde.signatureS3Key),
    updatedAt: molde.updatedAt,
  };
}
