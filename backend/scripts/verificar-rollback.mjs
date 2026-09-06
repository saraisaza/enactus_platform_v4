#!/usr/bin/env node
/**
 * ¿El rollback de este entorno existe de verdad?
 *
 * El rollback consiste en mover el alias `vivo` a la versión anterior. Eso
 * solo cambia algo si **API Gateway está integrado contra el alias**. Si la
 * integración apunta a la función sin cualificar, el tráfico entra por
 * `$LATEST`, mover el alias no hace nada, y el paso de rollback del pipeline
 * corre, no surte efecto y **reporta éxito**.
 *
 * Un mecanismo de seguridad que se ejecuta, no hace nada y da verde es peor
 * que no tenerlo: se descubre que no existía durante el incidente, que es
 * cuando ya no hay margen. Por eso esto falla ruidosamente y nunca degrada a
 * aviso — tampoco cuando no se puede comprobar. **No poder comprobarlo no es
 * lo mismo que estar bien.**
 *
 * Se usa de dos formas, contra la misma comprobación para que no puedan
 * divergir:
 *
 *   - como paso del pipeline, ANTES de tocar producción:
 *       node scripts/verificar-rollback.mjs --api-id qocz5bt4qa --funcion enactus-api-prod
 *   - dentro de las pruebas de humo, importando `verificarRollback()`.
 */
import { execFile } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';

const ejecutar = promisify(execFile);

/** Se lanza cuando el rollback no está conectado. Lleva el arreglo adentro. */
export class RollbackDesconectado extends Error {
  constructor(funcion, titulo, detalle, arreglo) {
    super(`${funcion}: ${titulo} ${detalle.replace(/\n/g, ' ')}`);
    this.name = 'RollbackDesconectado';
    this.funcion = funcion;
    this.titulo = titulo;
    this.detalle = detalle;
    this.arreglo = arreglo;
  }

  /** El texto largo, para cuando hay sitio para imprimirlo entero. */
  informe() {
    return [
      '',
      `  EL ROLLBACK DE ${this.funcion.toUpperCase()} NO ESTÁ CONECTADO`,
      '',
      `  ${this.titulo}`,
      ...this.detalle.split('\n').map((l) => `  ${l}`),
      '',
      '  Consecuencia: el paso de rollback del pipeline se ejecutaría,',
      '  no cambiaría a dónde llega el tráfico, y daría éxito.',
      '',
      '  Para arreglarlo:',
      '',
      ...this.arreglo.split('\n').map((l) => `    ${l}`),
      '',
    ].join('\n');
  }
}

async function aws(...parametros) {
  const { stdout } = await ejecutar('aws', parametros, { maxBuffer: 8 * 1024 * 1024 });
  return stdout.trim();
}

/**
 * Comprueba que el rollback está conectado. Devuelve un resumen o lanza
 * `RollbackDesconectado`.
 */
export async function verificarRollback({ apiId, funcion, alias = 'vivo', cuenta = '158151706149' }) {
  const repunte =
    `aws apigatewayv2 update-integration --api-id ${apiId} \\\n` +
    `  --integration-id "$(aws apigatewayv2 get-integrations --api-id ${apiId} \\\n` +
    `      --query 'Items[0].IntegrationId' --output text)" \\\n` +
    `  --integration-uri arn:aws:lambda:us-east-1:${cuenta}:function:${funcion}:${alias}`;

  // 1. El alias tiene que existir.
  let versionDelAlias;
  try {
    versionDelAlias = await aws(
      'lambda', 'get-alias', '--function-name', funcion,
      '--name', alias, '--query', 'FunctionVersion', '--output', 'text',
    );
  } catch (error) {
    throw new RollbackDesconectado(
      funcion,
      `La función no tiene alias «${alias}».`,
      String(error.stderr ?? error.message).split('\n')[0],
      `aws lambda publish-version --function-name ${funcion}\n` +
        `aws lambda create-alias --function-name ${funcion} --name ${alias} --function-version <N>\n` +
        repunte,
    );
  }

  // 2. Y tiene que apuntar a una versión publicada, no a $LATEST.
  if (versionDelAlias === '$LATEST') {
    throw new RollbackDesconectado(
      funcion,
      `El alias «${alias}» apunta a $LATEST.`,
      'No hay ninguna versión fija a la que volver: $LATEST cambia con cada despliegue.',
      `aws lambda publish-version --function-name ${funcion}\n` +
        `aws lambda update-alias --function-name ${funcion} --name ${alias} --function-version <N>`,
    );
  }

  // 3. Y API Gateway tiene que entrar POR el alias. Esta es la que faltaba.
  let uri;
  try {
    uri = await aws(
      'apigatewayv2', 'get-integrations', '--api-id', apiId,
      '--query', 'Items[0].IntegrationUri', '--output', 'text',
    );
  } catch (error) {
    throw new RollbackDesconectado(
      funcion,
      'No se pudo leer la integración de API Gateway.',
      String(error.stderr ?? error.message).split('\n')[0],
      repunte,
    );
  }

  if (!uri.endsWith(`:${alias}`)) {
    throw new RollbackDesconectado(
      funcion,
      `API Gateway ${apiId} no entra por el alias.`,
      `Apunta a  ${uri}\ny debería terminar en  :${alias}`,
      repunte,
    );
  }

  const versiones = (
    await aws(
      'lambda', 'list-versions-by-function', '--function-name', funcion,
      '--query', 'Versions[?Version!=`$LATEST`].Version', '--output', 'text',
    )
  ).split(/\s+/).filter(Boolean);

  return {
    apiId,
    funcion,
    alias,
    version: versionDelAlias,
    versionesPublicadas: versiones.length,
    // En el primer despliegue todavía no hay a dónde volver, y eso es
    // correcto: no es una configuración rota, es una historia corta.
    hayADondeVolver: versiones.length >= 2,
  };
}

// --- Como programa suelto ---------------------------------------------------
// `import.meta.main` no existe en Node 22, así que se compara la ruta del
// módulo con la del proceso. Va por `pathToFileURL` y no por `file://` + la
// ruta: cualquier carácter que haya que escapar —un espacio, sin ir más
// lejos, como el de «ENACTUS V4»— hace que la comparación literal falle, el
// bloque no se ejecute, y el script salga 0 sin haber comprobado nada. Es
// decir, exactamente el fallo que este archivo existe para evitar.
const esPrograma =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (esPrograma) {
  const args = Object.fromEntries(
    process.argv.slice(2).reduce((pares, actual, i, todos) => {
      if (actual.startsWith('--')) pares.push([actual.slice(2), todos[i + 1]]);
      return pares;
    }, []),
  );

  if (!args['api-id'] || !args.funcion) {
    console.error('Uso: verificar-rollback.mjs --api-id <id> --funcion <nombre> [--alias vivo]');
    process.exit(2);
  }

  try {
    const r = await verificarRollback({
      apiId: args['api-id'], funcion: args.funcion, alias: args.alias,
    });
    console.log(`  rollback conectado: ${r.apiId} -> ${r.funcion}:${r.alias} (versión ${r.version})`);
    if (!r.hayADondeVolver) {
      console.log(
        `  aviso: solo hay ${r.versionesPublicadas} versión publicada. Hasta el ` +
          'próximo despliegue no hay ninguna anterior a la que volver.',
      );
    }
    process.exit(0);
  } catch (error) {
    console.error(error instanceof RollbackDesconectado ? error.informe() : `\n  ${error.message}\n`);
    process.exit(1);
  }
}
