import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    // Las pruebas comparten una sola base (`TEST_DATABASE_URL`): en paralelo
    // se pisarían entre sí al migrar y sembrar.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
    env: {
      // `app.request()` no abre socket, así que sin esto no habría ninguna IP
      // y todas las peticiones de la suite compartirían un solo cupo.
      //
      // Declarar un proxy de confianza hace que las pruebas lean la IP de
      // `x-forwarded-for` —como en producción— y permite simular clientes
      // distintos. El caso contrario, `hops=0` ignorando la cabecera, se
      // prueba aparte en `client-ip.test.ts`, que no depende de este valor.
      TRUSTED_PROXY_HOPS: '1',
    },
  },
});
