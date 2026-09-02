import { describe, expect, it } from 'vitest';

import { resolveClientIp } from '../src/lib/client-ip';

/**
 * De dónde sale la IP del cliente.
 *
 * Esta prueba nace de un agujero real y reproducido: el límite de intentos de
 * login se agrupaba por IP, la IP salía de `x-forwarded-for[0]`, y esa entrada
 * la escribe el cliente. Rotándola pasaron 60 de 60 intentos de fuerza bruta
 * contra `admin@enactus.co` sin un solo 429.
 *
 * Lo que se prueba acá no es "la función devuelve una IP", es que **la entrada
 * que el cliente pudo haber inventado se descarta**.
 */

/** Contexto mínimo, con o sin socket, con o sin cabecera. */
const ctx = (opciones: { xff?: string; socket?: string; lambda?: string }) => ({
  env: {
    ...(opciones.socket
      ? { incoming: { socket: { remoteAddress: opciones.socket } } }
      : {}),
    ...(opciones.lambda
      ? { event: { requestContext: { http: { sourceIp: opciones.lambda } } } }
      : {}),
  },
  req: {
    header: (nombre: string) =>
      nombre.toLowerCase() === 'x-forwarded-for' ? opciones.xff : undefined,
  },
});

describe('sin proxies declarados (hops = 0, el default)', () => {
  it('IGNORA x-forwarded-for por completo', () => {
    // El caso del ataque: el cliente declara ser otro. Sin proxies de
    // confianza declarados, esa cabecera no vale nada.
    const ip = resolveClientIp(
      ctx({ xff: '10.0.0.1', socket: '198.51.100.4' }),
      0,
    );
    expect(ip).toBe('198.51.100.4');
  });

  it('rotar la cabecera no cambia la IP resultante', () => {
    const ips = ['1.1.1.1', '2.2.2.2', '3.3.3.3'].map((falsa) =>
      resolveClientIp(ctx({ xff: falsa, socket: '198.51.100.4' }), 0),
    );
    expect(new Set(ips).size).toBe(1);
  });

  it('en Lambda usa el sourceIp del evento, que lo pone API Gateway', () => {
    expect(
      resolveClientIp(ctx({ xff: '10.0.0.1', lambda: '198.51.100.9' }), 0),
    ).toBe('198.51.100.9');
  });
});

describe('con proxies declarados', () => {
  it('hops = 1: toma la ÚLTIMA entrada, no la primera', () => {
    // `x-forwarded-for: <lo que inventó el cliente>, <IP real que puso el proxy>`
    const ip = resolveClientIp(
      ctx({ xff: '10.0.0.1, 203.0.113.50', socket: '172.31.0.2' }),
      1,
    );
    expect(ip).toBe('203.0.113.50');
    expect(ip).not.toBe('10.0.0.1');
  });

  it('hops = 2 (CloudFront + API Gateway): salta las dos de la derecha', () => {
    const ip = resolveClientIp(
      ctx({ xff: 'inventada, 203.0.113.50, 130.176.0.9', socket: '172.31.0.2' }),
      2,
    );
    expect(ip).toBe('203.0.113.50');
  });

  it('varias entradas inventadas adelante no corren la que vale', () => {
    const ip = resolveClientIp(
      ctx({ xff: 'a, b, c, d, 203.0.113.50', socket: '172.31.0.2' }),
      1,
    );
    expect(ip).toBe('203.0.113.50');
  });

  it('si la cadena es más corta que los saltos, cae a la conexión', () => {
    // Alguien llegando DIRECTO al origen, saltándose los proxies, para que la
    // única entrada de la cabecera sea la suya. No se le hace caso.
    const ip = resolveClientIp(
      ctx({ xff: '10.0.0.1', socket: '198.51.100.4' }),
      2,
    );
    expect(ip).toBe('198.51.100.4');
  });

  it('sin cabecera ninguna, cae a la conexión', () => {
    expect(resolveClientIp(ctx({ socket: '198.51.100.4' }), 1)).toBe(
      '198.51.100.4',
    );
  });
});

describe('normalización', () => {
  it('::ffff:1.2.3.4 y 1.2.3.4 son el mismo cupo', () => {
    const a = resolveClientIp(ctx({ socket: '::ffff:203.0.113.7' }), 0);
    const b = resolveClientIp(ctx({ socket: '203.0.113.7' }), 0);
    expect(a).toBe(b);
    expect(a).toBe('203.0.113.7');
  });

  it('sin nada de dónde sacarla, devuelve un valor fijo y no revienta', () => {
    expect(resolveClientIp(ctx({}), 0)).toBe('desconocida');
  });
});
