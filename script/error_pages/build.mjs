#!/usr/bin/env node
// Builds the assets of the static error pages in public/: copies the fonts,
// their licences and the pixel art they use from app/frontend/ into
// public/errors/, then stamps every asset URL in public/errors.css and
// public/*.html with `?v=<first 8 hex of the file's SHA-256>`. public/ is
// cached for a year, so a changed file needs a new URL.
//
//   node script/error_pages/build.mjs                # writes the files that changed
//   node script/error_pages/build.mjs --check        # exits 1 when a file differs or is stray
//   any of them with --root <dir>                    # another tree than the repository's
//
// The output is deterministic: running it again changes no file.
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { basename, dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const SOURCES = [
  "app/frontend/fonts/vt323-latin-400-normal.woff2",
  "app/frontend/fonts/jetbrains-mono-latin-400-normal.woff2",
  "app/frontend/fonts/jetbrains-mono-latin-700-normal.woff2",
  "app/frontend/fonts/OFL-VT323.txt",
  "app/frontend/fonts/OFL-JetBrainsMono.txt",
  "app/frontend/images/pixel/wordmark.svg",
  "app/frontend/images/pixel/starfield.svg",
]
const COPY_DIR = "public/errors"
const STYLESHEET = "public/errors.css"
const STAMP_LENGTH = 8
// A URL the pages or the stylesheet load, inside quotes or url( ), with or
// without its stamp.
const ASSET_URL = /(["'(])(\/errors(?:\.css|\/[A-Za-z0-9._-]+))(?:\?v=[0-9a-f]*)?(?=["')])/g

const args = process.argv.slice(2)
const check = args.includes("--check")
const rootIndex = args.indexOf("--root")
const root = rootIndex >= 0 ? args[rootIndex + 1] : join(dirname(fileURLToPath(import.meta.url)), "../..")

const built = new Map()

for (const source of SOURCES) {
  built.set(join(COPY_DIR, basename(source)), readFileSync(join(root, source)))
}
built.set(STYLESHEET, stamped(STYLESHEET))
for (const page of readdirSync(join(root, "public")).filter((name) => name.endsWith(".html")).sort()) {
  built.set(join("public", page), stamped(join("public", page)))
}

const copied = existsSync(join(root, COPY_DIR)) ? readdirSync(join(root, COPY_DIR)) : []
const stray = copied
  .map((name) => join(COPY_DIR, name))
  .filter((path) => !built.has(path))
const changed = [...built].filter(([path, content]) => !sameAsDisk(path, content)).map(([path]) => path)

if (check) {
  for (const path of changed) console.error(`differs: ${path}`)
  for (const path of stray) console.error(`stray: ${path}`)
  if (changed.length || stray.length) {
    console.error("Run node script/error_pages/build.mjs")
    process.exit(1)
  }
  console.log(`${built.size} error page files up to date`)
} else {
  mkdirSync(join(root, COPY_DIR), { recursive: true })
  for (const path of changed) writeFileSync(join(root, path), built.get(path))
  for (const path of stray) rmSync(join(root, path), { recursive: true })
  console.log(`${built.size} error page files, ${changed.length} written, ${stray.length} removed`)
}

function stamped(path) {
  const text = readFileSync(join(root, path), "utf8")
  return Buffer.from(text.replace(ASSET_URL, (_match, opening, url) => `${opening}${url}?v=${stamp(url)}`))
}

function stamp(url) {
  const path = join("public", url)
  const content = built.get(path) ?? (existsSync(join(root, path)) ? readFileSync(join(root, path)) : null)
  if (!content) {
    console.error(`missing: ${path}, linked by an error page`)
    process.exit(1)
  }
  return createHash("sha256").update(content).digest("hex").slice(0, STAMP_LENGTH)
}

function sameAsDisk(path, content) {
  const file = join(root, path)
  return existsSync(file) && readFileSync(file).equals(content)
}
