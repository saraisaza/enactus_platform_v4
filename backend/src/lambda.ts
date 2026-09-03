import { cargarSecretos } from './lib/secretos';

/**
 * Punto de entrada en AWS Lambda.
 *
 * **El orden de estas líneas no es estético, es la única forma de que
 * funcione.** `env.ts` valida `process.env` en el momento en que se importa, y
 * `db/client.ts` abre el pool en el suyo. Si se importaran arriba —como
 * importa uno por costumbre— se ejecutarían antes de que la configuración
 * exista, y la Lambda arrancaría sin `JWT_SECRET` y sin saber a qué base
 * conectarse.
 *
 * De ahí el `await` a nivel de módulo y los `import()` dinámicos: primero se
 * trae la configuración de S3, después se construye la aplicación.
 *
 * Todo esto corre **una vez por contenedor**, no por petición: es el arranque
 * en frío. Las invocaciones tibias reutilizan el módulo ya cargado, con su
 * pool abierto.
 */
await cargarSecretos();

const { handle } = await import('hono/aws-lambda');
const { createApp } = await import('./app');

export const handler = handle(createApp());
