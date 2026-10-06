/**
 * Los tipos de aviso que la app sabe mostrar en el idioma de quien lo lee.
 *
 * Un aviso se guarda con su texto en español (`title`, `body`) —lo que ve una
 * versión de la app que no conoce el tipo— y, además, con su `kind` y los
 * datos que cambian (`params`). La app de quien lo recibe arma el texto con
 * eso, en su idioma. Ver `notifications.kind` en el esquema.
 */
export const TIPOS_DE_AVISO = [
  /** Un LXD calificó una entrega. `params.tarea`. */
  'entrega_calificada',
  /** Un mentor comentó una entrega (lo genera el servidor). `params.tarea`. */
  'entrega_revisada',
  /** Alguien reportó contenido del foro. Sin datos. */
  'foro_reporte',
  /** Se emitió un certificado. `params.laboratorio`. */
  'certificado_nuevo',
  /** El mentor avisa que comentó (lo manda la app). `params.tarea`. */
  'mentor_comento',
  /** Un aliado pide estudiantes patrocinados. `params.remitente`, `params.correo`. */
  'solicitud_patrocinados',
] as const;

export type TipoDeAviso = (typeof TIPOS_DE_AVISO)[number];

/**
 * Los que puede mandar una persona desde la app. Los demás los genera solo el
 * servidor: aceptarlos acá dejaría a cualquiera fabricar, por ejemplo, un
 * «Nuevo certificado» que no existe.
 */
export const TIPOS_DESDE_LA_APP = ['mentor_comento', 'solicitud_patrocinados'] as const;
