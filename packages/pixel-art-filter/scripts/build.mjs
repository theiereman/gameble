// Builds the package for npm into dist/: compiled JavaScript with type
// declarations, a publishable package.json, the README and the LICENSE.
// Publish with `npm publish dist` (see the README, "Publishing").
import { execFileSync } from "node:child_process"
import { cpSync, existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const dist = join(root, "dist")
const source = JSON.parse(readFileSync(join(root, "package.json"), "utf8"))

rmSync(dist, { recursive: true, force: true })
execFileSync("npx", ["tsc", "-p", join(root, "tsconfig.build.json")], { cwd: root, stdio: "inherit" })

// The sources import "./x" without an extension, which a bundler resolves but
// Node and a browser do not: write the extension, and point the worker URL at
// the compiled file.
for (const name of readdirSync(dist)) {
  if (!/\.(js|d\.ts)$/.test(name)) continue
  const file = join(dist, name)
  const text = readFileSync(file, "utf8")
    .replace(/(from\s+["'])(\.\/[^"']+?)(["'])/g, (_, a, path, b) => `${a}${path}.js${b}`)
    .replace(/(import\(\s*["'])(\.\/[^"']+?)(["']\s*\))/g, (_, a, path, b) => `${a}${path}.js${b}`)
    .replace(/new URL\("\.\/worker\.ts", import\.meta\.url\)/g, 'new URL("./worker.js", import.meta.url)')
  writeFileSync(file, text)
}
if (readFileSync(join(dist, "renderer.js"), "utf8").includes("worker.ts")) {
  throw new Error("renderer.js still points at worker.ts")
}

const manifest = {
  name: source.name,
  version: source.version,
  description: source.description,
  license: source.license,
  author: source.author,
  repository: source.repository,
  homepage: source.homepage,
  bugs: source.bugs,
  keywords: source.keywords,
  type: "module",
  sideEffects: false,
  main: "./index.js",
  module: "./index.js",
  types: "./index.d.ts",
  exports: { ".": { types: "./index.d.ts", default: "./index.js" } },
  files: ["*.js", "*.d.ts", "*.map", "README.md", "LICENSE"],
}
for (const key of Object.keys(manifest)) if (manifest[key] === undefined) delete manifest[key]
writeFileSync(join(dist, "package.json"), `${JSON.stringify(manifest, null, 2)}\n`)

for (const name of ["README.md", "LICENSE"]) {
  if (existsSync(join(root, name))) cpSync(join(root, name), join(dist, name))
}
console.log(`built ${source.name}@${source.version} into ${dist}`)
