import js from "@eslint/js"
import tseslint from "typescript-eslint"

export default tseslint.config(
  { ignores: ["app/frontend/images", "app/frontend/fonts"] },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    // ArtWorker stands for both the real Worker (its listener takes a MessageEvent) and a test fake
    // (its listener takes an unknown event); no concrete event type is assignable from both.
    files: ["app/frontend/lib/card_art/renderer.ts"],
    rules: { "@typescript-eslint/no-explicit-any": "off" },
  },
)
