import { defineConfig } from 'vitest/config'

// The root vite.config.ts loads RubyPlugin, which roots Vite in app/frontend.
// The application's pure TypeScript modules (no DOM, no asset imports) are
// tested from here, without it.
export default defineConfig({
  test: {
    include: ['app/frontend/**/*.test.ts'],
    environment: 'node',
    // Vitest empties every stylesheet a test imports, raw ones included, unless listed here.
    css: { include: [/styles\/(card|card-tilt-effects|card-detail|card-detail-stepping|card-detail-public|card-rarity-effects|booster|booster-canister|booster-effects|booster-celebration|booster-layouts|booster-layouts-tray|collection|collection-set-tiles|collection-filters|collection-grid|hub|hub-daily-sets|hub-responsive|hub-goal|shell|shell-top-bar|shell-status|shell-controls|shell-screens|tokens)\.css/] },
  },
})
