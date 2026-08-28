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
  },
});
