#!/usr/bin/env node
// Exports the interface's pixel-art icons (DESIGN.md: Rarity, Typography's
// glyphs, Chrome; AD-27) as static SVG files in app/frontend/images/pixel/.
// Each icon is a character grid, one character per art pixel:
//   "."  transparent
//   "c"  currentColor (the icon takes the colour of its text)
//   any other character: the fixed colour its icon's legend gives it.
// One art pixel is 2 CSS px: the viewBox is in art pixels, width and height
// are twice that. Pixels are merged into runs per row and colour, one <path>
// per colour, with crisp edges. `starfield` is the exception: a seeded tile
// of 2px and 4px stars, in CSS px.
//
//   node script/pixel_art/export.mjs          # writes the files
//   node script/pixel_art/export.mjs --check  # exits 1 when a file differs
//
// The output is deterministic: running it again changes no file.
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const out = join(root, "app/frontend/images/pixel")
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

const ICONS = {
  // The gameble logo: two stacked cards and a gold mark (12 × 12).
  logo: {
    legend: { T: "#3d6c8c", B: "#2a475e", H: "#b5e2ff", F: "#66c0f4", D: "#171a21", G: "#f4c542" },
    grid: [
      "....TTTTTTT.",
      "....BBBBBBB.",
      "....BBBBBBB.",
      ".HHHHHHHBBB.",
      ".FDDDDDFBBB.",
      ".FDDDDDFBBB.",
      ".FDDGDDFBBB.",
      ".FDGGGDFBBB.",
      ".FDDGDDFBBB.",
      ".FDDDDDF....",
      ".FDDDDDF....",
      ".FFFFFFF....",
    ],
  },
  ...Object.fromEntries(Object.entries(RARITY_SHAPES).map(([tier, grid]) => [`rarity-${tier}`, { legend: RARITY[tier], grid }])),
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

const files = new Map(Object.entries(ICONS).map(([name, icon]) => [`${name}.svg`, iconSvg(name, icon)]))
files.set("starfield.svg", starfieldSvg())

const check = process.argv.includes("--check")
if (check) {
  const differing = [...files].filter(([file, svg]) => {
    const path = join(out, file)
    return !existsSync(path) || readFileSync(path, "utf8") !== svg
  }).map(([file]) => file)
  const stray = existsSync(out) ? readdirSync(out).filter((file) => !files.has(file)) : []
  if (differing.length || stray.length) {
    for (const file of differing) console.error(`differs: app/frontend/images/pixel/${file}`)
    for (const file of stray) console.error(`not exported: app/frontend/images/pixel/${file}`)
    console.error("Run node script/pixel_art/export.mjs and commit the result.")
    process.exit(1)
  }
  console.log(`${files.size} pixel-art files up to date`)
} else {
  mkdirSync(out, { recursive: true })
  for (const [file, svg] of files) writeFileSync(join(out, file), svg)
  console.log(`${files.size} pixel-art files written to app/frontend/images/pixel/`)
}
