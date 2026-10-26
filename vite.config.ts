import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    RubyPlugin(),
  ],
  build: {
    // A font is always its own file: inlined as a data: URI it would be
    // refused by the Content-Security-Policy's font-src 'self'
    // (config/initializers/content_security_policy.rb). Other assets keep
    // Vite's default limit.
    assetsInlineLimit: (filePath) => (/\.woff2?$/.test(filePath) ? false : undefined),
  },
  // The card-art renderer (app/frontend/lib/card_art) starts its worker as a module
  // (new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })).
  worker: {
    format: 'es',
  },
})
