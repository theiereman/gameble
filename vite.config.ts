import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    react(),
  ],
  // pixel-art-filter starts its worker as a module
  // (new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })).
  worker: {
    format: 'es',
  },
})
