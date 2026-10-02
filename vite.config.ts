import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    react(),
  ],
  build: {
    // The card's pixel parts (images/card/) are never inlined: the sprite's
    // symbols are addressed by URL fragment, and the server (vite_asset_path)
    // and the React Card must write the same URL.
    assetsInlineLimit: (file) => (file.includes('/images/card/') ? false : undefined),
  },
})
