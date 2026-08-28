import { serve } from '@hono/node-server';

import { createApp } from './app';
import { env } from './env';

/**
 * Servidor local de desarrollo. En AWS no se usa: ahí entra por el adaptador
 * Lambda (`src/lambda.ts`), que envuelve la misma app.
 */
const app = createApp();

serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  console.log(`API escuchando en http://localhost:${info.port}`);
});
