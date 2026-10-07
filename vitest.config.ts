import { defineConfig } from 'vitest/config'

// The root vite.config.ts loads RubyPlugin, which roots Vite in app/frontend.
// The application's pure TypeScript modules (no DOM, no asset imports) are
// tested from here, without it.
export default defineConfig({
  test: {
    include: ['app/frontend/**/*.test.ts'],
    environment: 'node',
  },
})
