import { defineConfig } from 'vitest/config'

// The root vite.config.ts loads RubyPlugin, which roots Vite in app/frontend.
// The application's pure TypeScript modules (no DOM, no asset imports) are
// tested from here, without it.
export default defineConfig({
  test: {
    include: ['app/frontend/**/*.test.ts'],
    environment: 'node',
    // Vitest empties every stylesheet a test imports, raw ones included, unless listed here.
    css: { include: [/styles\/(card|card-detail|card-rarity-effects|booster|booster-layouts|collection|hub|shell|tokens)\.css/] },
  },
})
