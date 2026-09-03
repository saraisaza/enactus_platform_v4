import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['node_modules/**', 'dist/**', 'drizzle/**',
      // Artefacto de despliegue: JS suelto que se empaqueta y se sube a
      // Lambda, fuera del proyecto TypeScript a propósito.
      'infra/lambda-admin/**',
      // Salida de esbuild: código generado, no fuente.
      'dist-lambda/**',
      'dist-tareas/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        // `eslint.config.js` no está en el `include` del tsconfig (es .js), así
        // que se le permite el proyecto por defecto en vez de excluirlo del
        // lint: es código y también tiene que revisarse.
        projectService: { allowDefaultProject: ['eslint.config.js'] },
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // `any` está prohibido por el prompt: silenciar TypeScript con `any` es
      // exactamente el workaround que no queremos. Error, no warning.
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // Un catch vacío es el otro workaround prohibido.
      'no-empty': ['error', { allowEmptyCatch: false }],
      eqeqeq: ['error', 'always', { null: 'ignore' }],
    },
  },
);
