import { defineConfig } from 'vitest/config'

// The root vite.config.ts loads RubyPlugin, which roots Vite in app/frontend.
// JavaScript packages are tested from here, without it.
export default defineConfig({
  test: {
    include: ['packages/*/test/**/*.test.ts'],
    environment: 'node',
  },
})
