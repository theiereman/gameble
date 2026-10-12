#!/usr/bin/env node
// Exports the interface's pixel art (DESIGN.md: Rarity, Typography's glyphs,
// Chrome, Card backs, Booster canister, Showcase, Avatars; AD-27) as static
// files in app/frontend/images/pixel/.
//
// The icons (story 8.1) are SVG. Each is a character grid, one character per
// art pixel:
//   "."  transparent
//   "c"  currentColor (the icon takes the colour of its text)
//   any other character: the fixed colour its icon's legend gives it.
// One art pixel is 2 CSS px: the viewBox is in art pixels, width and height
// are twice that. Pixels are merged into runs per row and colour, one <path>
// per colour, with crisp edges. `starfield` is the exception: a seeded tile
// of 2px and 4px stars, in CSS px.
//
// The card backs, the canister, the planet and the avatars (story 8.8) are
// PNG at 1x art resolution, drawn by code ported from the prototypes (see
// "Drawn art" below).
//
//   node script/pixel_art/export.mjs                 # writes the files that changed
//   node script/pixel_art/export.mjs --check         # exits 1 when a file differs or is stray
//   node script/pixel_art/export.mjs --sheet <path>  # writes the HTML review sheet
//   any of them with --out <dir>                     # another folder than app/frontend/images/pixel
//
// The output is deterministic: running it again changes no file. PNGs are
// compared by their decoded pixels, never their compressed bytes, so another
// zlib build cannot fail the check.
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs"
import { dirname, join, relative, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { deflateSync, inflateSync } from "node:zlib"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const ART_PIXEL = 2

// DESIGN.md colours used by the fixed-colour icons.
const OUTLINE = "#06090d"
const RARITY = [
  null,
  { b: "#8f98a0", h: "#dfe6ec", l: "#4d5866" }, // 1 Commune
  { b: "#3fcf8e", h: "#b2f7d4", l: "#16684a" }, // 2 Peu commune
  { b: "#66c0f4", h: "#d2efff", l: "#2a6f9a" }, // 3 Rare
  { b: "#b47cff", h: "#ead9ff", l: "#55308f" }, // 4 Épique
  { b: "#f4c542", h: "#fff3c4", l: "#8f5e0a" }, // 5 Légendaire
]

// Rarity silhouettes, 7 × 7: b body, h lit (top) edge, l shaded (bottom)
// edge. They must stay distinct in grayscale (DESIGN.md, Rarity).
const RARITY_SHAPES = {
  // 1: a solid disc.
  1: [
    "..hhh..",
    ".hbbbb.",
    "hbbbbbb",
    "bbbbbbb",
    "bbbbbbl",
    ".bbbbl.",
    "..lll..",
  ],
  // 2: a ring inside a ring.
  2: [
    ".hhhhh.",
    "h.....b",
    "b.hhh.b",
    "b.b.b.b",
    "b.lll.b",
    "b.....l",
    ".lllll.",
  ],
  // 3: a diamond.
  3: [
    "...h...",
    "..hbb..",
    ".hbbbb.",
    "hbbbbbl",
    ".bbbbl.",
    "..bbl..",
    "...l...",
  ],
  // 4: a triangle, point up, on a full base.
  4: [
    "...h...",
    "...b...",
    "..hbb..",
    "..bbb..",
    ".hbbbb.",
    ".bbbbbl",
    "lllllll",
  ],
  // 5: a five-pointed star, two feet.
  5: [
    "...h...",
    "..hbh..",
    "hhbbbhh",
    ".bbbbb.",
    "..bbb..",
    ".bb.bl.",
    ".l...l.",
  ],
}

// The compact rarity set for card faces, 5 × 5 (DESIGN.md, Rarity icon):
// the same five silhouettes, still distinct in grayscale.
const RARITY_COMPACT_SHAPES = {
  // 1: a solid disc.
  1: [
    ".hhh.",
    "hbbbb",
    "bbbbb",
    "bbbbl",
    ".lll.",
  ],
  // 2: a ring around a centre dot.
  2: [
    ".hhh.",
    "h...b",
    "b.b.b",
    "b...l",
    ".lll.",
  ],
  // 3: a diamond.
  3: [
    "..h..",
    ".hbb.",
    "hbbbl",
    ".bbl.",
    "..l..",
  ],
  // 4: a triangle, point up, on a full base.
  4: [
    "..h..",
    ".hbb.",
    ".bbb.",
    "hbbbb",
    "lllll",
  ],
  // 5: a five-pointed star, two feet.
  5: [
    "..h..",
    "hhbhh",
    ".bbb.",
    ".b.l.",
    "l...l",
  ],
}

const WORDMARK_GLYPHS = {
  G: [".######", "#######", "##.....", "##.....", "##..###", "##..###", "##...##", "#######", ".######"],
  A: [".#####.", "#######", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##"],
  M: ["##...##", "###.###", "#######", "##.#.##", "##.#.##", "##...##", "##...##", "##...##", "##...##"],
  E: ["#######", "#######", "##.....", "######.", "######.", "##.....", "##.....", "#######", "#######"],
  B: ["######.", "#######", "##...##", "######.", "######.", "##...##", "##...##", "#######", "######."],
  L: ["##....", "##....", "##....", "##....", "##....", "##....", "##....", "######", "######"],
}
const WORDMARK_SPACING = 3
const GOLD_TIERS = ["#fff3c4", "#f4c542", "#d99a1f", "#8f5e0a"]
const GOLD_LIFTS = ["#ffffff", "#fff3c4", "#ffe08a", "#d99a1f"]
const GOLD_EDGE = "#fff3c4"

function goldTier(y, rows) {
  const t = y / rows
  return t < 0.2 ? 0 : t < 0.52 ? 1 : t < 0.78 ? 2 : 3
}

function setLetters(word) {
  const glyphs = [...word].map((letter) => WORDMARK_GLYPHS[letter])
  const rows = glyphs[0].length
  const lines = Array.from({ length: rows }, (_, y) => glyphs.map((glyph) => glyph[y]).join(".".repeat(WORDMARK_SPACING)))
  return lines.map((line) => [...line].map((cell) => cell === "#"))
}

function goldColours(mask, shineStart = null) {
  const rows = mask.length
  const shines = (x, y) => {
    if (shineStart === null) return false
    const s = x + y - shineStart
    return (s >= 0 && s < 2) || s === 3
  }
  return mask.map((line, y) => line.map((on, x) => {
    if (!on) return null
    const tier = goldTier(y, rows)
    if (shines(x, y)) return GOLD_LIFTS[tier]
    if (y === 0 || !mask[y - 1][x]) return GOLD_EDGE
    return GOLD_TIERS[tier]
  }))
}

function wordmarkIcon() {
  const mask = setLetters("GAMEBLE")
  const cols = mask[0].length
  const middle = Math.round(cols * 0.17) + Math.round(mask.length / 2)
  const colours = goldColours(mask, middle - 2)
  const palette = [...new Set([...GOLD_TIERS, ...GOLD_LIFTS])]
  const symbol = (colour) => colour === null ? "." : String(palette.indexOf(colour))
  return {
    legend: Object.fromEntries(palette.map((colour, i) => [String(i), colour])),
    grid: colours.map((line) => line.map(symbol).join("")),
  }
}

const FAVICON_SIDE_MARGIN = 1

function faviconIcon() {
  const colours = goldColours(setLetters("G"))
  const palette = [...new Set([...GOLD_TIERS, GOLD_EDGE])]
  const symbol = (colour) => colour === null ? "." : String(palette.indexOf(colour))
  const side = ".".repeat(FAVICON_SIDE_MARGIN)
  return {
    legend: Object.fromEntries(palette.map((colour, i) => [String(i), colour])),
    grid: colours.map((line) => side + line.map(symbol).join("") + side),
  }
}

const ICONS = {
  wordmark: wordmarkIcon(),
  favicon: faviconIcon(),
  ...Object.fromEntries(Object.entries(RARITY_SHAPES).map(([tier, grid]) => [`rarity-${tier}`, { legend: RARITY[tier], grid }])),
  ...Object.fromEntries(Object.entries(RARITY_COMPACT_SHAPES).map(([tier, grid]) => [`rarity-compact-${tier}`, { legend: RARITY[tier], grid }])),
  // A card's missing art (10 × 8): a frame, a sun and a mountain.
  picture: {
    grid: [
      "cccccccccc",
      "c........c",
      "c.....cc.c",
      "c.....cc.c",
      "c...c....c",
      "c..ccc.c.c",
      "c.cccccccc",
      "cccccccccc",
    ],
  },
  // A missing card's padlock (10 × 12, DESIGN.md, Missing-card slot): a
  // shackle over a body pierced by its keyhole.
  lock: {
    grid: [
      "...cccc...",
      "..c....c..",
      "..c....c..",
      "..c....c..",
      "..c....c..",
      ".cccccccc.",
      ".cccccccc.",
      ".ccc..ccc.",
      ".ccc..ccc.",
      ".ccc..ccc.",
      ".cccccccc.",
      ".cccccccc.",
    ],
  },
  // ◀ and ▶.
  "arrow-left": {
    grid: [
      "...c",
      "..cc",
      ".ccc",
      "cccc",
      ".ccc",
      "..cc",
      "...c",
    ],
  },
  "arrow-right": {
    grid: [
      "c...",
      "cc..",
      "ccc.",
      "cccc",
      "ccc.",
      "cc..",
      "c...",
    ],
  },
  // ▸
  "arrow-small-right": {
    grid: [
      "c..",
      "cc.",
      "ccc",
      "cc.",
      "c..",
    ],
  },
  // ✕
  close: {
    grid: [
      "c.....c",
      ".c...c.",
      "..c.c..",
      "...c...",
      "..c.c..",
      ".c...c.",
      "c.....c",
    ],
  },
  // ✓
  check: {
    grid: [
      "......c",
      ".....cc",
      "c...cc.",
      "cc.cc..",
      ".ccc...",
      "..c....",
    ],
  },
  // ◆
  diamond: {
    grid: [
      "..c..",
      ".ccc.",
      "ccccc",
      ".ccc.",
      "..c..",
    ],
  },
  // ⇄
  swap: {
    grid: [
      "......c..",
      "cccccccc.",
      "......c..",
      ".........",
      "..c......",
      ".cccccccc",
      "..c......",
    ],
  },
  // ↗
  external: {
    grid: [
      "..ccccc",
      ".....cc",
      "....c.c",
      "...c..c",
      "..c....",
      ".c.....",
      "c......",
    ],
  },
  // ⧗
  hourglass: {
    grid: [
      "ccccccc",
      ".c...c.",
      ".ccccc.",
      "..ccc..",
      "...c...",
      "..c.c..",
      ".c.c.c.",
      ".ccccc.",
      "ccccccc",
    ],
  },
  // The packs chip's small canister (8 × 11): steel caps, slate body, blue
  // label bands and a gold emblem.
  "canister-small": {
    legend: { o: OUTLINE, S: "#dfe6ec", d: "#5d6b7c", b: "#2f4f6c", B: "#1b2838", a: "#66c0f4", g: "#f4c542" },
    grid: [
      ".oooooo.",
      "oSSSSSSo",
      "oddddddo",
      "obbbbbBo",
      "oaaaaaao",
      "obbgbbBo",
      "oaaaaaao",
      "obbbbbBo",
      "oSSSSSSo",
      "oddddddo",
      ".oooooo.",
    ],
  },
  // The player's portrait until avatars exist (16 × 16).
  "avatar-default": {
    legend: { k: "#1b2838", h: "#66c0f4", s: "#2a6f9a", e: "#0b1520" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkkkkkkkkkkkk",
      "kkkkkkhhhhkkkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkhhhhhhhhkkkk",
      "kkkkheehheehkkkk",
      "kkkkhhhhhhhhkkkk",
      "kkkkhhhhhhhhkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkkkhhhhkkkkkk",
      "kkkkkkkhhkkkkkkk",
      "kkkksssssssskkkk",
      "kkksssssssssskkk",
      "kksssssssssssskk",
      "kssssssssssssssk",
      "kssssssssssssssk",
    ],
  },
  // Phone tab bar (11 × 11).
  "tab-hub": {
    grid: [
      "...........",
      "ccccccccccc",
      "c.........c",
      "c.ccc.....c",
      "c.........c",
      "c.c.c.c.c.c",
      "c.........c",
      "ccccccccccc",
      "....ccc....",
      "....ccc....",
      "..ccccccc..",
    ],
  },
  "tab-booster": {
    grid: [
      "..ccccccc..",
      ".ccccccccc.",
      ".c.......c.",
      ".ccccccccc.",
      ".c.......c.",
      ".c.ccccc.c.",
      ".c.......c.",
      ".ccccccccc.",
      ".c.......c.",
      ".ccccccccc.",
      "..ccccccc..",
    ],
  },
  "tab-collection": {
    grid: [
      "....ccccccc",
      "....c.....c",
      "..ccccccc.c",
      "..c.....c.c",
      "cccccccc..c",
      "c......c..c",
      "c......c..c",
      "c......cccc",
      "c......c...",
      "c......c...",
      "cccccccc...",
    ],
  },
  "tab-trades": {
    grid: [
      "........c..",
      "........cc.",
      "ccccccccccc",
      "........cc.",
      "........c..",
      "...........",
      "..c........",
      ".cc........",
      "ccccccccccc",
      ".cc........",
      "..c........",
    ],
  },
  "tab-more": {
    grid: [
      "cccc...cccc",
      "c..c...c..c",
      "c..c...c..c",
      "cccc...cccc",
      "...........",
      "...........",
      "...........",
      "cccc...cccc",
      "c..c...c..c",
      "c..c...c..c",
      "cccc...cccc",
    ],
  },
}

function iconSvg(name, { grid, legend = {} }) {
  const height = grid.length
  const width = grid[0].length
  const paths = new Map()
  grid.forEach((row, y) => {
    if (row.length !== width) throw new Error(`${name}: row ${y} is ${row.length} wide, not ${width}`)
    let x = 0
    while (x < width) {
      const ch = row[x]
      let end = x + 1
      while (end < width && row[end] === ch) end++
      if (ch !== ".") {
        const fill = ch === "c" ? "currentColor" : legend[ch]
        if (!fill) throw new Error(`${name}: no colour for "${ch}"`)
        if (!paths.has(fill)) paths.set(fill, [])
        paths.get(fill).push(`M${x} ${y}h${end - x}v1h-${end - x}z`)
      }
      x = end
    }
  })
  const body = [...paths.entries()].map(([fill, d]) => `<path fill="${fill}" d="${d.join("")}"/>`).join("")
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width * ART_PIXEL}" height="${height * ART_PIXEL}" shape-rendering="crispEdges">${body}</svg>\n`
}

// A small seeded generator (mulberry32), so the star field never changes
// between runs.
function random(seed) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// The star field's tile (DESIGN.md, Atmosphere): 2px and 4px squares of
// {colors.star} on the 2px grid, at a few brightnesses, repeated by CSS.
function starfieldSvg() {
  const SIZE = 480
  const STAR = "#c7d5e0"
  const next = random(20261005)
  const byOpacity = new Map()
  for (let i = 0; i < 70; i++) {
    const big = next() < 0.15
    const size = big ? 4 : 2
    const x = Math.floor(next() * ((SIZE - size) / 2)) * 2
    const y = Math.floor(next() * ((SIZE - size) / 2)) * 2
    const opacity = [0.35, 0.55, 0.8][Math.floor(next() * 3)]
    if (!byOpacity.has(opacity)) byOpacity.set(opacity, [])
    byOpacity.get(opacity).push(`M${x} ${y}h${size}v${size}h-${size}z`)
  }
  const body = [...byOpacity.entries()].sort(([a], [b]) => a - b)
    .map(([opacity, d]) => `<path fill="${STAR}" fill-opacity="${opacity}" d="${d.join("")}"/>`).join("")
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}" shape-rendering="crispEdges">${body}</svg>\n`
}


// ---------------------------------------------------------------------------
// Drawn art (story 8.8): the card backs, the canister, the planet and the
// avatars. Their drawing code is ported pixel for pixel from the approved
// prototypes (ux-gameble/mockups/key-screens.html and mobile.html): the same
// formulas, constants, rounding and RNG seeds, run on an in-memory RGBA
// buffer that behaves like the prototype's 2D canvas for whole-pixel fills.
// Each image is written as a PNG at 1x art resolution; the page draws it at
// 2 CSS px per art pixel.

// The prototype's colour helpers.
const clamp = (v, a, b) => v < a ? a : v > b ? b : v
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]
const mixc = (a, b, t) => {
  const x = hex(a), y = hex(b)
  return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * clamp(t, 0, 1)).toString(16).padStart(2, "0")).join("")
}

// A canvas stand-in: fillStyle takes "#rrggbb" (anything else is ignored, as
// a canvas ignores an invalid colour), fillRect paints opaque pixels, clipped
// to the buffer, later fills over earlier ones. Pixels never filled stay
// transparent. Every fill lands on whole pixels; a fractional one would be
// antialiased by a real canvas, so it is refused here.
function canvas(width, height) {
  const rgba = Buffer.alloc(width * height * 4)
  let fill = [0, 0, 0]
  return {
    width,
    height,
    rgba,
    set fillStyle(col) {
      if (/^#[0-9a-f]{6}$/i.test(col)) fill = hex(col)
    },
    fillRect(x, y, w, h) {
      if (![x, y, w, h].every(Number.isInteger)) throw new Error(`fillRect off the pixel grid: ${x}, ${y}, ${w}, ${h}`)
      if (w < 0) { x += w; w = -w }
      if (h < 0) { y += h; h = -h }
      const x0 = Math.max(0, x), x1 = Math.min(width, x + w)
      const y0 = Math.max(0, y), y1 = Math.min(height, y + h)
      for (let py = y0; py < y1; py++) {
        for (let px = x0; px < x1; px++) {
          const i = (py * width + px) * 4
          rgba[i] = fill[0]
          rgba[i + 1] = fill[1]
          rgba[i + 2] = fill[2]
          rgba[i + 3] = 255
        }
      }
    },
  }
}

// The 5 × 7 pixel font of the card backs' lettering, one base-32 digit per
// row, with the glyphs the prototype adds for the backs.
const B32 = "0123456789abcdefghijklmnopqrstuv"
const FONT = {
  A: "ehhvhhh", B: "uhhuhhu", C: "ehggghe", D: "uhhhhhu", E: "vgguggv", F: "vgguggg", G: "ehgnhhf", H: "hhhvhhh",
  I: "e44444e", L: "ggggggv", M: "hrllhhh", N: "hpljhhh", O: "ehhhhhe", P: "uhhuggg", R: "uhhukih", S: "fgge11u",
  T: "v444444", U: "hhhhhhe", "1": "4c4444e", " ": "0000000",
  J: "72222ic", K: "hikokih", Q: "ehhhlid", V: "hhhhha4", W: "hhhllla", X: "hha4ahh", Y: "hha4444", Z: "v1248gv",
  "0": "ehjlphe", "2": "eh1248v", "3": "v2421he", "4": "26aiv22", "5": "vgu11he", "6": "68guhhe", "7": "v124888",
  "8": "ehhehhe", "9": "ehhf12c",
}
function ptext(g, str, x, y, col) {
  g.fillStyle = col
  let cx = x
  for (const ch of str) {
    const gl = FONT[ch] || FONT[" "]
    for (let r = 0; r < 7; r++) {
      const row = B32.indexOf(gl[r] || "0")
      for (let c = 0; c < 5; c++) if (row & (1 << (4 - c))) g.fillRect(cx + c, y + r, 1, 1)
    }
    cx += 6
  }
  return cx
}
const ptw = (s) => s.length * 6 - 1
function ptextS(g, str, x, y, col, s) {
  g.fillStyle = col
  let cx = x
  for (const ch of str) {
    const gl = FONT[ch] || FONT[" "]
    for (let r = 0; r < 7; r++) {
      const row = B32.indexOf(gl[r] || "0")
      for (let c = 0; c < 5; c++) if (row & (1 << (4 - c))) g.fillRect(cx + c * s, y + r * s, s, s)
    }
    cx += 6 * s
  }
}
const MONOGRAM = goldColours(setLetters("G"))
const MONOGRAM_WIDTH = MONOGRAM[0].length
const MONOGRAM_HEIGHT = MONOGRAM.length
function drawMonogram(g, x, y, k) {
  MONOGRAM.forEach((line, row) => line.forEach((colour, col) => {
    if (!colour) return
    g.fillStyle = colour
    g.fillRect(x + col * k, y + row * k, k, k)
  }))
}

const FAVICON_PNG_SIZE = 180
const FAVICON_PNG_SCALE = 20
function faviconPng() {
  const g = canvas(FAVICON_PNG_SIZE, FAVICON_PNG_SIZE)
  const centred = (length) => (FAVICON_PNG_SIZE - length * FAVICON_PNG_SCALE) / 2
  drawMonogram(g, centred(MONOGRAM_WIDTH), centred(MONOGRAM_HEIGHT), FAVICON_PNG_SCALE)
  return g
}

// Card backs (DESIGN.md, Card backs). `id` is the prototype's id: its length
// seeds the stars and the snow, so it is kept as is.
function backCanvas(id, w, h) {
  const g = canvas(w, h)
  const P = (x, y, col) => { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), 1, 1) }
  const F = (x, y, ww, hh, col) => { g.fillStyle = col; g.fillRect(x, y, ww, hh) }
  const b = 5, cx = (w - 1) / 2, cy = (h - 1) / 2
  const frame = (o, hi, lo, band, well) => {
    F(0, 0, w, h, o); F(0, 0, w, 1, hi); F(0, 0, 1, h, hi); F(0, h - 1, w, 1, lo); F(w - 1, 0, 1, h, lo)
    F(1, 1, w - 2, h - 2, band); F(2, 2, w - 4, h - 4, well)
  }
  const field = (fn) => {
    for (let y = 3; y < h - 3; y++) for (let x = 3; x < w - 3; x++) { const col = fn(x, y); if (col) P(x, y, col) }
  }
  const inner = (col) => { F(b, b, w - 2 * b, 1, col); F(b, h - b - 1, w - 2 * b, 1, col); F(b, b, 1, h - 2 * b, col); F(w - b - 1, b, 1, h - 2 * b, col) }
  const brackets = (col) => {
    const L = Math.max(4, Math.round(w * 0.08)), q = b + 2
    for (const [x, y, sx, sy] of [[q, q, 1, 1], [w - q - 1, q, -1, 1], [q, h - q - 1, 1, -1], [w - q - 1, h - q - 1, -1, -1]]) {
      for (let i = 0; i < L; i++) { P(x + i * sx, y, col); P(x, y + i * sy, col) }
    }
  }
  const word = (s, col, sh, yy) => {
    if (ptw(s) > w - 16) return
    const tx = Math.round((w - ptw(s)) / 2)
    if (sh) ptext(g, s, tx, yy + 1, sh)
    ptext(g, s, tx, yy, col)
  }
  const big = (s, col, sh, yy, k) => {
    const tw = (s.length * 6 - 1) * k, tx = Math.round((w - tw) / 2)
    if (sh) ptextS(g, s, tx + 1, yy + 1, sh, k)
    ptextS(g, s, tx, yy, col, k)
  }
  let sd = w * 131 + id.length * 977
  const rr = () => (sd = (sd * 16807) % 2147483647) / 2147483647
  switch (id) {
    case "s1": { // Saison 1: Steam blueprint grid, a big engraved "1"
      frame("#2a475e", "#66c0f4", "#142636", "#1b2838", "#0b1520")
      field((x, y) => ((x - 3) % 16 === 0 || (y - 3) % 16 === 0) ? "#1f4a6a" : ((x - 3) % 4 === 0 || (y - 3) % 4 === 0) ? "#132b40" : "#0e2133")
      const k = w >= 100 ? 4 : w >= 70 ? 3 : 2, gw = 5 * k, gh = 7 * k
      const x0 = Math.round(cx - gw / 2 + k / 2), y0 = Math.round(cy - gh / 2 - h * 0.03), gl = "4c4444e"
      for (let r = 0; r < 7; r++) {
        const row = B32.indexOf(gl[r])
        for (let q = 0; q < 5; q++) {
          if (row & (1 << (4 - q))) {
            F(x0 + q * k + 1, y0 + r * k + 1, k, k, "#06090d")
            F(x0 + q * k, y0 + r * k, k, k, "#66c0f4")
            F(x0 + q * k, y0 + r * k, k, 1, "#b5e2ff")
          }
        }
      }
      for (let i = 0; i < 24; i++) {
        const a = i / 24 * Math.PI * 2, R0 = w * 0.36
        P(cx + Math.cos(a) * R0, cy - h * 0.03 + Math.sin(a) * R0, i % 6 ? "#2a6f9a" : "#f4c542")
      }
      inner("#2a475e"); brackets("#66c0f4"); word("SAISON", "#66c0f4", "#06090d", b + 5); word("GAMEBLE", "#3d6c8c", "#06090d", h - b - 12)
      break
    }
    case "w38": { // Semaine 38: community goal pennant, ring and five stars, hazard band
      frame("#2a475e", "#66c0f4", "#142636", "#1b2838", "#0b1015")
      field((x, y) => ((x - y + 999) % 5 === 0) ? "#152230" : "#0f1822")
      const pw = Math.round(w * 0.25), top = Math.round(h * 0.15), bot = Math.round(h * 0.66), nt = Math.round(h * 0.08)
      const inP = (x, y) => { const dx = Math.abs(x - cx); return dx <= pw && y >= top && y <= bot + nt * (dx / pw) }
      for (let y = top - 1; y <= bot + nt + 1; y++) {
        for (let x = Math.floor(cx - pw - 1); x <= Math.ceil(cx + pw + 1); x++) {
          if (!inP(x, y)) continue
          const edge = !inP(x - 1, y) || !inP(x + 1, y) || !inP(x, y - 1) || !inP(x, y + 1)
          P(x, y, edge ? "#f4c542" : mixc("#22364b", "#16222f", (y - top) / (bot - top)))
        }
      }
      const ry = h * 0.34, R0 = w * 0.11
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const d = Math.hypot(x - cx, y - ry)
          if (Math.abs(d - R0) < 0.6) P(x, y, "#f4c542"); else if (d < R0 * 0.45) P(x, y, "#66c0f4")
        }
      }
      for (let i = -2; i <= 2; i++) {
        const a = -Math.PI / 2 + i * 0.42, x = cx + Math.cos(a) * w * 0.19, y = ry + Math.sin(a) * w * 0.19
        P(x, y, "#fff3c4")
        if (w >= 70) { P(x - 1, y, "#f4c542"); P(x + 1, y, "#f4c542"); P(x, y - 1, "#f4c542"); P(x, y + 1, "#f4c542") }
      }
      big("38", "#f4c542", "#06090d", Math.round(h * 0.46), w >= 100 ? 2 : 1)
      const hy = Math.round(h * 0.82)
      for (let y = hy; y < hy + 3; y++) for (let x = b + 1; x < w - b - 1; x++) P(x, y, ((x + y) >> 1) % 3 === 0 ? "#e8833a" : "#0b1015")
      inner("#2a475e"); brackets("#f4c542"); word("SEMAINE", "#8fa3b5", "#06090d", h - b - 11)
      break
    }
    case "gold": { // Étoile d'or: gold sunburst and a big shaded star
      frame("#8f5e0a", "#fff3c4", "#4a3005", "#c99a2e", "#120d05")
      const sy = cy - h * 0.04
      field((x, y) => {
        const a = Math.atan2(y - sy, x - cx), k = Math.floor((a + Math.PI) / (Math.PI * 2) * 24) & 1, d = Math.hypot(x - cx, y - sy) / h
        return mixc(k ? "#33270b" : "#1d1607", "#0c0903", clamp(d * 1.7, 0, 1))
      })
      const Rs = w * 0.3
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const u = (x - cx) / Rs, v = (y - sy) / Rs, a = Math.atan2(v, u) + Math.PI / 2, r = Math.hypot(u, v)
          const kk = ((a / (Math.PI * 2 / 5)) % 1 + 1) % 1, t = Math.abs(kk - 0.5) * 2, lim = 0.42 + t * t * 0.58
          if (r <= lim) P(x, y, r < lim * 0.35 ? "#fff8dc" : mixc("#fff3c4", "#b8902a", clamp((v + 1) / 2, 0, 1)))
          else if (r <= lim + 1.4 / Rs) P(x, y, "#4a3005")
        }
      }
      for (let i = 0; i < 8; i++) {
        const a = i / 8 * Math.PI * 2 + 0.3, x = cx + Math.cos(a) * w * 0.41, y = sy + Math.sin(a) * w * 0.47
        P(x, y, "#fff3c4")
        if (i % 2 === 0 && w >= 70) { P(x - 1, y, "#f4c542"); P(x + 1, y, "#f4c542"); P(x, y - 1, "#f4c542"); P(x, y + 1, "#f4c542") }
      }
      inner("#8f5e0a"); brackets("#fff3c4"); word("LEGENDE", "#f4c542", "#120d05", h - b - 12)
      break
    }
    case "aur": { // Aurore: aurora curtains over a night sky and a mountain line
      frame("#1f4a44", "#4fa08a", "#0c2420", "#16352f", "#06100f")
      const bands = [
        { c: "#3fcf8e", y: 0.24, a: 0.06, f: 0.17, ph: 0, L: 0.17 },
        { c: "#66c0f4", y: 0.34, a: 0.05, f: 0.23, ph: 2, L: 0.12 },
        { c: "#b47cff", y: 0.17, a: 0.035, f: 0.12, ph: 4, L: 0.1 },
      ]
      field((x, y) => {
        let col = mixc("#0d2030", "#060c14", y / h)
        for (const B of bands) {
          const yc = h * B.y + Math.sin(x * B.f + B.ph) * h * B.a, d = y - yc, L = h * B.L
          if (d >= 0 && d < L) col = mixc(B.c, col, clamp(d / L * 1.05 + 0.12 + ((x + y) % 2) * 0.04, 0, 1))
          else if (d < 0 && d > -1.5) col = mixc(B.c, col, 0.45)
        }
        return col
      })
      for (let i = 0; i < w * h / 80; i++) { const x = 4 + rr() * (w - 8), y = 4 + rr() * (h * 0.5); P(x, y, rr() < 0.3 ? "#e6eef5" : "#5f7d94") }
      for (let x = 3; x < w - 3; x++) {
        const mh = h * 0.11 + Math.abs(Math.sin(x * 0.09 + 1)) * h * 0.07 + ((x >> 2) % 3 === 0 ? 1 : 0)
        for (let y = Math.round(h - 3 - mh); y < h - 3; y++) P(x, y, y < h - 2 - mh ? "#1f4a44" : "#07131a")
      }
      inner("#2f6a60"); brackets("#b2f7d4"); word("AURORE", "#b2f7d4", "#06100f", h - b - 12)
      break
    }
    case "b17": { // Millésime 2017: laurel wreath, the year, a ribbon
      frame("#6b4a12", "#f4d27a", "#2a1d06", "#4a3410", "#0a0805")
      field((x, y) => { const base = mixc("#141c2a", "#0a0f18", y / h); return x % 6 === 0 ? mixc(base, "#1d2739", 0.6) : base })
      const wy = cy - h * 0.05, R0 = w * 0.33
      for (const sx of [-1, 1]) {
        for (let deg = 105; deg <= 255; deg += 3) {
          const a = deg * Math.PI / 180, x = cx + sx * Math.cos(a) * -1 * R0, y = wy + Math.sin(a) * R0 * 1.12
          P(x, y, "#8f6a18")
          if (deg % 15 === 0) {
            const o = Math.cos(a), q = Math.sin(a)
            for (let k = 1; k <= 3; k++) {
              P(x + sx * -o * k * 0.9 + (k > 1 ? sx * 0.5 : 0), y + q * k * 0.6 - k * 0.7, k === 3 ? "#fff3c4" : "#f4c542")
              P(x - sx * -o * k * 0.7, y - q * k * 0.5 - k * 0.5, "#c9a03a")
            }
          }
        }
      }
      big("2017", "#fff3c4", "#4a3005", Math.round(wy - 3.5 * (w >= 100 ? 2 : 1)), w >= 100 ? 2 : 1)
      const ry = Math.round(wy + R0 * 1.12 + 4), rw = Math.round(w * 0.28)
      F(Math.round(cx - rw), ry, rw * 2, 3, "#2a6f9a"); F(Math.round(cx - rw), ry, rw * 2, 1, "#66c0f4")
      for (const sx of [-1, 1]) {
        const ex = Math.round(cx + sx * rw)
        for (let k = 0; k < 4; k++) { P(ex + sx * k, ry + k, "#1f5a80"); P(ex + sx * k, ry + k + 1, "#2a6f9a") }
      }
      inner("#6b4a12"); brackets("#f4c542"); word("TOP 10", "#c9a03a", "#0a0805", h - b - 12)
      break
    }
    case "cent": { // Centurion: riveted metal plate, orange core, "100"
      frame("#3a424b", "#8c97a3", "#14181c", "#2a3139", "#0b0e11")
      field((x, y) => (((x >> 2) + (y >> 2)) & 1) ? "#1d2228" : "#232a31")
      for (let y = b + 5; y < h - b - 4; y += 8) for (let x = b + 5; x < w - b - 4; x += 8) { P(x, y, "#8c97a3"); P(x + 1, y + 1, "#0b0e11") }
      const Rc = w * 0.27, oy = cy - h * 0.05
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const u = Math.abs(x - cx), v = Math.abs(y - oy), d = Math.max(u, v, (u + v) / 1.38)
          if (d < Rc - 2) P(x, y, mixc("#ffb15c", "#3a1a08", d / (Rc - 2))); else if (d < Rc) P(x, y, "#e8833a"); else if (d < Rc + 1.2) P(x, y, "#0b0e11")
        }
      }
      const k = w >= 100 ? 2 : 1
      big("100", "#fff1d8", "#3a1a08", Math.round(oy - 3.5 * k), k)
      const hy = Math.round(h * 0.8)
      for (let y = hy; y < hy + 3; y++) for (let x = b + 1; x < w - b - 1; x++) P(x, y, ((x + y) >> 1) % 3 === 0 ? "#e8833a" : "#14181c")
      inner("#3a424b"); brackets("#e8833a"); word("CENTURION", "#8c97a3", "#0b0e11", h - b - 12)
      break
    }
    case "snow": { // Soldes d'hiver: a big snowflake, falling snow, snowy pines
      frame("#4f86a8", "#d6efff", "#1f3a52", "#2f5a78", "#0a1622")
      field((x, y) => mixc("#1d3a58", "#0c1a2a", y / h))
      const fy = h * 0.38, Rf = w * 0.22
      for (let i = 0; i < 6; i++) {
        const a = i * Math.PI / 3 - Math.PI / 2
        for (let r = 0; r <= Rf; r += 0.5) P(cx + Math.cos(a) * r, fy + Math.sin(a) * r, "#e6f4ff")
        for (const fr of [0.45, 0.75]) {
          const bx = cx + Math.cos(a) * Rf * fr, by = fy + Math.sin(a) * Rf * fr, L = Rf * 0.26
          for (const s of [-1, 1]) {
            const a2 = a + s * Math.PI / 4
            for (let r = 0; r <= L; r += 0.5) P(bx + Math.cos(a2) * r, by + Math.sin(a2) * r, "#b5e2ff")
          }
        }
      }
      P(cx, fy, "#ffffff")
      for (let i = 0; i < w * h / 55; i++) {
        const x = 4 + rr() * (w - 8), y = 4 + rr() * (h * 0.74)
        if (Math.hypot(x - cx, y - fy) < Rf + 3) continue
        P(x, y, rr() < 0.5 ? "#e6eef5" : "#7fa6c4")
      }
      const gb = h - b - 3
      for (const [px, ph] of [[w * 0.2, h * 0.2], [w * 0.4, h * 0.14], [w * 0.63, h * 0.18], [w * 0.82, h * 0.24]]) {
        for (let k = 0; k < ph; k++) {
          const half = Math.floor(k * 0.34) + (k % 4 === 3 ? 1 : 0), y = Math.round(gb - ph + k)
          for (let x = -half; x <= half; x++) P(px + x, y, (k < 2 || (Math.abs(x) === half && k % 4 === 0)) ? "#c7d5e0" : "#0b1a26")
        }
      }
      F(3, gb, w - 6, h - 3 - gb, "#c7d5e0"); F(3, gb, w - 6, 1, "#e6f4ff")
      inner("#4f86a8"); brackets("#e6f4ff"); word("HIVER", "#e6f4ff", "#0a1622", b + 5)
      break
    }
    default: { // Standard
      F(0, 0, w, h, "#2a475e"); F(0, 0, w, 1, "#3d6c8c"); F(0, 0, 1, h, "#3d6c8c"); F(0, h - 1, w, 1, "#142636"); F(w - 1, 0, 1, h, "#142636")
      F(1, 1, w - 2, h - 2, "#1b2838"); F(2, 2, w - 4, h - 4, "#0e141b")
      for (let y = 3; y < h - 3; y++) {
        for (let x = 3; x < w - 3; x++) {
          const t = y / h, base = mixc("#152131", "#0d141d", t), alt = mixc("#1a2738", "#111a25", t)
          P(x, y, ((x + y) >> 1) % 3 === 0 ? alt : base)
        }
      }
      inner("#1f3346"); brackets("#66c0f4")
      const sy = cy - h * 0.04, Rr = w * 0.3
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const d = Math.hypot(x - cx, y - sy)
          if (d < Rr - 1.2) P(x, y, mixc("#183048", "#0b1119", d / Rr))
          else if (Math.abs(d - Rr) < 0.62) P(x, y, "#66c0f4")
          else if (Math.abs(d - (Rr + 5)) < 0.5 && ((x + y) & 1)) P(x, y, "#2a475e")
        }
      }
      for (let i = 0; i < 32; i++) {
        const a = i / 32 * Math.PI * 2, bg = i % 8 === 0, r0 = Rr + 2, r1 = Rr + (bg ? 4.2 : 3)
        for (let r = r0; r <= r1; r += 0.5) P(cx + Math.cos(a) * r, sy + Math.sin(a) * r, bg ? "#f4c542" : "#3d6c8c")
      }
      const k = Math.max(1, Math.round(Rr / 11.5))
      drawMonogram(g, Math.round(cx - (MONOGRAM_WIDTH * k - 1) / 2), Math.round(sy - (MONOGRAM_HEIGHT * k - 1) / 2), k)
      const ty = h - b - 12
      if (w >= 50) { const tx = Math.round((w - ptw("GAMEBLE")) / 2); ptext(g, "GAMEBLE", tx, ty + 1, "#06090d"); ptext(g, "GAMEBLE", tx, ty, "#3d6c8c") }
      for (let x = b + 4; x < w - b - 4; x += 3) P(x, ty - 4, "#1f3346")
    }
  }
  return g
}

// The booster canister (DESIGN.md, Booster canister), 100 × 150 art pixels in
// three parts: the caps blow off on opening. Its label text, hazard band and
// LEDs are page layers (they turn orange when armed), so they are not drawn.
const CANISTER = (() => {
  const W = 100
  const pc = (g, x, y, c) => { g.fillStyle = c; g.fillRect(x, y, 1, 1) }
  const rc = (g, x, y, w, h, c) => { g.fillStyle = c; g.fillRect(x, y, w, h) }
  const cyl = (x) => { const u = x / (W - 1); return u < 0.1 ? 0 : u > 0.88 ? 1 : (u - 0.1) / 0.78 } // 0 lit left edge, 1 shaded right edge
  function cap(top) {
    const g = canvas(W, 20)
    for (let y = 0; y < 20; y++) {
      const e = top ? y : 19 - y // distance from the open end
      for (let x = 0; x < W; x++) {
        if ((e === 0 && (x < 2 || x > W - 3)) || (e === 1 && (x < 1 || x > W - 2))) continue // rounded outer corners
        let col
        if (e === 0) col = "#06090d" // outline
        else if (e === 1) col = x <= 1 || x >= W - 2 ? "#06090d" : mixc("#f2f7fb", "#c7d5e0", cyl(x) * 0.6) // highlight line
        else if (e <= 13) { // knurled grip
          const t = (e - 2) / 11
          col = mixc("#dfe6ec", "#5d6b7c", clamp(t * 0.55 + cyl(x) * 0.55, 0, 1))
          if (x % 3 === 0) col = mixc(col, "#2b343e", 0.5); else if (x % 3 === 1) col = mixc(col, "#ffffff", 0.14)
        } else if (e <= 16) col = mixc(e === 14 ? "#6b7885" : "#3d4a57", "#1b2128", cyl(x) * 0.6) // collar
        else if (e === 17) col = "#8f98a0"; else if (e === 18) col = "#2a475e"; else col = "#06090d"
        if (x === 0 || x === W - 1) col = "#06090d"
        pc(g, x, y, col)
      }
    }
    if (top) { rc(g, 75, 4, 15, 10, "#06090d"); rc(g, 76, 5, 13, 8, "#0e141b"); rc(g, 76, 5, 13, 1, "#06090d"); rc(g, 76, 12, 13, 1, "#2a475e") } // indicator window
    return g
  }
  function body() {
    const g = canvas(W, 110)
    for (let y = 0; y < 110; y++) {
      for (let x = 0; x < W; x++) {
        let col
        if (x === 0 || x === W - 1 || y === 0 || y === 109) col = "#06090d"
        else {
          const t = cyl(x)
          col = mixc("#2f4f6c", "#1b2838", Math.min(1, t * 1.7)); col = mixc(col, "#0d141c", Math.max(0, t - 0.62) * 1.9); col = mixc(col, "#121b26", y / 109 * 0.3)
          if (y <= 4 || y >= 105) col = mixc(y === 1 || y === 106 ? "#4a7fa3" : y === 4 || y === 105 ? "#16222e" : "#2a475e", "#121a24", t * 0.75) // rim bands
          const d = x + (110 - y) * 0.35
          if (y > 4 && y < 105) { if (d > 15 && d < 18) col = mixc(col, "#ffffff", 0.08); else if (d > 21 && d < 22) col = mixc(col, "#ffffff", 0.05) } // gloss
        }
        pc(g, x, y, col)
      }
    }
    for (let y = 15; y <= 49; y++) { // label band
      for (let x = 1; x < W - 1; x++) {
        const t = cyl(x)
        let col = y === 15 ? "#e6f6ff" : y === 16 ? "#b5e2ff" : y === 49 ? "#1f5a80" : y === 48 ? "#2a6f9a" : (y % 3 === 0 ? "#5cb6ea" : "#66c0f4")
        if (t < 0.04) col = mixc(col, "#ffffff", 0.22); else if (t > 0.75) col = mixc(col, "#1f5a80", (t - 0.75) * 1.7)
        pc(g, x, y, col)
      }
    }
    for (const x0 of [4, W - 14]) for (let y = 19; y <= 45; y++) for (let x = x0; x < x0 + 10; x++) if (((x + y) >> 1) % 3 === 0) pc(g, x, y, "#2a6f9a")
    const wx = 35, wy = 55, ww = 30, wh = 32 // emblem window
    rc(g, wx - 1, wy - 1, ww + 2, wh + 2, "#06090d"); rc(g, wx, wy, ww, wh, "#c7d5e0"); rc(g, wx, wy, ww, 1, "#f2f7fb"); rc(g, wx, wy, 1, wh, "#f2f7fb")
    rc(g, wx, wy + wh - 1, ww, 1, "#8f98a0"); rc(g, wx + ww - 1, wy, 1, wh, "#8f98a0")
    for (let y = wy + 2; y < wy + wh - 2; y++) {
      for (let x = wx + 2; x < wx + ww - 2; x++) pc(g, x, y, mixc("#1c3954", "#0b1119", Math.min(1, Math.hypot(x - (wx + ww / 2 - 0.5), y - (wy + wh / 2 - 0.5)) / 15)))
    }
    rc(g, wx + 2, wy + 2, ww - 4, 1, "#06090d"); rc(g, wx + 2, wy + 2, 1, wh - 4, "#06090d")
    const mk = 2
    drawMonogram(g, wx + (ww - MONOGRAM_WIDTH * mk) / 2, wy + (wh - MONOGRAM_HEIGHT * mk) / 2, mk)
    for (const [x, y] of [[5, 7], [93, 7], [5, 100], [93, 100]]) { rc(g, x, y, 2, 2, "#8f98a0"); pc(g, x, y, "#f2f7fb"); pc(g, x + 1, y + 1, "#3d4a57") } // rivets
    rc(g, 65, 89, 28, 12, "#06090d"); rc(g, 66, 90, 26, 10, "#121a24"); rc(g, 66, 99, 26, 1, "#2a475e") // LED plate (the LEDs are a page layer)
    rc(g, 7, 89, 48, 8, "#06090d") // hazard frame (the band is a page layer)
    for (let x = 8; x < 54; x++) { if ((x * 7) % 5 < 2) continue; rc(g, x, 99, 1, (x * 3) % 4 ? 3 : 5, "#5d6b7c") } // barcode
    return g
  }
  return { top: cap(true), body: body(), bottom: cap(false) }
})()

// The ringed planet under the hub showcase (DESIGN.md, Showcase), 200 × 200.
function drawPlanet() {
  const N = 200, g = canvas(N, N), cx = 99.5, cy = 99.5, R0 = 80, ringY = 107, rx = 98, ry = 9
  const P = (x, y, col) => { g.fillStyle = col; g.fillRect(x, y, 1, 1) }
  const inRing = (x, y) => { const e = ((x - cx) / rx) ** 2 + ((y - ringY) / ry) ** 2; return e <= 1 && e >= 0.8 }
  for (let y = 0; y < ringY; y++) for (let x = 0; x < N; x++) if (inRing(x, y)) P(x, y, "#1f4a6a")
  const bands = [[0.16, "#3d6c8c"], [0.3, "#2a475e"], [0.4, "#4a7fa3"], [0.5, "#2a475e"], [0.59, "#1f3a52"], [0.66, "#2a475e"], [0.8, "#1b3044"], [1.01, "#142636"]]
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      const dx = x - cx, dy = y - cy, d = Math.hypot(dx, dy)
      if (d > R0) continue
      const v = (y - (cy - R0)) / (2 * R0)
      const k = bands.findIndex((b) => v < b[0])
      let col = bands[k][1]
      if (k > 0 && v - bands[k - 1][0] < 0.012 && ((x + y) & 1)) col = bands[k - 1][1] // dithered band edge
      const lit = (-dx * 0.55 - dy * 0.75) / R0
      if (lit < -0.3) col = mixc(col, "#0b1119", Math.min(0.62, (-0.3 - lit) * 0.9))
      if (d > R0 - 2 && lit > 0.15) col = mixc(col, "#8fd3ff", 0.4)
      P(x, y, col)
    }
  }
  for (const [x, y, r] of [[118, 74, 4], [80, 120, 3], [134, 102, 2], [92, 58, 2]]) {
    for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++) if (i * i + j * j <= r * r) P(x + i, y + j, (j === -r || i === -r) ? "#4a7fa3" : "#1b3044")
  }
  for (const [x, y, w] of [[58, 36, 7], [48, 48, 3], [42, 60, 2]]) for (let i = 0; i < w; i++) P(x + i, y, "#8fd3ff")
  for (let y = ringY; y < N; y++) for (let x = 0; x < N; x++) if (inRing(x, y)) P(x, y, ((x + y) % 9 === 0) ? "#b5e2ff" : "#4f8db8")
  for (let x = 0; x < N; x++) {
    const t = 1 - ((x - cx) / rx) ** 2
    if (t < 0) continue
    const y = Math.round(ringY + ry * Math.sqrt(t) * 0.92)
    if (y >= ringY) P(x, y, "#8fd3ff")
  }
  return g
}

// Avatars (16 × 16): a head and shoulders over a vertical gradient, one
// palette each: [gradient top, gradient bottom, lit edge, head, shoulders].
const PALS = {
  hugo: ["#24384c", "#142030", "#8fd3ff", "#66c0f4", "#3d6c8c"],
  lea: ["#3a2440", "#1a1020", "#ffc6e2", "#f48fb1", "#9c4f78"],
  max: ["#3a3218", "#1a160a", "#ffe7a0", "#f4c542", "#9a7a20"],
  ines: ["#15362d", "#0a1a15", "#bff7dc", "#3fcf8e", "#1f7a55"],
  tom: ["#3a2414", "#1a0f08", "#ffd2a6", "#e8833a", "#8a4a1c"],
  sam: ["#262840", "#12131f", "#dcdcff", "#a3a3ff", "#5a5a9a"],
  x1: ["#2a2f36", "#14171b", "#e6eef5", "#c7d5e0", "#5d6b78"],
  x2: ["#2c1f3a", "#140e1c", "#e6d4ff", "#b47cff", "#55308f"],
}
const AV_ROWS = [
  "................",
  "................",
  "......####......",
  ".....######.....",
  "....########....",
  "....########....",
  "....########....",
  ".....######.....",
  "......####......",
  "....########....",
  "..############..",
  ".##############.",
  ".##############.",
  "################",
  "################",
  "################",
]
function avatarCanvas(k) {
  const p = PALS[k], g = canvas(16, 16)
  for (let y = 0; y < 16; y++) { g.fillStyle = mixc(p[0], p[1], y / 15); g.fillRect(0, y, 16, 1) }
  AV_ROWS.forEach((r, y) => {
    for (let x = 0; x < 16; x++) {
      if (r[x] === "#") {
        g.fillStyle = (r[x - 1] !== "#" || (AV_ROWS[y - 1] && AV_ROWS[y - 1][x] !== "#")) ? p[2] : y < 9 ? p[3] : p[4]
        g.fillRect(x, y, 1, 1)
      }
    }
  })
  return g
}

// The eight backs of the prototype (DESIGN.md, Card backs), under their file
// names, and the card sizes they are drawn for: half of each DESIGN card size,
// since one art pixel is 2 CSS px. The drawing depends on the size, so each
// size is its own file.
const BACK_DESIGNS = [
  { name: "standard", id: "std", title: "Standard", look: "slate frame, diagonal weave, blue ring with gold ticks, the gold G monogram, GAMEBLE" },
  { name: "saison-1", id: "s1", title: "Saison 1", look: "blueprint grid, engraved 1 in a ring of blue and gold dots, SAISON, GAMEBLE" },
  { name: "semaine-38", id: "w38", title: "Semaine 38", look: "gold-edged pennant, gold ring and five stars, 38, orange hazard band, SEMAINE" },
  { name: "etoile-dor", id: "gold", title: "Étoile d'or", look: "gold frame, gold sunburst, large shaded gold star, sparkles, LEGENDE" },
  { name: "aurore", id: "aur", title: "Aurore", look: "night sky, jade, blue and violet aurora, stars, dark mountain line, AURORE" },
  { name: "millesime-2017", id: "b17", title: "Millésime 2017", look: "bronze-gold frame, laurel wreath around 2017, blue ribbon, TOP 10" },
  { name: "centurion", id: "cent", title: "Centurion", look: "riveted gunmetal plate, orange octagonal core with 100, orange hazard band, CENTURION" },
  { name: "soldes-hiver", id: "snow", title: "Soldes d'hiver", look: "icy blue frame, large snowflake, falling snow, snowy pines, HIVER" },
]
const CARD_SIZES = { xs: [100, 150], s: [112, 168], m: [160, 240], l: [208, 312], xl: [240, 360] }
const AVATARS = { hugo: "blue", lea: "pink", max: "gold", ines: "jade", tom: "orange", sam: "lavender", x1: "grey", x2: "violet" }

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
      const filter = raw[y * (stride + 1)]
      for (let i = 0; i < stride; i++) {
        const v = raw[y * (stride + 1) + 1 + i]
        const a = i >= 4 ? rgba[y * stride + i - 4] : 0
        const b = y > 0 ? rgba[(y - 1) * stride + i] : 0
        const c = i >= 4 && y > 0 ? rgba[(y - 1) * stride + i - 4] : 0
        let pred
        if (filter === 0) pred = 0
        else if (filter === 1) pred = a
        else if (filter === 2) pred = b
        else if (filter === 3) pred = (a + b) >> 1
        else if (filter === 4) {
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
// Every exported file: an SVG string or a PNG's pixels ({width, height, rgba}).

const files = new Map(Object.entries(ICONS).map(([name, icon]) => [`${name}.svg`, iconSvg(name, icon)]))
files.set("starfield.svg", starfieldSvg())
for (const { name, id } of BACK_DESIGNS) {
  for (const [size, [w, h]] of Object.entries(CARD_SIZES)) files.set(`back-${name}-${size}.png`, backCanvas(id, w / 2 | 0, h / 2 | 0))
}
files.set("canister-cap-top.png", CANISTER.top)
files.set("canister-body.png", CANISTER.body)
files.set("canister-cap-bottom.png", CANISTER.bottom)
files.set("planet.png", drawPlanet())
files.set("favicon.png", faviconPng())
for (const [key, colour] of Object.entries(AVATARS)) files.set(`avatar-${colour}.png`, avatarCanvas(key))

// One line per file for the review sheet; the script refuses to run when a
// file has none.
const TIER_NAMES = ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"]
const TIER_SHAPES = ["solid disc", "ring inside a ring", "diamond", "triangle", "star"]
const DESCRIPTIONS = {
  "wordmark.svg": "The gameble wordmark: flat gold GAMEBLE with a lit top edge and a diagonal shine, 66 × 9",
  "favicon.svg": "Favicon: the wordmark's gold G, 9 × 9",
  ...Object.fromEntries(TIER_NAMES.map((tier, i) => [`rarity-${i + 1}.svg`, `${tier} rarity icon, ${TIER_SHAPES[i]}, 7 × 7`])),
  ...Object.fromEntries(TIER_NAMES.map((tier, i) => [`rarity-compact-${i + 1}.svg`, `${tier} rarity icon for card faces, ${TIER_SHAPES[i]}, 5 × 5`])),
  "picture.svg": "Missing cover art: a frame, a sun and a mountain (text colour)",
  "lock.svg": "A missing card's padlock on its empty slot (10 × 12, text colour)",
  "arrow-left.svg": "◀ arrow (text colour)",
  "arrow-right.svg": "▶ arrow (text colour)",
  "arrow-small-right.svg": "▸ small arrow for links (text colour)",
  "close.svg": "✕ close and remove (text colour)",
  "check.svg": "✓ check mark (text colour)",
  "diamond.svg": "◆ ticker separator (text colour)",
  "swap.svg": "⇄ trade swap (text colour)",
  "external.svg": "↗ external link (text colour)",
  "hourglass.svg": "⧗ hourglass for expiry and pending (text colour)",
  "canister-small.svg": "The packs chip's small canister, 8 × 11",
  "avatar-default.svg": "The player's portrait in the shell, 16 × 16",
  "tab-hub.svg": "Phone tab bar icon: PONT (text colour)",
  "tab-booster.svg": "Phone tab bar icon: BOOSTER (text colour)",
  "tab-collection.svg": "Phone tab bar icon: COLLECTION (text colour)",
  "tab-trades.svg": "Phone tab bar icon: ÉCHANGES (text colour)",
  "tab-more.svg": "Phone tab bar icon: PLUS (text colour)",
  "starfield.svg": "Star field tile, 480 × 480 CSS px, repeated under the content",
  ...Object.fromEntries(BACK_DESIGNS.flatMap(({ name, title }) => Object.entries(CARD_SIZES).map(([size, [w, h]]) =>
    [`back-${name}-${size}.png`, `${title} back for card-${size}, ${w / 2 | 0} × ${h / 2 | 0} art px`]))),
  "canister-cap-top.png": "Canister top cap: steel grip, collar, indicator window, 100 × 20",
  "canister-body.png": "Canister body: slate cylinder, label band, emblem window with the gold G monogram, rivets, LED plate, barcode, 100 × 110",
  "canister-cap-bottom.png": "Canister bottom cap: steel grip and collar, 100 × 20",
  "planet.png": "Ringed planet under the hub showcase: slate and blue bands, a lit ring, 200 × 200",
  "favicon.png": "Home-screen icon: the wordmark's gold G, 20 screen pixels per glyph pixel, 180 × 180",
  ...Object.fromEntries(Object.entries(AVATARS).map(([key, colour]) => [`avatar-${colour}.png`, `Avatar, ${colour} palette (“${key}” in the prototype), 16 × 16`])),
}
for (const file of files.keys()) if (!DESCRIPTIONS[file]) throw new Error(`${file}: no description in DESCRIPTIONS`)

// ---------------------------------------------------------------------------
// Command line.

const USAGE = "usage: node script/pixel_art/export.mjs [--check | --sheet <path>] [--out <dir>]"
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
const out = resolve(option("--out") ?? join(root, "app/frontend/images/pixel"))
const shown = relative(root, out).startsWith("..") ? out : relative(root, out)
const sheet = option("--sheet")
const check = args.includes("--check")

const isPng = (content) => typeof content !== "string"
const samePixels = (a, b) => a.width === b.width && a.height === b.height && a.rgba.equals(b.rgba)
function upToDate(file, content) {
  const path = join(out, file)
  if (!existsSync(path)) return false
  if (!isPng(content)) return readFileSync(path, "utf8") === content
  const decoded = decodePng(readFileSync(path))
  return decoded !== null && samePixels(decoded, content)
}
function failWhenStale() {
  const differing = [...files].filter(([file, content]) => !upToDate(file, content)).map(([file]) => file)
  const stray = existsSync(out) ? readdirSync(out).filter((file) => !files.has(file)) : []
  if (!differing.length && !stray.length) return
  for (const file of differing) console.error(`differs: ${join(shown, file)}`)
  for (const file of stray) console.error(`not exported: ${join(shown, file)}`)
  console.error("Run node script/pixel_art/export.mjs and commit the result.")
  process.exit(1)
}

if (sheet) {
  failWhenStale()
  writeFileSync(resolve(sheet), sheetHtml())
  console.log(`review sheet of ${files.size} pixel-art files written to ${sheet}`)
} else if (check) {
  failWhenStale()
  console.log(`${files.size} pixel-art files up to date`)
} else {
  mkdirSync(out, { recursive: true })
  let written = 0
  for (const [file, content] of files) {
    if (upToDate(file, content)) continue
    writeFileSync(join(out, file), isPng(content) ? encodePng(content) : content)
    written++
  }
  console.log(`${files.size} pixel-art files in ${shown}/ (${written} written)`)
}

// ---------------------------------------------------------------------------
// The review sheet: one self-contained HTML page of every exported file, read
// back from the folder, at 2 CSS px per art pixel on the DESIGN ground. SVGs
// are inlined as markup (so text-colour icons take the page's text colour),
// PNGs as data: URIs.

function sheetHtml() {
  const escape = (s) => String(s).replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[m])
  const image = (file) => {
    const content = files.get(file)
    const bytes = readFileSync(join(out, file))
    if (!isPng(content)) return bytes.toString("utf8").trim().replace(' xmlns="http://www.w3.org/2000/svg"', "")
    return `<img src="data:image/png;base64,${bytes.toString("base64")}" width="${content.width * ART_PIXEL}" height="${content.height * ART_PIXEL}" alt="">`
  }
  const item = (file) => `<figure><div class="art">${image(file)}</div><figcaption><code>${escape(file)}</code><span>${escape(DESCRIPTIONS[file])}</span></figcaption></figure>`
  const svgs = [...files.keys()].filter((file) => file.endsWith(".svg"))
  const sizes = Object.keys(CARD_SIZES)
  const backRows = BACK_DESIGNS.map(({ name, title, look }) =>
    `<tr><th scope="row"><b>${escape(title)}</b><span>${escape(look)}</span></th>${sizes.map((size) => `<td>${item(`back-${name}-${size}.png`)}</td>`).join("")}</tr>`).join("\n")
  const canisterParts = ["canister-cap-top.png", "canister-body.png", "canister-cap-bottom.png"]
  const assembled = canisterParts.map((file) => image(file)).join("")
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>gameble pixel art</title>
<style>
  body { margin: 0; padding: 24px 32px 48px; background: #0b0f15; color: #c7d5e0; font: 15px/1.4 ui-monospace, monospace; }
  h1 { font-size: 20px; margin: 0 0 4px; color: #e6eef5; }
  h2 { font-size: 16px; margin: 40px 0 12px; color: #66c0f4; letter-spacing: 1px; text-transform: uppercase; }
  p { margin: 0 0 12px; max-width: 90ch; }
  img, svg { display: block; image-rendering: pixelated; image-rendering: crisp-edges; }
  .grid { display: flex; flex-wrap: wrap; gap: 20px; align-items: flex-end; }
  figure { margin: 0; display: flex; flex-direction: column; gap: 6px; max-width: 260px; }
  figure .art { display: flex; align-items: flex-end; }
  figcaption { display: flex; flex-direction: column; font-size: 12px; }
  figcaption code { color: #e6eef5; }
  figcaption span, th span { color: #8f98a0; }
  .backs { overflow-x: auto; }
  table { border-collapse: separate; border-spacing: 16px 20px; margin: 0 -16px; }
  th { text-align: left; vertical-align: top; width: 180px; font-weight: normal; font-size: 12px; }
  th b { display: block; color: #e6eef5; font-size: 14px; }
  thead th { vertical-align: bottom; color: #66c0f4; }
  td { vertical-align: bottom; }
  .assembled { display: flex; flex-direction: column; }
  .note { color: #e8833a; }
</style>
</head>
<body>
<h1>gameble pixel art</h1>
<p>Every file in <code>${escape(shown)}/</code> (${files.size} files), as written by <code>script/pixel_art/export.mjs</code>, at 2 CSS px per art pixel.</p>

<h2>Interface icons (story 8.1)</h2>
<div class="grid">
${svgs.map(item).join("\n")}
</div>

<h2>Card backs</h2>
<p>Half of each DESIGN card size, one file per size: the drawing changes with the size.</p>
<div class="backs"><table>
<thead><tr><th></th>${sizes.map((size) => `<th scope="col">card-${size}</th>`).join("")}</tr></thead>
<tbody>
${backRows}
</tbody>
</table></div>

<h2>Booster canister</h2>
<p class="note">The label text (SAISON 1 / GRAND CATALOGUE), the hazard band and the three LEDs are page layers over these images, since they turn orange when the canister is armed; they are not in the files.</p>
<div class="grid">
${canisterParts.map(item).join("\n")}
<figure><div class="art"><div class="assembled">${assembled}</div></div><figcaption><code>assembled</code><span>The three parts stacked, 100 × 150 art px</span></figcaption></figure>
</div>

<h2>Planet</h2>
<div class="grid">
${item("planet.png")}
</div>

<h2>Avatars</h2>
<div class="grid">
${Object.values(AVATARS).map((colour) => item(`avatar-${colour}.png`)).join("\n")}
</div>

<h2>Home-screen icon</h2>
<div class="grid">
${item("favicon.png")}
</div>
</body>
</html>
`
}
