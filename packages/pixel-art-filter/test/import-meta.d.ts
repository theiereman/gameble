// The one Vite feature the tests use, typed without pulling in vite/client.
interface ImportMeta {
  glob(pattern: string, options: { query: "?raw"; import: "default"; eager: true }): Record<string, string>
}
