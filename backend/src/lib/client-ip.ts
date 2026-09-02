import { env } from '../env';

/**
 * De dónde sale la IP del cliente — y por qué NO es `x-forwarded-for[0]`.
 *
 * Esta función existe por un agujero real, verificado con `curl` contra la API
 * corriendo: el límite de intentos de login se agrupaba por
 * `login:${ip}:${correo}` sacando la IP de la primera entrada de
 * `x-forwarded-for`. Esa entrada la escribe el cliente. Rotándola, 60 de 60
 * intentos de fuerza bruta contra `admin@enactus.co` pasaron sin un solo 429:
 * el límite no frenaba nada y las pruebas seguían en verde, porque probaban
 * que IPs distintas tienen cupos distintos — que es exactamente el mecanismo
 * que el atacante usa.
 *
 * La regla: **de una petición HTTP, lo único que el cliente no puede
 * falsificar es la IP de la conexión.** Todo lo demás, cabeceras incluidas,
 * es texto que él eligió.
 *
 * Cuando hay proxies delante (CloudFront, API Gateway), la IP de la conexión
 * es la del proxy y hay que leer `x-forwarded-for` — pero solo la parte que
 * escribió un proxy de confianza, nunca la que venía de antes.
 */

/** Forma mínima que necesitamos del contexto, sin acoplarse a Hono. */
interface ContextoConEntorno {
  env?: unknown;
  req: { header: (nombre: string) => string | undefined };
}

/**
 * La IP de la conexión: la que puso el runtime, no el cliente.
 *
 * Hay dos runtimes y cada uno la expone en su lugar. Ninguno de los dos
 * existe en `app.request()` de las pruebas, donde no hay socket — ahí
 * devuelve `undefined` y se cae al camino de la cabecera.
 */
function ipDeLaConexion(c: ContextoConEntorno): string | undefined {
  const entorno = c.env as
    | {
        // Adaptador de Lambda: `sourceIp` lo escribe API Gateway a partir de
        // la conexión TCP. El cliente no participa.
        event?: { requestContext?: { http?: { sourceIp?: string } } };
        // @hono/node-server: el socket real.
        incoming?: { socket?: { remoteAddress?: string } };
      }
    | undefined;

  return (
    entorno?.event?.requestContext?.http?.sourceIp ??
    entorno?.incoming?.socket?.remoteAddress
  );
}

/**
 * La IP del cliente, según cuántos proxies de confianza haya declarados.
 *
 * Cada proxy **agrega a la derecha** la IP de quien le habló. Así que con
 * `hops` proxies de confianza delante, la IP real del cliente está a `hops`
 * posiciones del final — todo lo que esté a la izquierda de eso lo pudo haber
 * inventado el cliente y se descarta.
 *
 *     hops=0  →  se ignora la cabecera entera y se usa la conexión.
 *     hops=1  →  `..., IP-REAL`                    (solo CloudFront)
 *     hops=2  →  `..., IP-REAL, ip-de-cloudfront`  (CloudFront + API Gateway)
 */
export function resolveClientIp(
  c: ContextoConEntorno,
  hops: number = env.TRUSTED_PROXY_HOPS,
): string {
  const directa = ipDeLaConexion(c);
  if (hops === 0) return normalizar(directa);

  const cadena = (c.req.header('x-forwarded-for') ?? '')
    .split(',')
    .map((parte) => parte.trim())
    .filter(Boolean);

  // Si la cadena es más corta que los saltos declarados, la petición no pasó
  // por los proxies que se esperaban. Puede ser alguien llegando directo al
  // origen para saltarse el conteo, así que se cae a la conexión en vez de
  // agarrar la entrada que quede — que sería justamente la del atacante.
  const cliente = cadena.length >= hops ? cadena[cadena.length - hops] : undefined;
  return normalizar(cliente ?? directa);
}

/**
 * IPv6 escribe las IPv4 como `::ffff:1.2.3.4`; sin esto, la misma máquina
 * puede ocupar dos cupos distintos según cómo se conectó.
 */
function normalizar(ip: string | undefined): string {
  if (!ip) return 'desconocida';
  return ip.startsWith('::ffff:') ? ip.slice('::ffff:'.length) : ip;
}
