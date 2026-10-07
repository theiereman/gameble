import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    react(),
  ],
  // The card-art renderer (app/frontend/lib/card_art) starts its worker as a module
  // (new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })).
  worker: {
    format: 'es',
  },
})
