/// <reference types="vitest/config" />
import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    target: 'es2022',
    outDir: 'dist',
    assetsInlineLimit: 100_000_000, // todo inline: el destino es un solo archivo
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        // Un solo chunk. El script de inline de despues lo mete en el HTML.
        manualChunks: undefined,
        inlineDynamicImports: true,
      },
    },
  },
  test: {
    environment: 'node',
    include: ['tests/**/*.spec.ts'],
  },
});
