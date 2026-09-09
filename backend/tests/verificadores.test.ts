import { execFile } from 'node:child_process';
import { chmodSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { promisify } from 'node:util';

import { afterAll, describe, expect, it } from 'vitest';

const ejecutar = promisify(execFile);

/**
 * Meta-pruebas: ¿los verificadores verifican?
 *
 * REGLA PERMANENTE DEL PROYECTO: ningún script de verificación se acepta sin
 * su meta-prueba. Un verificador roto se ve **idéntico** a un sistema sano —
 * los dos salen 0 y no dicen nada— y por eso es el único tipo de código donde
 * un fallo silencioso no tiene ningún síntoma hasta el incidente.
 *
 * No es teórico. `verificar-rollback.mjs` decidía si lo estaban ejecutando
 * como programa comparando `import.meta.url` contra `file://` + la ruta. Este
 * proyecto vive en `…/ENACTUS V4/…`, con un espacio, que la URL codifica como
 * `%20`: la comparación fallaba, el bloque principal no corría y el script
 * **salía 0 sin comprobar nada**. Exactamente el fallo que existe para evitar.
 *
 * Esa regresión concreta la cubren estas pruebas sin hacer nada especial: se
 * invocan los scripts por su ruta real, que YA tiene el espacio. Si alguien
 * vuelve a comparar rutas a mano, los casos que esperan salida 1 se ponen
 * rojos.
 *
 * El `aws` que ven los scripts es falso: se antepone al PATH un ejecutable que
 * responde el escenario que pide cada caso. Así se puede montar «la
 * integración apunta a la función sin cualificar» sin tocar AWS.
 */

const RAIZ = resolve(__dirname, '..');
const temporales: string[] = [];

/** Escribe un `aws` de mentira que responde según `escenario`. */
function awsFalso(escenario: Record<string, string | { error: string }>): string {
  const dir = mkdtempSync(join(tmpdir(), 'aws-falso-'));
  temporales.push(dir);
  const ruta = join(dir, 'aws');
  writeFileSync(
    ruta,
    `#!/usr/bin/env node
const respuestas = ${JSON.stringify(escenario)};
// La clave es "<servicio> <operacion>": basta para distinguir cada llamada.
const clave = process.argv[2] + ' ' + process.argv[3];
const r = respuestas[clave];
if (r === undefined) {
  process.stderr.write('el escenario no cubre: ' + clave + '\\n');
  process.exit(70);
}
if (typeof r === 'object' && r.error) {
  process.stderr.write(r.error + '\\n');
  process.exit(255);
}
process.stdout.write(String(r) + '\\n');
`,
    'utf8',
  );
  chmodSync(ruta, 0o755);
  return dir;
}

interface Salida {
  codigo: number;
  salida: string;
}

async function correr(
  script: string,
  args: string[],
  escenario: Record<string, string | { error: string }>,
): Promise<Salida> {
  const dir = awsFalso(escenario);
  try {
    const { stdout, stderr } = await ejecutar(
      process.execPath,
      [join(RAIZ, 'scripts', script), ...args],
      { env: { ...process.env, PATH: `${dir}:${process.env.PATH ?? ''}` } },
    );
    return { codigo: 0, salida: stdout + stderr };
  } catch (error) {
    const e = error as { code?: number; stdout?: string; stderr?: string };
    return { codigo: e.code ?? -1, salida: (e.stdout ?? '') + (e.stderr ?? '') };
  }
}

const ARN_FUNCION = 'arn:aws:lambda:us-east-1:158151706149:function:enactus-api-prod';
const ARGS_ROLLBACK = ['--api-id', 'qocz5bt4qa', '--funcion', 'enactus-api-prod'];

/** El escenario sano, del que cada caso se desvía en una sola cosa. */
const SANO = {
  'lambda get-alias': '7',
  'apigatewayv2 get-integrations': `${ARN_FUNCION}:vivo`,
  'lambda list-versions-by-function': '6\t7',
};

afterAll(async () => {
  const { rm } = await import('node:fs/promises');
  await Promise.all(temporales.map((d) => rm(d, { recursive: true, force: true })));
});

describe('verificar-rollback.mjs se pone rojo cuando el rollback no sirve', () => {
  it('sale 0 cuando todo está conectado', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, SANO);
    expect(r.salida).toContain('rollback conectado');
    expect(r.codigo).toBe(0);
  });

  // El fallo real que estuvo en produccion: alias creado, permiso puesto, y
  // API Gateway entrando por la funcion sin cualificar. Mover el alias no
  // cambiaba nada y el pipeline reportaba exito.
  it('sale 1 si API Gateway no entra por el alias', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, {
      ...SANO,
      'apigatewayv2 get-integrations': ARN_FUNCION,
    });
    expect(r.codigo).toBe(1);
    expect(r.salida).toContain('NO ESTÁ CONECTADO');
    // Y tiene que decir como arreglarlo, no solo que esta mal.
    expect(r.salida).toContain('update-integration');
  });

  it('sale 1 si no existe el alias', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, {
      ...SANO,
      'lambda get-alias': { error: 'ResourceNotFoundException: Alias not found' },
    });
    expect(r.codigo).toBe(1);
    expect(r.salida).toContain('no tiene alias');
  });

  // $LATEST cambia con cada despliegue: no es un sitio al que volver.
  it('sale 1 si el alias apunta a $LATEST', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, {
      ...SANO,
      'lambda get-alias': '$LATEST',
    });
    expect(r.codigo).toBe(1);
    expect(r.salida).toContain('$LATEST');
  });

  // No poder comprobarlo NO es lo mismo que estar bien. Si esto saliera 0,
  // un fallo de red o de permisos se veria como un sistema sano.
  it('sale 1 si no puede consultar a AWS', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, {
      ...SANO,
      'apigatewayv2 get-integrations': { error: 'AccessDeniedException' },
    });
    expect(r.codigo).toBe(1);
  });

  it('avisa cuando solo hay una versión publicada, sin fallar por eso', async () => {
    const r = await correr('verificar-rollback.mjs', ARGS_ROLLBACK, {
      ...SANO,
      'lambda list-versions-by-function': '1',
    });
    expect(r.codigo).toBe(0);
    expect(r.salida).toContain('solo hay 1 versión publicada');
  });
});

describe('fijar-concurrencia.mjs aplica lo alcanzable y lo dice', () => {
  const ARGS = ['--funcion', 'enactus-api-prod', '--objetivo', '40'];

  // El estado de hoy: tope de cuenta 10 y minimo sin reservar 10 -> cero.
  it('no falla el despliegue cuando la cuenta no permite reservar nada', async () => {
    const r = await correr('fijar-concurrencia.mjs', ARGS, {
      'lambda get-account-settings':
        '{"ConcurrentExecutions":10,"UnreservedConcurrentExecutions":10}',
      'lambda get-function-concurrency': 'None',
    });
    expect(r.codigo).toBe(0);
    expect(r.salida).toContain('alcanzable hoy           0');
    // Que no falle no puede significar que pase en silencio.
    expect(r.salida).toContain('POR DEBAJO del objetivo');
  });

  it('aplica el objetivo entero cuando la cuota ya está aprobada', async () => {
    const r = await correr('fijar-concurrencia.mjs', ARGS, {
      'lambda get-account-settings':
        '{"ConcurrentExecutions":1000,"UnreservedConcurrentExecutions":1000}',
      'lambda get-function-concurrency': 'None',
      'lambda put-function-concurrency': '{"ReservedConcurrentExecutions":40}',
    });
    expect(r.codigo).toBe(0);
    expect(r.salida).toContain('aplicado                 40');
    expect(r.salida).not.toContain('POR DEBAJO');
  });

  // El caso intermedio, que es donde un calculo mal hecho se nota: hay hueco,
  // pero no el suficiente. 25 sin reservar - 10 de minimo = 15.
  it('se queda en lo que cabe cuando el hueco es parcial', async () => {
    const r = await correr('fijar-concurrencia.mjs', ARGS, {
      'lambda get-account-settings':
        '{"ConcurrentExecutions":50,"UnreservedConcurrentExecutions":25}',
      'lambda get-function-concurrency': 'None',
      'lambda put-function-concurrency': '{"ReservedConcurrentExecutions":15}',
    });
    expect(r.codigo).toBe(0);
    expect(r.salida).toContain('alcanzable hoy           15');
    expect(r.salida).toContain('POR DEBAJO del objetivo');
  });

  // Lo ya reservado por esta funcion vuelve al bolsillo comun al cambiarlo,
  // asi que suma. Sin esto, un segundo despliegue calcularia de menos.
  it('cuenta lo que la propia función ya tenía reservado', async () => {
    const r = await correr('fijar-concurrencia.mjs', ARGS, {
      'lambda get-account-settings':
        '{"ConcurrentExecutions":50,"UnreservedConcurrentExecutions":10}',
      'lambda get-function-concurrency': '30',
      'lambda put-function-concurrency': '{"ReservedConcurrentExecutions":30}',
    });
    expect(r.codigo).toBe(0);
    // 10 sin reservar + 30 propias - 10 de minimo = 30.
    expect(r.salida).toContain('alcanzable hoy           30');
  });
});
