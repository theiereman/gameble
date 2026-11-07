#!/usr/bin/env node
// Exports the five feed reaction icons (thumb, heart, GG, wow, middle
// finger) as PNGs in app/frontend/images/reactions/.
//
// Each icon is a vector drawing in sources/<name>.svg, inspired by its emoji
// and drawn by hand: a lit side, a shaded side and an outline tinted from its
// colour. The script renders it
// with resvg at SUPERSAMPLE times the icon's size, then pixelates it with
// pixelcrush, the filter of the card art, to SIZE × SIZE in COLOURS colours.
// The app shows each pixel at 1 CSS px.
//
//   node script/reaction_icons/export.mjs            # writes the files that changed
//   node script/reaction_icons/export.mjs --check    # exits 1 when a file differs or is stray
//   either of them with --out <dir>                  # another folder than app/frontend/images/reactions
//
// The output is deterministic: running it again changes no file. PNGs are
// compared by their decoded pixels, never their compressed bytes, so another
// zlib build cannot fail the check.
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs"
import { basename, dirname, join, relative, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { deflateSync, inflateSync } from "node:zlib"
import { Resvg } from "@resvg/resvg-js"
import { filter } from "pixelcrush"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "../..")
const SOURCES = join(here, "sources")
const SIZE = 20
const SUPERSAMPLE = 16
const COLOURS = 14

// ---------------------------------------------------------------------------
// Rendering.

// resvg gives premultiplied RGBA; pixelcrush weighs straight RGB by alpha.
function unpremultiply(rgba) {
  const straight = Buffer.from(rgba)
  for (let i = 0; i < straight.length; i += 4) {
    const alpha = straight[i + 3]
    if (alpha === 0 || alpha === 255) continue
    for (let c = 0; c < 3; c++) straight[i + c] = Math.min(255, Math.round((straight[i + c] * 255) / alpha))
  }
  return straight
}

function rasterise(svg) {
  const side = SIZE * SUPERSAMPLE
  const rendered = new Resvg(svg, { fitTo: { mode: "width", value: side }, font: { loadSystemFonts: false } }).render()
  if (rendered.width !== side || rendered.height !== side) throw new Error(`rendered at ${rendered.width} × ${rendered.height}, not ${side} × ${side}: the source must be square`)
  const rgba = unpremultiply(rendered.pixels)
  return { width: side, height: side, data: new Uint8ClampedArray(rgba.buffer, rgba.byteOffset, rgba.length) }
}

function icon(svg) {
  const { pixels } = filter(rasterise(svg), { width: SIZE, height: SIZE, colors: COLOURS, crop: "none" })
  return { width: pixels.width, height: pixels.height, rgba: Buffer.from(pixels.data.buffer, pixels.data.byteOffset, pixels.data.length) }
}

const files = new Map(
  readdirSync(SOURCES)
    .filter((file) => file.endsWith(".svg"))
    .sort()
    .map((file) => [`${basename(file, ".svg")}.png`, icon(readFileSync(join(SOURCES, file), "utf8"))]),
)

// ---------------------------------------------------------------------------
// PNG: RGBA, 8 bits, filter 0 on every row, one zlib stream.

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  return c >>> 0
})
function crc32(buf) {
  let c = 0xffffffff
  for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}
function pngChunk(type, data) {
  const head = Buffer.alloc(8)
  head.writeUInt32BE(data.length, 0)
  head.write(type, 4, "latin1")
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0)
  return Buffer.concat([head, data, crc])
}
function encodePng({ width, height, rgba }) {
  const stride = width * 4
  const raw = Buffer.alloc((stride + 1) * height)
  for (let y = 0; y < height; y++) rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride)
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr.set([8, 6, 0, 0, 0], 8) // 8 bits, RGBA, deflate, adaptive filtering, no interlace
  return Buffer.concat([PNG_SIGNATURE, pngChunk("IHDR", ihdr), pngChunk("IDAT", deflateSync(raw, { level: 9 })), pngChunk("IEND", Buffer.alloc(0))])
}
// Decodes an RGBA 8-bit non-interlaced PNG to its pixels, whatever its zlib
// build or row filters; anything else (or a broken file) gives null.
function decodePng(buf) {
  try {
    if (!buf.subarray(0, 8).equals(PNG_SIGNATURE)) return null
    let pos = 8, width, height
    const idat = []
    while (pos < buf.length) {
      const length = buf.readUInt32BE(pos)
      const type = buf.toString("latin1", pos + 4, pos + 8)
      const data = buf.subarray(pos + 8, pos + 8 + length)
      if (type === "IHDR") {
        width = data.readUInt32BE(0)
        height = data.readUInt32BE(4)
        if (data[8] !== 8 || data[9] !== 6 || data[12] !== 0) return null
      } else if (type === "IDAT") idat.push(data)
      else if (type === "IEND") break
      pos += 12 + length
    }
    const raw = inflateSync(Buffer.concat(idat))
    const stride = width * 4
    if (raw.length !== (stride + 1) * height) return null
    const rgba = Buffer.alloc(stride * height)
    for (let y = 0; y < height; y++) {
      const rowFilter = raw[y * (stride + 1)]
      for (let i = 0; i < stride; i++) {
        const v = raw[y * (stride + 1) + 1 + i]
        const a = i >= 4 ? rgba[y * stride + i - 4] : 0
        const b = y > 0 ? rgba[(y - 1) * stride + i] : 0
        const c = i >= 4 && y > 0 ? rgba[(y - 1) * stride + i - 4] : 0
        let pred
        if (rowFilter === 0) pred = 0
        else if (rowFilter === 1) pred = a
        else if (rowFilter === 2) pred = b
        else if (rowFilter === 3) pred = (a + b) >> 1
        else if (rowFilter === 4) {
          const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c)
          pred = pa <= pb && pa <= pc ? a : pb <= pc ? b : c
        } else return null
        rgba[y * stride + i] = (v + pred) & 0xff
      }
    }
    return { width, height, rgba }
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Command line.

const USAGE = "usage: node script/reaction_icons/export.mjs [--check] [--out <dir>]"
const args = process.argv.slice(2)
function option(name) {
  const at = args.indexOf(name)
  if (at === -1) return undefined
  const value = args[at + 1]
  if (!value || value.startsWith("--")) {
    console.error(`${name} needs a path.\n${USAGE}`)
    process.exit(1)
  }
  return value
}
const out = resolve(option("--out") ?? join(root, "app/frontend/images/reactions"))
const shown = relative(root, out).startsWith("..") ? out : relative(root, out)
const check = args.includes("--check")

const samePixels = (a, b) => a.width === b.width && a.height === b.height && a.rgba.equals(b.rgba)
function upToDate(file, content) {
  const path = join(out, file)
  if (!existsSync(path)) return false
  const decoded = decodePng(readFileSync(path))
  return decoded !== null && samePixels(decoded, content)
}
function failWhenStale() {
  const differing = [...files].filter(([file, content]) => !upToDate(file, content)).map(([file]) => file)
  const stray = existsSync(out) ? readdirSync(out).filter((file) => !files.has(file)) : []
  if (!differing.length && !stray.length) return
  for (const file of differing) console.error(`differs: ${join(shown, file)}`)
  for (const file of stray) console.error(`not exported: ${join(shown, file)}`)
  console.error("Run node script/reaction_icons/export.mjs and commit the result.")
  process.exit(1)
}

if (check) {
  failWhenStale()
  console.log(`${files.size} reaction icons up to date`)
} else {
  mkdirSync(out, { recursive: true })
  let written = 0
  for (const [file, content] of files) {
    if (upToDate(file, content)) continue
    writeFileSync(join(out, file), encodePng(content))
    written++
  }
  console.log(`${files.size} reaction icons in ${shown}/ (${written} written)`)
}
