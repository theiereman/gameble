#!/usr/bin/env node
// Generates the hand-drawn pixel parts of the card (DESIGN.md: Card back,
// Rarity seal, Dust, Card face marks) as pixel-rect SVGs in
// app/frontend/images/card/, from the mockups' own drawing code: the scripts
// of mockups/card-backs.html and mockups/card-face.html run here against a
// pixel sink instead of a canvas. Both card renderers (CardComponent and
// Card.tsx) reference the files through Vite asset URLs; the final art can
// later replace them under the same names.
//
//   node script/card_art/generate.mjs
//
// Writes:
// - back-<rarity>.svg: one back per tier, 80 × 120 art pixels, without its
//   seal and dust (the legendary's sparkles stay on its back);
// - dust-<1..4>.svg: the dust overlay of each level, semi-transparent;
// - sprite.svg: <symbol>s for the five seals (seal-<rarity>, card-sized
//   viewBox so a seal sits in the medallion when drawn over the whole back),
//   the season seal (season-seal[-wide], wide for two digits)
//   and the digit and letter glyphs (glyph-<char>, 5 × 5, drawn in
//   currentColor, centred in a fixed advance).
//
// The output is deterministic: running it again changes no file.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const mockups = join(root, "_bmad-output/initiative-gameble/ux-gameble/mockups")
const out = join(root, "app/frontend/images/card")

const RARITIES = ["steel", "emerald", "sapphire", "amethyst", "gold"]

// A canvas stand-in: an RGBA float buffer that composites fillRect calls
// (source-over, globalAlpha) pixel by pixel.
class PixelSink {
  constructor(width, height) {
    this.width = width
    this.height = height
    this.data = new Float64Array(width * height * 4)
    this.fillStyle = "#000000"
    this.globalAlpha = 1
  }

  fillRect(x, y, w, h) {
    const [r, g, b] = rgb(this.fillStyle)
    const a = this.globalAlpha
    const x0 = Math.max(0, Math.floor(x)), y0 = Math.max(0, Math.floor(y))
    const x1 = Math.min(this.width, Math.floor(x + w)), y1 = Math.min(this.height, Math.floor(y + h))
    for (let py = y0; py < y1; py++) for (let px = x0; px < x1; px++) {
      const i = (py * this.width + px) * 4, da = this.data[i + 3], oa = a + da * (1 - a)
      for (const [k, c] of [[0, r], [1, g], [2, b]]) this.data[i + k] = oa ? (c * a + this.data[i + k] * da * (1 - a)) / oa : 0
      this.data[i + 3] = oa
    }
  }

  // The rest of CanvasRenderingContext2D the mockups touch, as no-ops.
  getImageData() { return { data: [] } }
  putImageData() {}
  drawImage() {}

  get(x, y) {
    const i = (y * this.width + x) * 4
    return [this.data[i], this.data[i + 1], this.data[i + 2], this.data[i + 3]]
  }

  set(x, y, [r, g, b, a]) {
    const i = (y * this.width + x) * 4
    this.data.set([r, g, b, a], i)
  }

  clear(x, y) { this.set(x, y, [0, 0, 0, 0]) }
}

function rgb(hex) {
  const n = parseInt(hex.slice(1), 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

// Runs a mockup's last <script> with a stub DOM and returns the names it lists.
function runMockup(file, names) {
  const html = readFileSync(join(mockups, file), "utf8")
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  const source = scripts.at(-1)[1]
  const element = () => ({ style: {}, append() {}, appendChild() {}, set textContent(_) {}, set className(_) {},
    getContext: () => new PixelSink(1, 1) })
  const document = { createElement: element, getElementById: element }
  const window = { matchMedia: () => ({ matches: true }) }
  class Image { set src(_) {} }
  // eslint-disable-next-line no-new-func
  return new Function("document", "window", "Image", `${source}\nreturn { ${names.join(", ")} }`)(document, window, Image)
}

// The first direction's parchment tones, recoloured to DESIGN.md's text
// tones (story 8.1) until the card faces and backs are redrawn.
const RECOLOUR = { "#e2d1ad": "#c7d5e0", "#f4ead2": "#e6eef5" }

// A pixel-rect SVG: one <path> per colour, made of rectangles merged across
// rows. Alpha is kept to two decimals.
function pixelSvg(sink, { symbol } = {}) {
  const { width, height } = sink
  const key = ([r, g, b, a]) => {
    const alpha = Math.round(a * 100) / 100
    if (alpha <= 0) return null
    const raw = "#" + [r, g, b].map((c) => Math.round(c).toString(16).padStart(2, "0")).join("")
    const hex = RECOLOUR[raw] ?? raw
    return alpha >= 1 ? hex : `${hex}/${alpha}`
  }
  // Runs per row, then rectangles grown downwards while the run repeats.
  const rows = []
  for (let y = 0; y < height; y++) {
    const runs = []
    let x = 0
    while (x < width) {
      const k = key(sink.get(x, y))
      let end = x + 1
      while (end < width && key(sink.get(end, y)) === k) end++
      if (k) runs.push({ x, w: end - x, k })
      x = end
    }
    rows.push(runs)
  }
  const used = rows.map((runs) => runs.map(() => false))
  const paths = new Map()
  rows.forEach((runs, y) => runs.forEach((run, i) => {
    if (used[y][i]) return
    let h = 1
    for (let yy = y + 1; yy < height; yy++) {
      const j = rows[yy].findIndex((other, jj) => !used[yy][jj] && other.x === run.x && other.w === run.w && other.k === run.k)
      if (j < 0) break
      used[yy][j] = true
      h++
    }
    if (!paths.has(run.k)) paths.set(run.k, [])
    paths.get(run.k).push(`M${run.x} ${y}h${run.w}v${h}h-${run.w}z`)
  }))
  const body = [...paths.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([k, d]) => {
    const [fill, alpha] = k.split("/")
    return `<path fill="${fill}"${alpha ? ` fill-opacity="${alpha}"` : ""} d="${d.join("")}"/>`
  }).join("")
  if (symbol) return `<symbol id="${symbol}" viewBox="0 0 ${width} ${height}">${body}</symbol>`
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" shape-rendering="crispEdges">${body}</svg>\n`
}

// ---- Backs, seals and dust: mockups/card-backs.html ----

const backs = runMockup("card-backs.html", ["W", "H", "CX", "CY", "BRASS", "GOLD", "SETS", "tools", "base", "corners", "topBottom", "strap", "medallion", "seal", "dust"])
const { W, H } = backs
// The mockup's choice per tier (card-backs.html, `pick`).
const pick = (tier) => (tier === 4 ? { top: 2, corner: 1, strap: 0, pat: 0 } : { top: 2, corner: 2, strap: 2, pat: 0 })
// The legendary seal also scatters sparkles over the back: a plus around each
// of the points `seal()` lists. Those pixels belong to the back; every other
// seal pixel (the amethyst's ribbon included) stays in the seal.
const SPARKLE_POINTS = JSON.parse(backs.seal.toString().match(/for \(const \[x, y\] of (\[\[[\d, \[\]]*\]\])\)/)[1])
const sparkle = new Set(SPARKLE_POINTS.flatMap(([x, y]) => [[x, y], [x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]].map(([px, py]) => `${px},${py}`)))

const seals = []
mkdirSync(out, { recursive: true })
RARITIES.forEach((rarity, tier) => {
  const legendary = tier === 4, M = legendary ? backs.GOLD : backs.BRASS, S = backs.SETS[0][tier], o = pick(tier)
  const back = new PixelSink(W, H), t = backs.tools(back)
  backs.base(t, M, o.pat, legendary)
  backs.corners(t, M, o.corner)
  backs.topBottom(t, M, o.top, S)
  backs.strap(t, M, o.strap)
  backs.medallion(t, M, legendary)

  const seal = new PixelSink(W, H)
  backs.seal(backs.tools(seal), tier, S)
  if (legendary) for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const p = seal.get(x, y)
    if (p[3] > 0 && sparkle.has(`${x},${y}`)) {
      back.set(x, y, p)
      seal.clear(x, y)
    }
  }
  writeFileSync(join(out, `back-${rarity}.svg`), pixelSvg(back))
  seals.push(pixelSvg(seal, { symbol: `seal-${rarity}` }))
})

for (let level = 1; level <= 4; level++) {
  const sink = new PixelSink(W, H)
  backs.dust(backs.tools(sink), level)
  writeFileSync(join(out, `dust-${level}.svg`), pixelSvg(sink))
}

// ---- Season seal and glyphs: mockups/card-face.html ----

const face = runMockup("card-face.html", ["drawFace", "SIZES", "FONT", "C"])
// The face draws its season seal as a rust ring around "S1"; it is the only
// rust on a face without art. The large card's seal (radius 8) serves both
// sizes: the small one's (radius 7) is one pixel too narrow for "S" and a
// digit at a fixed glyph advance.
const RUST = rgb(face.C.rust), SURFACE = [...rgb(face.C.surface), 1]
// Widened by this many columns for a two-digit season (three glyph advances).
const WIDE = 8

const seasonSeals = []
{
  const mockSize = "big", r = 8
  const { W: fw, H: fh } = face.SIZES[mockSize]
  const sink = new PixelSink(fw, fh)
  face.drawFace(sink, { game: { title: "X", pub: "X", year: 2000 }, tier: 0, variant: "A", size: mockSize }, null)
  let minX = fw, maxX = 0, minY = fh, maxY = 0
  for (let y = 0; y < fh; y++) for (let x = 0; x < fw; x++) {
    const [pr, pg, pb] = sink.get(x, y)
    if (Math.round(pr) === RUST[0] && Math.round(pg) === RUST[1] && Math.round(pb) === RUST[2]) {
      minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y)
    }
  }
  // The rust ring is symmetric about the seal's centre; the ink ring is one
  // pixel outside it.
  const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
  const x0 = minX - 1, y0 = minY - 1, sw = maxX - minX + 3, sh = maxY - minY + 3
  const round = new PixelSink(sw, sh)
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
    const d = Math.hypot(x0 + x - cx, y0 + y - cy)
    if (d > r + 0.6) continue
    // Inside the rust ring, the mockup's "S1" is cleared to parchment: the
    // season is written with the glyphs.
    round.set(x, y, d <= r - 2 ? SURFACE : sink.get(x0 + x, y0 + y))
  }
  seasonSeals.push(pixelSvg(round, { symbol: "season-seal" }))

  // The wide seal repeats the middle column.
  const wide = new PixelSink(sw + WIDE, sh), mid = Math.floor(sw / 2)
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw + WIDE; x++) {
    const from = x <= mid ? x : x < mid + WIDE ? mid : x - WIDE
    wide.set(x, y, round.get(from, y))
  }
  seasonSeals.push(pixelSvg(wide, { symbol: "season-seal-wide" }))
}

const GLYPH = 5
const glyphs = Object.keys(face.FONT).filter((ch) => /^[0-9A-Z]$/.test(ch)).sort().map((ch) => {
  const rows = face.FONT[ch], offset = Math.floor((GLYPH - rows[0].length) / 2)
  let d = ""
  rows.forEach((row, y) => { for (let x = 0; x < row.length; x++) if (row[x] === "#") d += `M${x + offset} ${y}h1v1h-1z` })
  return `<symbol id="glyph-${ch}" viewBox="0 0 ${GLYPH} ${GLYPH}"><path fill="currentColor" d="${d}"/></symbol>`
})

writeFileSync(join(out, "sprite.svg"),
  `<svg xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">${[...seals, ...seasonSeals, ...glyphs].join("")}</svg>\n`)

console.log(`Card art written to ${out}`)
