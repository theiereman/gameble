#!/usr/bin/env node
// Exports the interface's pixel art (Rarity, Typography's glyphs,
// Chrome, Card backs, Booster canister, Showcase, Avatars) as static
// files in app/frontend/images/pixel/.
//
// The icons are SVG. Each is a character grid, one character per
// art pixel:
//   "."  transparent
//   "c"  currentColor (the icon takes the colour of its text)
//   any other character: the fixed colour its icon's legend gives it.
// One art pixel is 2 CSS px: the viewBox is in art pixels, width and height
// are twice that. Pixels are merged into runs per row and colour, one <path>
// per colour, with crisp edges. `starfield` is the exception: a seeded tile
// of 2px and 4px stars, in CSS px.
//
// The card backs, the canister, the planet and the avatars are
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
import { SET_BACK_DESIGNS, drawSetBack, setBackName } from "./set_backs.mjs"
import { NAMED_BACK_DESIGNS } from "./named_backs.mjs"
import { EMBLEM_SIZE, ORIGIN_LOOKS, drawEmblem, originBodyFile } from "./origin_canisters.mjs"
import { NEBULA_HEIGHT, NEBULA_WIDTH, drawNebula } from "./nebula.mjs"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const ART_PIXEL = 2

// Design colours used by the fixed-colour icons.
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
// edge. They must stay distinct in grayscale.
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

// The compact rarity set for card faces, 5 × 5 (rarity icon):
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

// The diagonal shine: a 2 px band, a 1 px gap and a 1 px thin band, from
// the diagonal x + y = start.
function shines(x, y, start) {
  if (start === null) return false
  const s = x + y - start
  return (s >= 0 && s < 2) || s === 3
}

function goldColours(mask, shineStart = null) {
  const rows = mask.length
  return mask.map((line, y) => line.map((on, x) => {
    if (!on) return null
    const tier = goldTier(y, rows)
    if (shines(x, y, shineStart)) return GOLD_LIFTS[tier]
    if (y === 0 || !mask[y - 1][x]) return GOLD_EDGE
    return GOLD_TIERS[tier]
  }))
}

const wordmarkMask = () => setLetters("GAMEBLE")
const WORDMARK_PALETTE = [...new Set([...GOLD_TIERS, ...GOLD_LIFTS])]
const WORDMARK_LEGEND = Object.fromEntries(WORDMARK_PALETTE.map((colour, i) => [String(i), colour]))
const wordmarkGrid = (colours) => colours.map((line) => line.map((colour) => colour === null ? "." : String(WORDMARK_PALETTE.indexOf(colour))).join(""))

// Where the shine rests, in the wordmark's first third.
function wordmarkRestShine(mask) {
  const middle = Math.round(mask[0].length * 0.17) + Math.round(mask.length / 2)
  return middle - 2
}

// The band's starts, frame by frame, as the hover sweep plays them after
// the rest frame: rightward 4 art pixels a frame past the last letter, then
// in from the left, ending one step short of the rest shine.
const WORDMARK_SWEEP = [
  ...Array.from({ length: 16 }, (_, i) => 18 + 4 * i),
  ...Array.from({ length: 6 }, (_, i) => -10 + 4 * i),
]

function wordmarkIcon() {
  const mask = wordmarkMask()
  return { legend: WORDMARK_LEGEND, grid: wordmarkGrid(goldColours(mask, wordmarkRestShine(mask))) }
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

// The phone's back button: the gold G drawn for the Discord server, larger
// than the favicon's, outlined in near-black with a sparkle and a shine.
const BACK_G = {
  legend: { o: "#120d05", s: "#4a3105", w: "#ffffff", 1: "#fff3c4", l: "#ffe08a", 2: "#f4c542", 3: "#d99a1f", 4: "#8f5e0a" },
  grid: [
    ".....oooooooooooooooooooooooooooooooo",
    "...1.o111111111111111111111111111111o",
    "..1w1o111111111111111111111111111111o",
    ".1www1111111111111111111111111111111o",
    "..1w1o111111111111111111111111111111o",
    "ooo1oo111111111111111111111111111111o",
    "o11111111111111111111111111111111111o",
    "o11111111111111111111111111111111111o",
    "o11111111111111111111111111111111111o",
    "o11111111111111111111111111111111111o",
    "o22222222222222222222222222222222222o",
    "o2222222222oooooooooooooooooooooooooo",
    "o2222222222osssssssssssssssssssssssss",
    "o2222222222osssssssssssssssssssssssss",
    "o2222222222osssssssssssssssssssssssss",
    "o2222222222o.........................",
    "o2222222222o.........................",
    "o2222222222o.........................",
    "o2222222222o.........................",
    "o2222222222o.........................",
    "o2222222222o........ooooooooooooooooo",
    "o2222222222o........o111111111111111o",
    "o2222222222o........o222222222222222o",
    "o2222222222o........o222222222222222o",
    "o2222222222o........o222222222222222o",
    "o3333333333o........o333333333333333o",
    "o3333333333o........o333333333333333o",
    "o3333333333o........o333333333333333o",
    "o3333333333o........o333333333333333o",
    "o3333333333o........o33333333333333lo",
    "o3333333333o........o3333333333333llo",
    "o3333333333o........oooooo3333333lllo",
    "o3333333333o........ssssso333333llllo",
    "o3333333333o........ssssso33333lllllo",
    "o3333333333o........ssssso3333llllllo",
    "o3333333333ooooooooooooooo333lllllllo",
    "o333333333311111111111111133llllllllo",
    "o44444444444444444444444444333333334o",
    "o44444444444444444444444443333333344o",
    "o44444444444444444444444433333333443o",
    "o44444444444444444444444333333334433o",
    "oooooo444444444444444443333333344334o",
    "ssssso444444444444444433333333443344o",
    "ssssso444444444444444333333334433444o",
    "ssssso444444444444443333333344334444o",
    ".....o444444444444433333333443344444o",
    ".....oooooooooooooooooooooooooooooooo",
    ".....ssssssssssssssssssssssssssssssss",
    ".....ssssssssssssssssssssssssssssssss",
    ".....ssssssssssssssssssssssssssssssss",
  ],
}

const ACHIEVEMENT_GLYPHS = {
  pack: [".#####.", "#######", "#.....#", "#.###.#", "#.#.#.#", "#.....#", "#######"],
  gem: ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
  star: ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"],
  set: ["###.###", "#.#.#.#", "###.###", ".......", "###.###", "#.#.#.#", "###.###"],
  trade: ["....#..", "######.", "....#..", ".......", "..#....", ".######", "..#...."],
  outlier: ["......#", ".......", "..###..", ".#...#.", ".#...#.", "##...##", "#######"],
  card: [".####..", "#....#.", "#.##.##", "#....##", "#.##.##", "#....##", ".######"],
  duplicate: ["#####..", "#.#####", "#.##.##", "#.##.##", "#.#####", "#.##.##", "..#####"],
  tokens: [".......", ".#.#.#.", ".#.#.#.", ".......", "..#.#..", "..#.#..", "......."],
  hourglass: ["###....", "#.#....", ".#..###", ".#..#.#", ".#..###", "#.#....", "###...."],
  clover: [".##.##.", ".##.##.", "..###..", ".##.#..", "....#..", "...#...", "...#..#"],
  refused: ["#######", "#######", "##...##", "#.#.#.#", "#..#..#", "#.#.#.#", "#######"],
  skip: ["#..#...", ".#..#..", "..#..#.", "...#..#", "..#..#.", ".#..#..", "#..#..."],
  revealed: [".#####.", ".#.#.#.", ".#####.", "#.#.#.#", "#######", ".#####.", "..###.."],
  fan: ["#.###.#", ".#.#.#.", "..###..", "..###..", ".#####.", ".#####.", "......."],
  tower: ["...#...", "..###..", "..#.#..", "..###..", "#.#.#.#", "#######", "#######"],
  flag: [".####..", ".###...", ".#.....", ".#.....", "#######", "#.....#", "#######"],
  lens: [".###...", "#.#.#..", "#####..", "#.#.#..", ".###.#.", "......#", "......."],
  clasp: ["...#...", "..###..", "...#...", "..###..", ".#####.", "#######", ".#.#.#."],
  stopwatch: ["..###..", "...#..#", ".#####.", "##.#.##", "#..#..#", "##...##", ".#####."],
  moon: ["..####.", ".###...", "###...#", "###....", "###.#..", ".###...", "..####."],
}
const ACHIEVEMENT_EARNED = { h: "#d2efff", b: "#66c0f4", s: "#2a6f9a" }
const ACHIEVEMENT_LOCKED = { h: "#8f98a0", b: "#5d6b78", s: "#3d4a57" }

function achievementIcon(cells, legend) {
  const side = cells.length * 2
  const filled = (x, y) => x >= 0 && y >= 0 && x < side && y < side && cells[y >> 1][x >> 1] === "#"
  const shade = (x, y) => !filled(x, y - 1) ? "h" : !filled(x, y + 1) || !filled(x + 1, y) ? "s" : "b"
  const grid = Array.from({ length: side }, (_, y) => Array.from({ length: side }, (_, x) => filled(x, y) ? shade(x, y) : ".").join(""))
  return { legend, grid }
}

const achievementIcons = () => Object.fromEntries(Object.entries(ACHIEVEMENT_GLYPHS).flatMap(([glyph, cells]) => [
  [`achievement-${glyph}`, achievementIcon(cells, ACHIEVEMENT_EARNED)],
  [`achievement-${glyph}-locked`, achievementIcon(cells, ACHIEVEMENT_LOCKED)],
]))

// The ranks' insignia, told apart by shape alone: one to three chevrons
// stacked every 3 rows, one 9-pixel star, two 7-pixel stars 2 columns apart.
const RANK_CHEVRON = ["....c....", "...ccc...", "..cc.cc..", ".cc...cc.", "cc.....cc"]
const RANK_STAR9 = ["....c....", "...ccc...", "...ccc...", "ccccccccc", ".ccccccc.", "..ccccc..", "..ccccc..", ".ccc.ccc.", ".cc...cc."]
const RANK_STAR7 = ["...c...", "..ccc..", "ccccccc", ".ccccc.", "..ccc..", ".cc.cc.", ".c...c."]

function stacked(shape, count, stride) {
  const rows = Array.from({ length: shape.length + stride * (count - 1) }, () => [...".".repeat(shape[0].length)])
  for (let k = 0; k < count; k++) shape.forEach((row, y) => [...row].forEach((ch, x) => { if (ch === "c") rows[y + stride * k][x] = "c" }))
  return rows.map((row) => row.join(""))
}

const RANK_MARKS = {
  novice: stacked(RANK_CHEVRON, 1, 3),
  apprentice: stacked(RANK_CHEVRON, 2, 3),
  adept: stacked(RANK_CHEVRON, 3, 3),
  expert: RANK_STAR9,
  master: RANK_STAR7.map((row, y) => `${row}..${RANK_STAR7[y]}`),
}

const ICONS = {
  wordmark: wordmarkIcon(),
  ...Object.fromEntries(Object.entries(RANK_MARKS).map(([rank, grid]) => [`rank-${rank}`, { grid }])),
  favicon: faviconIcon(),
  "back-g": BACK_G,
  ...Object.fromEntries(Object.entries(RARITY_SHAPES).map(([tier, grid]) => [`rarity-${tier}`, { legend: RARITY[tier], grid }])),
  ...Object.fromEntries(Object.entries(RARITY_COMPACT_SHAPES).map(([tier, grid]) => [`rarity-compact-${tier}`, { legend: RARITY[tier], grid }])),
  ...achievementIcons(),
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
  // A missing card's padlock (10 × 12, missing-card slot): a
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
  // An open eye (11 × 7): who sees a setting, beside a section's heading.
  eye: {
    grid: [
      "...ccccc...",
      ".cc.....cc.",
      "c...ccc...c",
      "c...ccc...c",
      "c...ccc...c",
      ".cc.....cc.",
      "...ccccc...",
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
  // ⋯ more actions
  more: {
    grid: [
      "cc..cc..cc",
      "cc..cc..cc",
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
  // + (8 × 8): the new set tile's add mark.
  plus: {
    grid: [
      "...cc...",
      "...cc...",
      "...cc...",
      "cccccccc",
      "cccccccc",
      "...cc...",
      "...cc...",
      "...cc...",
    ],
  },
  // An "i" in a rounded frame (9 × 9): a short explanation beside a heading.
  info: {
    grid: [
      ".ccccccc.",
      "c.......c",
      "c...c...c",
      "c.......c",
      "c..cc...c",
      "c...c...c",
      "c..ccc..c",
      "c.......c",
      ".ccccccc.",
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
  // The merged counter's standard capsule: a round-ended pill, blue (7 × 11).
  "capsule-standard": {
    legend: { o: OUTLINE, a: "#66c0f4", b: "#2f4f6c" },
    grid: [
      "..ooo..",
      ".oaaao.",
      "oaaaaao",
      "oaaaaao",
      "oaaaaao",
      "obbbbbo",
      "obbbbbo",
      "obbbbbo",
      "obbbbbo",
      ".obbbo.",
      "..ooo..",
    ],
  },
  // The merged counter's special capsule: a lime diamond (9 × 9).
  "capsule-special": {
    legend: { o: OUTLINE, l: "#a4d007", d: "#5c7a0c" },
    grid: [
      "....o....",
      "...olo...",
      "..olllo..",
      ".olllllo.",
      "olllllllo",
      ".odllldo.",
      "..oddlo..",
      "...odo...",
      "....o....",
    ],
  },
  // The player's portrait until they choose an avatar (16 × 16).
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
  // Novice: a blue hood, the face in shadow, two pale eyes, a gold clasp (16 × 16).
  "avatar-novice": {
    legend: { k: "#1b2838", h: "#66c0f4", s: "#2a6f9a", d: "#14324a", e: "#0b1520", w: "#d2efff", g: "#f4c542" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkkkhhkkkkkkk",
      "kkkkkkhhhhkkkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkhhhsshhhkkkk",
      "kkkhhhseeshhhkkk",
      "kkkhhseeeeshhkkk",
      "kkkhhsweewshhkkk",
      "kkkhhseeeeshhkkk",
      "kkkhhhseeshhhkkk",
      "kkhhhhhsshhhhhkk",
      "kshhhhhhhhhhhhsk",
      "sshhhhhgghhhhhss",
      "ssshhhsddshhhsss",
      "sssshhsddshhssss",
      "sssshhsddshhssss",
    ],
  },
  // Archivist: a green hood, a face with brass spectacles (16 × 16).
  "avatar-archivist": {
    legend: { k: "#1b2838", h: "#3fcf8e", s: "#16684a", d: "#0d3f2d", f: "#f2c9a0", n: "#c08a62", e: "#0b1520", o: "#d2efff", y: "#8f5e0a" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkhhhhhhhhkkkk",
      "kkkhhhsssshhhkkk",
      "kkkhhsnffnshhkkk",
      "kkhhsnffffnshhkk",
      "kkhhsyyffyyshhkk",
      "kkhhyeoyyoeyhhkk",
      "kkhhsyyffyyshhkk",
      "kkhhsnffffnshhkk",
      "kkkhhsnnnnshhkkk",
      "kkhhhhsssshhhhkk",
      "khhhhhhhhhhhhhhk",
      "shhhhhhddhhhhhhs",
      "sshhhhhddhhhhhss",
      "sshhhhhddhhhhhss",
    ],
  },
  // Guardian: a steel helm with a red crest and a T visor, pauldrons, a gold emblem on the chest (16 × 16).
  "avatar-guardian": {
    legend: { k: "#1b2838", h: "#dfe6ec", m: "#8f98a0", s: "#4d5866", e: "#0b1520", r: "#e05a4f", g: "#f4c542", y: "#8f5e0a" },
    grid: [
      "kkkkkkkrrkkkkkkk",
      "kkkkkkrrrrkkkkkk",
      "kkkkkmmhhmmkkkkk",
      "kkkkmmhhhhmmkkkk",
      "kkkmmhhhhhhmmkkk",
      "kkkmmhhhhhhmmkkk",
      "kkkmmeeeeeemmkkk",
      "kkkmmhheehhmmkkk",
      "kkkmmhheehhmmkkk",
      "kkkkmmheehmmkkkk",
      "kkkkkmmmmmmkkkkk",
      "kmmhkksssskkhmmk",
      "mmhhhsggggshhhmm",
      "mhhhssgyygsshhhm",
      "mmhhssyggysshhmm",
      "smmhsssssssshmms",
    ],
  },
  // Oracle: a violet hood with a green gem, the face in shadow, two pale eyes (16 × 16).
  "avatar-oracle": {
    legend: { k: "#1b2838", h: "#b47cff", s: "#55308f", d: "#2c1850", e: "#0b1520", w: "#ead9ff", j: "#3fcf8e", l: "#b2f7d4" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkkhhhhkkkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkhhhljhhhkkkk",
      "kkkhhhhjjhhhhkkk",
      "kkkhhsseesshhkkk",
      "kkhhseeeeeeshhkk",
      "kkhhseweeweshhkk",
      "kkhhseeeeeeshhkk",
      "kkhhsseeeesshhkk",
      "kkhhhsseesshhhkk",
      "khhhhhsssshhhhhk",
      "hhhhhhhsshhhhhhh",
      "shhhhhhsshhhhhhs",
      "sshhhhhddhhhhhss",
      "dshhhhhddhhhhhsd",
    ],
  },
  // Grand master: a red hood, a gold crown, a white beard, a gold stole (16 × 16).
  "avatar-grand-master": {
    legend: { k: "#1b2838", h: "#e05a4f", s: "#8a2a24", d: "#4a1412", g: "#f4c542", y: "#8f5e0a", f: "#f2c9a0", e: "#0b1520", b: "#f4f1e8", q: "#c7c2b4" },
    grid: [
      "kkkkkkkggkkkkkkk",
      "kkkkkgkggkgkkkkk",
      "kkkkkggggggkkkkk",
      "kkkkhyyyyyyhkkkk",
      "kkkhhgggggghhkkk",
      "kkkhhsffffshhkkk",
      "kkhhsffffffshhkk",
      "kkhhsfeffefshhkk",
      "kkhhsffffffshhkk",
      "kkhhsbbbbbbshhkk",
      "kkhhsbqbbqbshhkk",
      "khhhhsbbbbshhhhk",
      "hhhhhhsbbshhhhhh",
      "shhhhhgggghhhhhs",
      "sshhhhgyyghhhhss",
      "dshhhhgyyghhhhsd",
    ],
  },
  // Mechanic: a round afro, gold earrings, orange overalls over a white tee (16 × 16).
  "avatar-mechanic": {
    legend: { k: "#1b2838", a: "#3a2620", b: "#5c3d2e", f: "#7a4a2b", n: "#5a3420", e: "#0b1520", m: "#c0604a", g: "#f4c542", o: "#f08a3c", p: "#a8521c", t: "#dfe6ec" },
    grid: [
      "kkkkkaaaaaakkkkk",
      "kkkaaaaaaaaaakkk",
      "kkaaabaaaabaaakk",
      "kaabaaaaaaaabaak",
      "kaaaaaffffaaaaak",
      "kaaaffffffffaaak",
      "kaaafeffffefaaak",
      "kaaaffffffffaaak",
      "kaaanffmmffnaaak",
      "kkagnffffffngakk",
      "kkkkknffffnkkkkk",
      "kkkoottnnttookkk",
      "kooooptootpooook",
      "ooooppooooppoooo",
      "oooopoooooopoooo",
      "pooopoooooopooop",
    ],
  },
  // Pilot: red hair, freckles, flight goggles on the forehead, a leather jacket with a fleece collar (16 × 16).
  "avatar-pilot": {
    legend: { k: "#1b2838", r: "#d9662b", q: "#9a3f17", f: "#f7d7b8", n: "#d9a582", z: "#c0704a", e: "#0b1520", g: "#4a3326", l: "#66c0f4", m: "#b06a50", j: "#8a5a32", i: "#5c3a1e", c: "#f4f1e8" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkrrrrrrrrkkkk",
      "kkkrrrrrrrrrrkkk",
      "kkrrrqrrrrqrrrkk",
      "kkggllggggllggkk",
      "kkrrffffffffrrkk",
      "kkrrfeffffefrrkk",
      "kkkrnzffffznrkkk",
      "kkkknffmmffnkkkk",
      "kkkkknffffnkkkkk",
      "kkkkkkffffkkkkkk",
      "kkjjccffffccjjkk",
      "kjjjccjjjjccjjjk",
      "jjjjjcijjicjjjjj",
      "jjjjjcijjicjjjjj",
      "ijjjjcijjicjjjji",
    ],
  },
  // Cartographer: bald, a grey beard, a violet turtleneck (16 × 16).
  "avatar-cartographer": {
    legend: { k: "#1b2838", f: "#b5784a", n: "#8a5530", y: "#d39a6c", b: "#c7c2b4", w: "#f4f1e8", e: "#0b1520", t: "#b47cff", u: "#55308f" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkkkkkkkkkkkk",
      "kkkkkffyfffkkkkk",
      "kkkkffyfffffkkkk",
      "kkkffffffffffkkk",
      "kkknffffffffnkkk",
      "kknnfeffffefnnkk",
      "kkknffffffffnkkk",
      "kkknfbbbbbbfnkkk",
      "kkkbbwbbbbwbbkkk",
      "kkkkbbbwwbbbkkkk",
      "kkkkuubwwbuukkkk",
      "kktttuuuuuutttkk",
      "ktttttuuuutttttk",
      "tttttttuuttttttt",
      "utttttuttutttttu",
    ],
  },
  // Botanist: a teal hijab draped over an ochre top, a leaf pinned on the chest (16 × 16).
  "avatar-botanist": {
    legend: { k: "#1b2838", h: "#2fb5a8", s: "#17675f", f: "#d9a066", n: "#a8733f", e: "#0b1520", m: "#8a4a2a", y: "#e0a43a", v: "#9a6a1e", l: "#a4d007", d: "#5c7a0c" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkkhhhhhhkkkkk",
      "kkkkhhhhhhhhkkkk",
      "kkkhhhhhhhhhhkkk",
      "kkhhhsssssshhhkk",
      "kkhhsffffffshhkk",
      "kkhhsfeffefshhkk",
      "kkhhsffffffshhkk",
      "kkhhsnfmmfnshhkk",
      "kkhhhsnffnshhhkk",
      "kkhhhhsssshhhhkk",
      "kkhhhhhhhhhhhhkk",
      "khhldhhhhhhhhhhk",
      "yyhdlhhhhhhhhhyy",
      "yyyhhhhhhhhhhyyy",
      "vyyyhhhhhhhhyyyv",
    ],
  },
  // Streamer: a black bob with a pink streak, a headset with a mic, a pink hoodie (16 × 16).
  "avatar-streamer": {
    legend: { k: "#1b2838", a: "#0b0f16", r: "#ff6fae", c: "#dfe6ec", x: "#8f98a0", f: "#e8b98a", n: "#b98556", e: "#0b1520", m: "#b0605a", p: "#ff6fae", q: "#b23a76" },
    grid: [
      "kkkkkkkkkkkkkkkk",
      "kkkkaaaaaaaakkkk",
      "kkkcccccccccckkk",
      "kkcaaaaaaaarackk",
      "kkaaaaaaaaaarakk",
      "kccaaffffffaacck",
      "kccaafeffefaacck",
      "kccaaffffffaacck",
      "kccaaffmmffaacck",
      "kkkxaanffnaaakkk",
      "kkkkxxnffnkkkkkk",
      "kkppppqqqqppppkk",
      "kpppppqppqpppppk",
      "ppppppqppqpppppp",
      "ppppppqppqpppppp",
      "qppppppppppppppq",
    ],
  },
  // The pencil on the player's own portrait, which opens the avatar choice (8 × 8, text colour).
  pencil: {
    grid: [
      "......c.",
      ".....ccc",
      "....ccc.",
      "...ccc..",
      "..ccc...",
      ".ccc....",
      ".cc.....",
      "c.......",
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
  "tab-capsule": {
    grid: [
      "...........",
      "...ccccc...",
      "..c.....c..",
      "..c.....c..",
      "..c.....c..",
      "..ccccccc..",
      "..ccccccc..",
      "..c.....c..",
      "..c.....c..",
      "...ccccc...",
      "...........",
    ],
  },
  "tab-sets": {
    grid: [
      "ccccc.ccccc",
      "c...c.c...c",
      "c...c.c...c",
      "c...c.c...c",
      "ccccc.ccccc",
      "...........",
      "ccccc.ccccc",
      "c...c.c...c",
      "c...c.c...c",
      "c...c.c...c",
      "ccccc.ccccc",
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
  "tab-friends": {
    grid: [
      "...........",
      ".ccc...ccc.",
      ".c.c...c.c.",
      ".ccc...ccc.",
      "...........",
      "ccccc.ccccc",
      "c...c.c...c",
      "c...c.c...c",
      "c...c.c...c",
      "ccccc.ccccc",
      "...........",
    ],
  },
  "tab-me": {
    grid: [
      "...ccccc...",
      "...c...c...",
      "...c...c...",
      "...ccccc...",
      "...........",
      ".ccccccccc.",
      ".c.......c.",
      ".c.......c.",
      ".c.......c.",
      ".ccccccccc.",
      "...........",
    ],
  },
  // The phone header's menu, beside the bell: three bars (text colour).
  menu: {
    grid: [
      "ccccccc",
      ".......",
      ".......",
      "ccccccc",
      ".......",
      ".......",
      "ccccccc",
    ],
  },
  // The header's bell, beside the player chip (7 × 8): a dome flaring to its rim, b body, h lit edge, l shaded edge.
  bell: {
    legend: RARITY[5],
    grid: [
      "..hbl..",
      ".hbbbl.",
      ".hbbbl.",
      ".hbbbl.",
      "hbbbbbl",
      "lllllll",
      ".......",
      "..hbl..",
    ],
  },
}

// One run-length path per fill: each row's runs of a symbol, `top` rows down.
function rowRuns(name, grid, legend = {}, paths = new Map(), top = 0) {
  const width = grid[0].length
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
        paths.get(fill).push(`M${x} ${top + y}h${end - x}v1h-${end - x}z`)
      }
      x = end
    }
  })
  return paths
}

const pathsSvg = (paths) => [...paths.entries()].map(([fill, d]) => `<path fill="${fill}" d="${d.join("")}"/>`).join("")

function pixelSvg(width, height, body) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width * ART_PIXEL}" height="${height * ART_PIXEL}" shape-rendering="crispEdges">${body}</svg>\n`
}

function iconSvg(name, { grid, legend = {} }) {
  return pixelSvg(grid[0].length, grid.length, pathsSvg(rowRuns(name, grid, legend)))
}

// The top bar's wordmark under a hovering mouse: the wordmark without its
// shine, then a strip of shine overlays one wordmark high each, frame 0 the
// rest shine and the next ones the band's sweep. The SVG clips the strip to
// frame 0; the stylesheet steps it up a frame at a time (styles/shell-top-bar.css).
function wordmarkSweepSvg() {
  const mask = wordmarkMask()
  const rows = mask.length
  const shineOnly = (start) => mask.map((line, y) => line.map((on, x) => on && shines(x, y, start) ? GOLD_LIFTS[goldTier(y, rows)] : null))
  const frames = new Map()
  ;[wordmarkRestShine(mask), ...WORDMARK_SWEEP].forEach((start, frame) =>
    rowRuns("wordmark-sweep", wordmarkGrid(shineOnly(start)), WORDMARK_LEGEND, frames, frame * rows))
  const base = pathsSvg(rowRuns("wordmark-sweep", wordmarkGrid(goldColours(mask)), WORDMARK_LEGEND))
  return pixelSvg(mask[0].length, rows, `${base}<g class="wordmark-sweep__frames">${pathsSvg(frames)}</g>`)
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

// The star field's tile (atmosphere): 2px and 4px squares of
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
// Drawn art: the card backs, the canister, the planet and the
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

// The standard back, the one every player starts with; the set backs'
// anatomy is drawn after it.
function standardBack(w, h) {
  const g = canvas(w, h)
  const P = (x, y, col) => { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), 1, 1) }
  const F = (x, y, ww, hh, col) => { g.fillStyle = col; g.fillRect(x, y, ww, hh) }
  const b = 5, cx = (w - 1) / 2, cy = (h - 1) / 2
  const inner = (col) => { F(b, b, w - 2 * b, 1, col); F(b, h - b - 1, w - 2 * b, 1, col); F(b, b, 1, h - 2 * b, col); F(w - b - 1, b, 1, h - 2 * b, col) }
  const brackets = (col) => {
    const L = Math.max(4, Math.round(w * 0.08)), q = b + 2
    for (const [x, y, sx, sy] of [[q, q, 1, 1], [w - q - 1, q, -1, 1], [q, h - q - 1, 1, -1], [w - q - 1, h - q - 1, -1, -1]]) {
      for (let i = 0; i < L; i++) { P(x + i * sx, y, col); P(x, y + i * sy, col) }
    }
  }
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
  return g
}

// The booster canister (booster canister), 100 × 150 art pixels in
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
  const STANDARD_BAND = { top: "#e6f6ff", second: "#b5e2ff", body: "#66c0f4", stripe: "#5cb6ea", dark: "#2a6f9a", edge: "#1f5a80" }
  function body(band = STANDARD_BAND, origin = null) {
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
        let col = y === 15 ? band.top : y === 16 ? band.second : y === 49 ? band.edge : y === 48 ? band.dark : (y % 3 === 0 ? band.stripe : band.body)
        if (t < 0.04) col = mixc(col, "#ffffff", 0.22); else if (t > 0.75) col = mixc(col, band.edge, (t - 0.75) * 1.7)
        pc(g, x, y, col)
      }
    }
    for (const x0 of [4, W - 14]) for (let y = 19; y <= 45; y++) for (let x = x0; x < x0 + 10; x++) if (((x + y) >> 1) % 3 === 0) pc(g, x, y, band.dark)
    const wx = 35, wy = 55, ww = 30, wh = 32 // emblem window
    rc(g, wx - 1, wy - 1, ww + 2, wh + 2, "#06090d"); rc(g, wx, wy, ww, wh, "#c7d5e0"); rc(g, wx, wy, ww, 1, "#f2f7fb"); rc(g, wx, wy, 1, wh, "#f2f7fb")
    rc(g, wx, wy + wh - 1, ww, 1, "#8f98a0"); rc(g, wx + ww - 1, wy, 1, wh, "#8f98a0")
    for (let y = wy + 2; y < wy + wh - 2; y++) {
      for (let x = wx + 2; x < wx + ww - 2; x++) pc(g, x, y, mixc("#1c3954", "#0b1119", Math.min(1, Math.hypot(x - (wx + ww / 2 - 0.5), y - (wy + wh / 2 - 0.5)) / 15)))
    }
    rc(g, wx + 2, wy + 2, ww - 4, 1, "#06090d"); rc(g, wx + 2, wy + 2, 1, wh - 4, "#06090d")
    const mk = 2
    if (origin) drawEmblem(g, wx + (ww - EMBLEM_SIZE + 1) / 2 | 0, wy + (wh - EMBLEM_SIZE) / 2 | 0, origin)
    else drawMonogram(g, wx + (ww - MONOGRAM_WIDTH * mk) / 2, wy + (wh - MONOGRAM_HEIGHT * mk) / 2, mk)
    for (const [x, y] of [[5, 7], [93, 7], [5, 100], [93, 100]]) { rc(g, x, y, 2, 2, "#8f98a0"); pc(g, x, y, "#f2f7fb"); pc(g, x + 1, y + 1, "#3d4a57") } // rivets
    rc(g, 65, 89, 28, 12, "#06090d"); rc(g, 66, 90, 26, 10, "#121a24"); rc(g, 66, 99, 26, 1, "#2a475e") // LED plate (the LEDs are a page layer)
    rc(g, 7, 89, 48, 8, "#06090d") // hazard frame (the band is a page layer)
    for (let x = 8; x < 54; x++) { if ((x * 7) % 5 < 2) continue; rc(g, x, 99, 1, (x * 3) % 4 ? 3 : 5, "#5d6b7c") } // barcode
    return g
  }
  return { top: cap(true), body: body(), bottom: cap(false), origins: ORIGIN_LOOKS.map((look) => [look, body(look.band, look)]) }
})()

// The ringed planet under the hub showcase (showcase), 200 × 200.
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

// The standard back, drawn for each card size: half of each DESIGN card
// size, since one art pixel is 2 CSS px. The drawing depends on the size, so
// each size is its own file. The named and set backs share these sizes.
const STANDARD_BACK = { name: "standard", title: "Standard", look: "slate frame, diagonal weave, blue ring with gold ticks, the gold G monogram, GAMEBLE" }
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
files.set("wordmark-sweep.svg", wordmarkSweepSvg())
files.set("starfield.svg", starfieldSvg())
files.set("nebula.png", drawNebula())
for (const [size, [w, h]] of Object.entries(CARD_SIZES)) files.set(`back-${STANDARD_BACK.name}-${size}.png`, standardBack(w / 2 | 0, h / 2 | 0))
for (const design of NAMED_BACK_DESIGNS) {
  for (const [size, [w, h]] of Object.entries(CARD_SIZES)) {
    const g = canvas(w / 2 | 0, h / 2 | 0)
    drawSetBack(g, g.width, g.height, design, { mixc, ptext, ptw })
    files.set(`back-${design.name}-${size}.png`, g)
  }
}
for (const design of SET_BACK_DESIGNS) {
  for (const [size, [w, h]] of Object.entries(CARD_SIZES)) {
    const g = canvas(w / 2 | 0, h / 2 | 0)
    drawSetBack(g, g.width, g.height, design, { mixc, ptext, ptw })
    files.set(`back-${setBackName(design)}-${size}.png`, g)
  }
}
files.set("canister-cap-top.png", CANISTER.top)
files.set("canister-body.png", CANISTER.body)
files.set("canister-cap-bottom.png", CANISTER.bottom)
for (const [look, body] of CANISTER.origins) files.set(originBodyFile(look), body)
files.set("planet.png", drawPlanet())
files.set("favicon.png", faviconPng())
for (const [key, colour] of Object.entries(AVATARS)) files.set(`avatar-${colour}.png`, avatarCanvas(key))

// One line per file for the review sheet; the script refuses to run when a
// file has none.
const TIER_NAMES = ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"]
const TIER_SHAPES = ["solid disc", "ring inside a ring", "diamond", "triangle", "star"]
const DESCRIPTIONS = {
  "wordmark.svg": "The gameble wordmark: flat gold GAMEBLE with a lit top edge and a diagonal shine, 66 × 9",
  "wordmark-sweep.svg": "The top bar's wordmark under a hovering mouse: the wordmark without shine and a strip of 23 shine frames, the rest shine then the 22-step sweep, 66 × 9",
  "favicon.svg": "Favicon: the wordmark's gold G, 9 × 9",
  "back-g.svg": "The phone's back button: the Discord server's gold G, outlined, with a sparkle, 37 × 50",
  ...Object.fromEntries(TIER_NAMES.map((tier, i) => [`rarity-${i + 1}.svg`, `${tier} rarity icon, ${TIER_SHAPES[i]}, 7 × 7`])),
  ...Object.fromEntries(TIER_NAMES.map((tier, i) => [`rarity-compact-${i + 1}.svg`, `${tier} rarity icon for card faces, ${TIER_SHAPES[i]}, 5 × 5`])),
  ...Object.fromEntries(Object.entries(ACHIEVEMENT_GLYPHS).flatMap(([glyph]) => [
    [`achievement-${glyph}.svg`, `Achievement icon, ${glyph}, earned (blue), 14 × 14`],
    [`achievement-${glyph}-locked.svg`, `Achievement icon, ${glyph}, not yet earned (grey), 14 × 14`],
  ])),
  "picture.svg": "Missing cover art: a frame, a sun and a mountain (text colour)",
  "lock.svg": "A missing card's padlock on its empty slot (10 × 12, text colour)",
  "eye.svg": "An open eye, who sees a section's setting, 11 × 7 (text colour)",
  "arrow-left.svg": "◀ arrow (text colour)",
  "arrow-right.svg": "▶ arrow (text colour)",
  "arrow-small-right.svg": "▸ small arrow for links (text colour)",
  "close.svg": "✕ close and remove (text colour)",
  "check.svg": "✓ check mark (text colour)",
  "plus.svg": "+ add mark, the new set tile's, 8 × 8 (text colour)",
  "more.svg": "⋯ more actions, the menu of a row's rarer actions (text colour)",
  "info.svg": "An \"i\" in a rounded frame, the info mark beside a heading, 9 × 9 (text colour)",
  "rank-novice.svg": "Novice rank mark: one chevron, 9 × 5 (text colour)",
  "rank-apprentice.svg": "Apprentice rank mark: two stacked chevrons, 9 × 8 (text colour)",
  "rank-adept.svg": "Adept rank mark: three stacked chevrons, 9 × 11 (text colour)",
  "rank-expert.svg": "Expert rank mark: one five-point star, 9 × 9 (text colour)",
  "rank-master.svg": "Master rank mark: two five-point stars, 16 × 7 (text colour)",
  "diamond.svg": "◆ ticker separator (text colour)",
  "swap.svg": "⇄ trade swap (text colour)",
  "external.svg": "↗ external link (text colour)",
  "hourglass.svg": "⧗ hourglass for expiry and pending (text colour)",
  "canister-small.svg": "The packs chip's small canister, 8 × 11",
  "avatar-default.svg": "The player's portrait until they choose an avatar, 16 × 16",
  "avatar-novice.svg": "Avatar: the novice, a blue hood, the face in shadow, a gold clasp, 16 × 16",
  "avatar-archivist.svg": "Avatar: the archivist, a green hood, brass spectacles, 16 × 16",
  "avatar-guardian.svg": "Avatar: the guardian, a steel helm with a red crest, a gold emblem, 16 × 16",
  "avatar-oracle.svg": "Avatar: the oracle, a violet hood with a green gem, the face in shadow, 16 × 16",
  "avatar-grand-master.svg": "Avatar: the grand master, a red hood, a gold crown, a white beard, 16 × 16",
  "avatar-mechanic.svg": "Avatar: the mechanic, a round afro, gold earrings, orange overalls, 16 × 16",
  "avatar-pilot.svg": "Avatar: the pilot, red hair, freckles, flight goggles, a leather jacket, 16 × 16",
  "avatar-cartographer.svg": "Avatar: the cartographer, bald, a grey beard, a violet turtleneck, 16 × 16",
  "avatar-botanist.svg": "Avatar: the botanist, a teal hijab, a leaf pinned on the chest, 16 × 16",
  "avatar-streamer.svg": "Avatar: the streamer, a black bob with a pink streak, a headset, a pink hoodie, 16 × 16",
  "pencil.svg": "✎ pencil on the player's own portrait, choose an avatar, 8 × 8 (text colour)",
  "capsule-standard.svg": "The merged counter's standard capsule: a blue pill, 7 × 11",
  "capsule-special.svg": "The merged counter's special capsule: a lime diamond, 9 × 9",
  "tab-hub.svg": "Phone tab bar icon: PONT (text colour)",
  "tab-collection.svg": "Phone tab bar icon: COLLECTION (text colour)",
  "tab-capsule.svg": "Phone tab bar icon: CAPSULE, a vertical pill (text colour)",
  "tab-sets.svg": "Phone tab bar icon: SETS, four tiles (text colour)",
  "tab-trades.svg": "Phone tab bar icon: ÉCHANGES, two opposed arrows (text colour)",
  "tab-friends.svg": "Phone tab bar icon: AMIS, two heads and shoulders (text colour)",
  "tab-me.svg": "Phone tab bar icon: ME, one head and shoulders (text colour)",
  "bell.svg": "The header's bell, what is new for the player, 7 × 8",
  "menu.svg": "The phone header's menu: profile, settings and the extras (text colour)",
  "starfield.svg": "Star field tile, 480 × 480 CSS px, repeated under the content",
  "nebula.png": `Nebula tile behind the star field: faint blue and violet clouds and a pale band of the galaxy, ${NEBULA_WIDTH} × ${NEBULA_HEIGHT}, drawn at 4 CSS px per pixel`,
  ...Object.fromEntries([STANDARD_BACK, ...NAMED_BACK_DESIGNS].flatMap(({ name, title }) => Object.entries(CARD_SIZES).map(([size, [w, h]]) =>
    [`back-${name}-${size}.png`, `${title} back for card-${size}, ${w / 2 | 0} × ${h / 2 | 0} art px`]))),
  ...Object.fromEntries(SET_BACK_DESIGNS.flatMap((design) => Object.entries(CARD_SIZES).map(([size, [w, h]]) =>
    [`back-${setBackName(design)}-${size}.png`, `${design.word} back of the ${design.key} ${design.kind.replace(/_/g, " ")} set for card-${size}, ${w / 2 | 0} × ${h / 2 | 0} art px`]))),
  "canister-cap-top.png": "Canister top cap: steel grip, collar, indicator window, 100 × 20",
  "canister-body.png": "Canister body: slate cylinder, label band, emblem window with the gold G monogram, rivets, LED plate, barcode, 100 × 110",
  "canister-cap-bottom.png": "Canister bottom cap: steel grip and collar, 100 × 20",
  ...Object.fromEntries(ORIGIN_LOOKS.map((look) => [originBodyFile(look),
    `${look.title} canister body: the label band and the window's ${look.emblemName} emblem in the origin's colour, 100 × 110`])),
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
  const backRows = [STANDARD_BACK, ...NAMED_BACK_DESIGNS].map(({ name, title, look }) =>
    `<tr><th scope="row"><b>${escape(title)}</b><span>${escape(look)}</span></th>${sizes.map((size) => `<td>${item(`back-${name}-${size}.png`)}</td>`).join("")}</tr>`).join("\n")
  const setBackRows = SET_BACK_DESIGNS.map((design) =>
    `<tr><th scope="row"><b>${escape(design.word)}</b><span>${escape(`${design.key}, ${design.kind.replace(/_/g, " ")} set`)}</span></th>${sizes.map((size) => `<td>${item(`back-${setBackName(design)}-${size}.png`)}</td>`).join("")}</tr>`).join("\n")
  const canisterParts = ["canister-cap-top.png", "canister-body.png", "canister-cap-bottom.png", ...ORIGIN_LOOKS.map(originBodyFile)]
  const assembled = canisterParts.slice(0, 3).map((file) => image(file)).join("")
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

<h2>Interface icons</h2>
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

<h2>Set backs</h2>
<p>The back of each set, earned at half its cards: one word and one motif per set, one file per size.</p>
<div class="backs"><table>
<thead><tr><th></th>${sizes.map((size) => `<th scope="col">card-${size}</th>`).join("")}</tr></thead>
<tbody>
${setBackRows}
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

<h2>Nebula</h2>
<div class="grid">
${item("nebula.png")}
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
