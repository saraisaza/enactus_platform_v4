import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';

/**
 * Configuración de ejecución, leída de un objeto cifrado en S3.
 *
 * **Por qué S3 y no Secrets Manager.** La Lambda vive en una VPC sin NAT, a
 * propósito. Secrets Manager solo tiene endpoint de tipo *Interface*, que se
 * cobra por hora: unos US$7 al mes por zona, más de lo que cuesta la propia
 * base de datos. S3 tiene endpoint de tipo *Gateway*, que es gratuito y que la
 * VPC ya necesita. Mismo cifrado, mismo aislamiento, sin la factura.
 *
 * Secrets Manager sigue siendo la fuente de verdad: el pipeline —que corre
 * fuera de la VPC— copia el secreto a S3 en cada despliegue. Así no hay dos
 * lugares donde editar a mano.
 *
 * **Cómo queda protegido:**
 *
 * - Bucket aparte, cifrado con SSE-KMS y una llave propia.
 * - La política del bucket NIEGA `s3:GetObject` a todo el mundo salvo al rol
 *   de ejecución de la Lambda — comprobado: `enactus-deploy`, con
 *   `PowerUserAccess`, recibe 403.
 * - `kms:Decrypt` acotado con `kms:ViaService` a S3, así que la llave no sirve
 *   para descifrar nada por fuera de este camino.
 * - Con SSE-KMS **descifra S3**, no el cliente: no hace falta endpoint de KMS.
 */

/** Lo que la aplicación espera encontrar. Nombres iguales a los de `env.ts`. */
const ESPERADAS = [
  'DATABASE_URL',
  'JWT_SECRET',
  'CORS_ORIGIN',
  'NODE_ENV',
  'TRUSTED_PROXY_HOPS',
] as const;

/**
 * Una sola lectura por contenedor.
 *
 * Vive fuera del handler a propósito: leerlo en cada invocación agregaría un
 * viaje a S3 a cada petición de cada persona, para traer siempre lo mismo. La
 * promesa se guarda —no el resultado— para que dos invocaciones concurrentes
 * durante el arranque en frío compartan la misma lectura en vez de disparar
 * dos.
 */
let enCurso: Promise<void> | undefined;

export function cargarSecretos(): Promise<void> {
  enCurso ??= leer();
  return enCurso;
}

/** Solo para las pruebas: olvida la lectura anterior. */
export function olvidarSecretos(): void {
  enCurso = undefined;
}

async function leer(): Promise<void> {
  const bucket = process.env.SECRETS_BUCKET;
  const key = process.env.SECRETS_KEY;

  // Sin las dos variables no hay nada que leer. En local eso es lo normal: la
  // configuración viene de `backend/.env` y esta función no hace falta.
  if (!bucket || !key) return;

  const s3 = new S3Client({});
  let texto: string;
  try {
    const respuesta = await s3.send(
      new GetObjectCommand({ Bucket: bucket, Key: key }),
    );
    if (!respuesta.Body) throw new Error('la respuesta llegó sin cuerpo');
    texto = await respuesta.Body.transformToString();
  } catch (error) {
    // Ruidoso y sin arrancar. Lo contrario —seguir con la configuración a
    // medias— haría que la Lambda levantara sin `JWT_SECRET` y firmara
    // tokens con un valor vacío, o se conectara a la base equivocada. Un
    // fallo al arrancar se ve; uno así, no.
    //
    // El mensaje dice DÓNDE falló, nunca qué había adentro.
    throw new Error(
      `No pude leer la configuración de s3://${bucket}/${key}: ` +
        `${error instanceof Error ? error.message : String(error)}`,
    );
  }

  let config: Record<string, unknown>;
  try {
    config = JSON.parse(texto) as Record<string, unknown>;
  } catch {
    // El contenido NO se incluye en el mensaje: es exactamente el secreto.
    throw new Error(
      `La configuración de s3://${bucket}/${key} no es JSON válido ` +
        `(${texto.length} bytes leídos).`,
    );
  }

  const faltantes = ESPERADAS.filter((nombre) => !config[nombre]);
  if (faltantes.length > 0) {
    throw new Error(
      `A la configuración de s3://${bucket}/${key} le faltan: ${faltantes.join(', ')}.`,
    );
  }

  // Lo que ya venga en el entorno gana: permite sobreescribir un valor suelto
  // desde la consola de Lambda sin tocar el secreto, que es lo que uno quiere
  // a las 2 de la mañana.
  for (const [nombre, valor] of Object.entries(config)) {
    process.env[nombre] ??= String(valor);
  }
}
