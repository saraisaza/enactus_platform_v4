#!/usr/bin/env node
/**
 * Fija la `reserved concurrency` de una Lambda **hasta donde la cuenta deje**.
 *
 * El objetivo es 40 en producción y 10 en staging: con `max: 1` conexión por
 * contenedor, eso acota cuántas conexiones puede abrir cada entorno contra una
 * `db.t4g.micro` de 79.
 *
 * Hoy no se puede reservar **nada**. La cuenta tiene un tope total de 10
 * ejecuciones concurrentes —restricción que AWS aplica a cuentas nuevas— y
 * exige dejar 10 sin reservar. 10 menos cualquier cosa es menos de 10, así que
 * hasta `--objetivo 1` es rechazado. Comprobado, no deducido:
 *
 *   InvalidParameterValueException: Specified ReservedConcurrentExecutions for
 *   function decreases account's UnreservedConcurrentExecution below its
 *   minimum value of [10].
 *
 * Por eso este script **no falla** cuando no puede aplicar el objetivo: deja
 * dicho en el log qué pidió, qué consiguió y por qué hay diferencia, y sigue.
 * Un despliegue no debe caerse por una cuota de AWS pendiente — pero tampoco
 * debe pasar en silencio, que es lo que haría un `|| true`.
 *
 *   node scripts/fijar-concurrencia.mjs --funcion enactus-api-prod --objetivo 40
 */
import { execFile } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';

const ejecutar = promisify(execFile);

/** AWS exige que SIEMPRE queden estas sin reservar, en toda la cuenta. */
const MINIMO_SIN_RESERVAR = 10;

async function aws(...parametros) {
  const { stdout } = await ejecutar('aws', parametros, { maxBuffer: 8 * 1024 * 1024 });
  return stdout.trim();
}

export async function fijarConcurrencia({ funcion, objetivo }) {
  const cuenta = JSON.parse(
    await aws('lambda', 'get-account-settings', '--query', 'AccountLimit', '--output', 'json'),
  );

  const actual = await aws(
    'lambda', 'get-function-concurrency', '--function-name', funcion,
    '--query', 'ReservedConcurrentExecutions', '--output', 'text',
  );
  const yaReservado = actual === 'None' ? 0 : Number(actual);

  // Lo que esta funcion puede reservar sin bajar del minimo de la cuenta.
  // Lo que ya tiene reservado vuelve al bolsillo comun al cambiarlo, asi que
  // suma.
  const alcanzable = Math.max(
    0,
    cuenta.UnreservedConcurrentExecutions + yaReservado - MINIMO_SIN_RESERVAR,
  );
  const aAplicar = Math.min(objetivo, alcanzable);

  console.log(`  ${funcion}`);
  console.log(`    tope de la cuenta        ${cuenta.ConcurrentExecutions}`);
  console.log(`    sin reservar ahora       ${cuenta.UnreservedConcurrentExecutions}`);
  console.log(`    reservado por esta       ${yaReservado || 'nada'}`);
  console.log(`    objetivo                 ${objetivo}`);
  console.log(`    alcanzable hoy           ${alcanzable}`);

  if (aAplicar === yaReservado) {
    console.log(`    sin cambios (ya está en ${yaReservado || 'nada'})`);
  } else if (aAplicar === 0) {
    // Quitar una reserva que no existe da error; se salta.
    if (yaReservado > 0) {
      await aws('lambda', 'delete-function-concurrency', '--function-name', funcion);
      console.log('    se retiró la reserva: la cuenta ya no la permite');
    }
  } else {
    await aws(
      'lambda', 'put-function-concurrency', '--function-name', funcion,
      '--reserved-concurrent-executions', String(aAplicar),
    );
    console.log(`    aplicado                 ${aAplicar}`);
  }

  if (aAplicar < objetivo) {
    console.log('');
    console.log(`    AVISO: ${funcion} queda POR DEBAJO del objetivo (${aAplicar} de ${objetivo}).`);
    console.log('    La cuenta tiene un tope total de ' + cuenta.ConcurrentExecutions +
      ' y AWS exige dejar ' + MINIMO_SIN_RESERVAR + ' sin reservar.');
    console.log('    Mientras siga así, producción y staging COMPARTEN ese tope:');
    console.log('    una prueba de carga contra staging puede dejar producción sin');
    console.log('    capacidad. Lo que sí está cerrado por debajo son las conexiones');
    console.log('    a la base (CONNECTION LIMIT por rol). Ver BLOQUEOS_INFRA.md.');
    console.log('');
  }

  return { funcion, objetivo, alcanzable, aplicado: aAplicar, porDebajo: aAplicar < objetivo };
}

const esPrograma =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (esPrograma) {
  const args = Object.fromEntries(
    process.argv.slice(2).reduce((pares, actual, i, todos) => {
      if (actual.startsWith('--')) pares.push([actual.slice(2), todos[i + 1]]);
      return pares;
    }, []),
  );
  if (!args.funcion || !args.objetivo) {
    console.error('Uso: fijar-concurrencia.mjs --funcion <nombre> --objetivo <n>');
    process.exit(2);
  }
  try {
    await fijarConcurrencia({ funcion: args.funcion, objetivo: Number(args.objetivo) });
    // Sale 0 aunque quede por debajo: es una cuota pendiente, no un fallo del
    // despliegue. El aviso de arriba es la señal.
    process.exit(0);
  } catch (error) {
    console.error(`  no se pudo ajustar la concurrencia de ${args.funcion}: ${error.message}`);
    process.exit(1);
  }
}
