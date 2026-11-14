// The feed's decors: one faint pixel scene behind each kind of entry, drawn on
// a grid of 4 CSS px. Each decor comes in two layouts, both anchored to the
// entry's bottom right corner: "post", the phone post, and "row", the wide
// desktop row. A scene lights cells at an intensity from 0 to 1;
// the file keeps them at a low opacity, so the decor dresses the entry without
// competing with its text.
const CELL = 4
const OPACITY = 0.13
const LAYOUTS = { post: [96, 80], row: [320, 40] }

const COLOURS = {
  pull: "#66c0f4",
  discovery: "#f4c542",
  trade: "#a4d007",
  repost: "#b5e2ff",
  set: "#c4945e",
  "set-complete": "#c4945e",
  sale: "#e8833a",
  verdict: "#ff5a6a",
}

const LOOKS = {
  pull: "a large card shining, a diagonal glint, a halo and sparkles",
  discovery: "hills under the stars, a flag planted on the highest",
  trade: "two cards facing each other, a straight arrow each way between them",
  repost: "a broadcast tower sending square waves",
  set: "terraces climbing to a pennant",
  "set-complete": "a wall of tiles, all filled",
  sale: "a mountain of piled PiCoins",
  verdict: "the Flukeometer's histogram, its last bar crowned",
}

const COIN = [".ccccc.", "c.....c", "c.ccc.c", "c..c.cc", "c..c..c", ".ccccc."]
const SPARKLE = ["..c..", "..c..", "ccccc", "..c..", "..c.."]
const GLINT = [".c.", "ccc", ".c."]
const CROWN = ["c...c...c", "cc.ccc.cc", "ccccccccc", "c.ccccc.c", "ccccccccc"]
const TILE = ["ccccc", "c...c", "c...c", "c...c", "ccccc"]
const ARROW_RIGHT = ["c..", "cc.", "ccc", "cc.", "c.."]
const ARROW_LEFT = ["..c", ".cc", "ccc", ".cc", "..c"]

function scene(columns, rows, random) {
  const cells = new Map()
  const put = (x, y, intensity) => {
    if (x < 0 || y < 0 || x >= columns || y >= rows || intensity <= 0) return
    const key = y * columns + x
    cells.set(key, Math.max(cells.get(key) ?? 0, Math.min(1, intensity)))
  }
  const rect = (x, y, width, height, intensity) => {
    for (let i = 0; i < width; i++) for (let j = 0; j < height; j++) put(x + i, y + j, intensity)
  }
  const sprite = (grid, x, y, intensity) => grid.forEach((line, j) => [...line].forEach((ch, i) => {
    if (ch === "c") put(x + i, y + j, intensity)
    else if (ch === "d") put(x + i, y + j, intensity * 0.45)
  }))
  const dither = (x, y, intensity) => { if ((x + y) % 2 === 0) put(x, y, intensity) }
  const stars = (count, height) => {
    for (let i = 0; i < count; i++) put(Math.floor(random() * columns), Math.floor(random() * height), 0.35 + random() * 0.4)
  }
  const hill = (x, peaks) => peaks.reduce((h, [centre, width, top]) => Math.max(h, top * Math.exp(-(((x - centre) / width) ** 2))), 0)
  const card = (x0, y0, width, height, fill) => {
    for (let x = 0; x < width; x++) for (let y = 0; y < height; y++) {
      if (x === 0 || y === 0 || x === width - 1 || y === height - 1) put(x0 + x, y0 + y, 1)
      else fill(x, y)
    }
  }
  return { cells, put, rect, sprite, dither, stars, hill, card, columns, rows }
}

function drawPull({ put, rect, sprite, stars, card, columns: C, rows: R }) {
  stars(Math.floor(C * R / 160), R)
  const height = Math.min(R - 12, 40), width = Math.round(height * 0.7)
  const x0 = C - width - 14, y0 = Math.round((R - height) / 2)
  const cx = x0 + width / 2, cy = y0 + height / 2
  for (let i = 0; i < 12; i++) {
    const angle = i / 12 * Math.PI * 2
    for (let r = Math.round(height * 0.6); r < height * 1.4; r += 2) {
      put(Math.round(cx + Math.cos(angle) * r), Math.round(cy + Math.sin(angle) * r), 0.6 - r / (height * 2.6))
    }
  }
  rect(x0 - 1, y0 - 1, width + 2, height + 2, 0.15)
  card(x0, y0, width, height, (x, y) => {
    const inner = (x === 2 || y === 2 || x === width - 3 || y === height - 3) && x > 1 && y > 1 && x < width - 2 && y < height - 2
    const band = x + y - Math.round(height * 0.55)
    if (inner) put(x0 + x, y0 + y, 0.55)
    else if (band >= 0 && band < 6) put(x0 + x, y0 + y, 0.95)
    else if (band >= 8 && band < 10) put(x0 + x, y0 + y, 0.7)
    else if (x > 3 && x < width - 4 && y > height * 0.15 && y < height * 0.6 && (x + y) % 2 === 0) put(x0 + x, y0 + y, 0.3)
  })
  sprite(SPARKLE, x0 - 8, y0 + 4, 1)
  sprite(GLINT, x0 + width + 4, y0 + 2, 1)
  sprite(SPARKLE, x0 + width + 3, y0 + height - 9, 1)
  sprite(GLINT, x0 - 6, y0 + height - 6, 1)
  sprite(GLINT, x0 + Math.round(width / 2), y0 - 6, 1)
}

function drawDiscovery({ put, rect, stars, hill, columns: C, rows: R }) {
  stars(Math.floor(C * R / 60), R * 0.7)
  const far = [[C * 0.2, C * 0.25, R * 0.35], [C * 0.6, C * 0.3, R * 0.42], [C * 0.95, C * 0.2, R * 0.3]]
  const near = [[C * 0.8, C * 0.16, R * 0.62], [C * 0.35, C * 0.2, R * 0.25]]
  for (let x = 0; x < C; x++) {
    const farTop = Math.round(R - hill(x, far)), nearTop = Math.round(R - hill(x, near))
    for (let y = farTop; y < nearTop; y++) if ((x + y) % 4 === 0) put(x, y, 0.6)
    put(x, farTop, 0.7)
    for (let y = nearTop; y < R; y++) put(x, y, y === nearTop ? 1 : 0.75)
  }
  const fx = Math.round(C * 0.8), fy = Math.round(R - hill(C * 0.8, near))
  rect(fx, fy - 12, 1, 12, 1)
  rect(fx + 1, fy - 12, 7, 4, 1)
  rect(fx + 1, fy - 8, 5, 1, 1)
}

function drawTrade({ put, sprite, stars, card, columns: C, rows: R }) {
  stars(Math.floor(C * R / 160), R)
  const height = Math.min(R - 12, 30), width = Math.round(height * 0.7), y0 = Math.round((R - height) / 2)
  const right = C - 12 - width, left = right - Math.max(26, Math.round(C * 0.12)) - width
  ;[left, right].forEach((x0, k) => card(x0, y0, width, height, (x, y) => {
    if ((x + y + k) % 2 === 0 && y > height * 0.15 && y < height * 0.6 && x > 2 && x < width - 3) put(x0 + x, y0 + y, 0.35)
  }))
  const from = left + width + 4, to = right - 4
  const upper = y0 + Math.round(height * 0.35), lower = y0 + Math.round(height * 0.65)
  for (let x = from; x <= to; x++) { put(x, upper, 1); put(x, lower, 1) }
  sprite(ARROW_RIGHT, to - 2, upper - 2, 1)
  sprite(ARROW_LEFT, from, lower - 2, 1)
}

function drawRepost({ put, rect, columns: C, rows: R }) {
  const cx = Math.round(C * 0.82), base = R - 1, top = base - 18
  for (let r = 10; r < Math.min(C * 0.4, 60); r += 7) {
    const intensity = 1 - r / (C * 1.6)
    for (let x = cx - r; x <= cx + r; x++) if ((x + r) % 2 === 0) put(x, top - r, intensity)
    for (let y = top - r; y <= top + r; y++) if ((y + r) % 2 === 0) { put(cx - r, y, intensity); put(cx + r, y, intensity) }
  }
  for (let y = top; y <= base; y++) {
    const half = Math.round((y - top) / 3)
    put(cx - half, y, 1)
    put(cx + half, y, 1)
    if (y % 3 === 0) rect(cx - half, y, 2 * half + 1, 1, 0.6)
  }
  rect(cx - 1, top - 3, 3, 3, 1)
}

function drawSet({ put, rect, dither, stars, columns: C, rows: R }) {
  stars(Math.floor(C * R / 160), R * 0.5)
  const steps = 7, stepWidth = Math.ceil(C / steps), stepHeight = Math.max(3, Math.floor(R * 0.75 / steps))
  for (let s = 0; s < steps; s++) {
    const top = R - (s + 1) * stepHeight
    for (let x = s * stepWidth; x < Math.min(C, (s + 1) * stepWidth); x++) {
      put(x, top, 1)
      for (let y = top + 1; y < R; y++) dither(x, y, 0.55)
    }
    for (let y = top; y < R; y++) put(s * stepWidth, y, 0.9)
  }
  const fx = C - Math.round(stepWidth / 2), fy = R - steps * stepHeight
  rect(fx, fy - 10, 1, 10, 1)
  rect(fx - 6, fy - 10, 6, 4, 1)
}

function drawSetComplete({ rect, sprite, columns: C, rows: R }) {
  const step = 7
  for (let gx = 0; gx * step < C; gx++) for (let gy = 0; gy * step < R; gy++) {
    const lit = (gx * 7 + gy * 3) % 5 === 0 ? 1 : 0.55
    rect(gx * step + 1, gy * step + 1, step - 2, step - 2, lit * 0.7)
    sprite(TILE, gx * step + 1, gy * step + 1, lit)
  }
}

function drawSale({ put, rect, sprite, stars, hill, columns: C, rows: R }, random) {
  stars(Math.floor(C * R / 160), R * 0.5)
  const peaks = [[C * 0.78, C * 0.2, R * 0.62], [C * 0.45, C * 0.16, R * 0.38], [C * 0.12, C * 0.14, R * 0.26]]
  for (let x = 0; x < C; x += 8) {
    const top = Math.round(R - 2 - hill(x + 4, peaks)), offset = Math.floor(random() * 3) - 1
    for (let y = R - 2; y > top; y -= 2) {
      rect(x + offset, y, 7, 1, 0.9)
      put(x + offset - 1 + (y % 4 ? 0 : 8), y, 0.3)
    }
    if (top < R - 6 && random() < 0.55) sprite(COIN, x + offset, top - 6, 1)
  }
  for (let i = 0; i < C / 18; i++) sprite(COIN, Math.floor(random() * (C - 7)), Math.floor(random() * R * 0.35), 0.5)
}

function drawVerdict({ put, sprite, dither, stars, columns: C, rows: R }) {
  const width = 4, bars = Math.min(18, Math.floor(C * 0.5 / width)), x0 = C - bars * width - 10, top = R - Math.round(R * 0.62)
  for (let i = 0; i < bars; i++) {
    const t = (i - bars * 0.42) / (bars * 0.2), last = i === bars - 1
    const height = last ? R - top : Math.max(1, Math.round(R * 0.45 * Math.exp(-t * t)))
    for (let y = R - height; y < R; y++) for (let x = 0; x < width - 1; x++) {
      if (y === R - height || last) put(x0 + i * width + x, y, last ? 1 : 0.75)
      else dither(x0 + i * width + x, y, 0.6)
    }
  }
  sprite(CROWN, x0 + (bars - 1) * width - 3, top - 7, 1)
  for (let x = x0 - 6; x < C; x += 2) put(x, top + 3, 0.35)
  stars(Math.floor(C * R / 160), R * 0.4)
}

const DRAW = {
  pull: drawPull,
  discovery: drawDiscovery,
  trade: drawTrade,
  repost: drawRepost,
  set: drawSet,
  "set-complete": drawSetComplete,
  sale: drawSale,
  verdict: drawVerdict,
}

function decorSvg(kind, columns, rows, random) {
  const canvas = scene(columns, rows, random)
  DRAW[kind](canvas, random)
  const runs = new Map()
  for (let y = 0; y < rows; y++) {
    let x = 0
    while (x < columns) {
      const level = Math.round((canvas.cells.get(y * columns + x) ?? 0) * 10)
      let end = x + 1
      while (end < columns && Math.round((canvas.cells.get(y * columns + end) ?? 0) * 10) === level) end++
      if (level > 0) {
        if (!runs.has(level)) runs.set(level, [])
        runs.get(level).push(`M${x} ${y}h${end - x}v1h-${end - x}z`)
      }
      x = end
    }
  }
  const body = [...runs.entries()].sort(([a], [b]) => a - b)
    .map(([level, d]) => `<path fill-opacity="${+(OPACITY * level / 10).toFixed(3)}" d="${d.join("")}"/>`).join("")
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${columns} ${rows}" width="${columns * CELL}" height="${rows * CELL}" shape-rendering="crispEdges"><g fill="${COLOURS[kind]}">${body}</g></svg>\n`
}

export function feedDecors(random) {
  const files = new Map()
  const descriptions = {}
  Object.keys(DRAW).forEach((kind, k) => {
    for (const [layout, [columns, rows]] of Object.entries(LAYOUTS)) {
      const file = `feed-decor-${kind}-${layout}.svg`
      files.set(file, decorSvg(kind, columns, rows, random(20261114 + k)))
      descriptions[file] = `Feed decor behind a ${kind.replace("-", " ")} entry, ${layout === "post" ? "phone post" : "wide row"}: ${LOOKS[kind]}, ${columns} × ${rows} cells of ${CELL} CSS px`
    }
  })
  return { files, descriptions }
}
