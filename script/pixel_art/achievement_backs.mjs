// The four card backs the hardest achievements unlock, drawn on the anatomy
// of the other backs: a lit and shaded frame, a patterned field, an inner
// line, four corner brackets, a central motif and a 5 x 7 word. A word wider
// than the back less 16 art pixels is dropped, as on every back.
const FRAME_WIDTH = 5
const WORD_MARGIN = 16

export const ACHIEVEMENT_BACK_DESIGNS = [
  { name: "trefle-fane", id: "clover", title: "Trèfle fané", word: "TREFLE", look: "washed-out sage frame, khaki field, a wilted four-leaf clover with two drooping brown leaves and one fallen, TREFLE" },
  { name: "assidu", id: "tick", title: "Assidu", word: "ASSIDU", look: "moss frame, dark hatched field, a chartreuse check mark spilling out of its box over seven filled squares, ASSIDU" },
  { name: "siege-social", id: "tower", title: "Siège social", word: "SIEGE", look: "copper frame, dusk sky, one tower with amber windows over low buildings in silhouette, SIEGE" },
  { name: "contrat", id: "contract", title: "Contrat", word: "PACTE", look: "taupe frame, an ivory contract signed by both parties and closed with a green wax seal, PACTE" },
]

export function drawAchievementBack(g, w, h, design, { mixc, ptext, ptw }) {
  const fill = (x, y, ww, hh, col) => { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), Math.round(ww), Math.round(hh)) }
  const plot = (x, y, col) => fill(x, y, 1, 1, col)
  const cx = (w - 1) / 2, b = FRAME_WIDTH
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v))
  let seed = w * 131 + design.id.length * 977
  const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647

  const frame = (outer, lit, shade, band, well) => {
    fill(0, 0, w, h, outer); fill(0, 0, w, 1, lit); fill(0, 0, 1, h, lit); fill(0, h - 1, w, 1, shade); fill(w - 1, 0, 1, h, shade)
    fill(1, 1, w - 2, h - 2, band); fill(2, 2, w - 4, h - 4, well)
  }
  const field = (colourAt) => {
    for (let y = 3; y < h - 3; y++) for (let x = 3; x < w - 3; x++) plot(x, y, colourAt(x, y))
  }
  const innerLine = (col) => { fill(b, b, w - 2 * b, 1, col); fill(b, h - b - 1, w - 2 * b, 1, col); fill(b, b, 1, h - 2 * b, col); fill(w - b - 1, b, 1, h - 2 * b, col) }
  const brackets = (col) => {
    const length = Math.max(4, Math.round(w * 0.08)), q = b + 2
    for (const [x, y, sx, sy] of [[q, q, 1, 1], [w - q - 1, q, -1, 1], [q, h - q - 1, 1, -1], [w - q - 1, h - q - 1, -1, -1]]) {
      for (let i = 0; i < length; i++) { plot(x + i * sx, y, col); plot(x, y + i * sy, col) }
    }
  }
  const word = (col, shadow, y) => {
    if (ptw(design.word) > w - WORD_MARGIN) return
    const x = Math.round((w - ptw(design.word)) / 2)
    ptext(g, design.word, x, y + 1, shadow)
    ptext(g, design.word, x, y, col)
  }
  const disc = (x, y, radius, colourAt) => {
    for (let py = Math.floor(y - radius); py <= Math.ceil(y + radius); py++) {
      for (let px = Math.floor(x - radius); px <= Math.ceil(x + radius); px++) {
        const distance = Math.hypot(px - x, py - y)
        if (distance <= radius) plot(px, py, colourAt(px - x, py - y, distance / radius))
      }
    }
  }
  const stroke = (x0, y0, x1, y1, thickness, col) => {
    const steps = Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) * 2)
    for (let i = 0; i <= steps; i++) fill(x0 + (x1 - x0) * i / steps - thickness / 2, y0 + (y1 - y0) * i / steps - thickness / 2, thickness, thickness, col)
  }
  const wordY = h - b - 12
  const tools = { fill, plot, cx, w, h, mixc, clamp, random, disc, stroke }

  if (design.id === "clover") {
    frame("#4f5338", "#a3a874", "#26291a", "#2f3322", "#0e0f0a")
    field((x, y) => ((x * 7 + y * 13) % 11 === 0 ? "#1c1d12" : mixc("#16170f", "#0e0f0a", y / h)))
    drawClover(tools)
    innerLine("#4f5338"); brackets("#a3a874"); word("#a3a874", "#0e0f0a", wordY)
  } else if (design.id === "tick") {
    frame("#56661c", "#d4ec6a", "#222a0a", "#37430f", "#0d1105")
    field((x, y) => (((x - y + 999) % 4 === 0) ? "#171f08" : "#0d1105"))
    drawTick(tools)
    innerLine("#56661c"); brackets("#a4d007"); word("#a4d007", "#0d1105", wordY)
  } else if (design.id === "tower") {
    frame("#7a4430", "#d98a5c", "#2e170f", "#4c2a1d", "#140808")
    drawTower(tools)
    innerLine("#7a4430"); brackets("#ffcf9a"); word("#ffcf9a", "#140808", wordY)
  } else {
    frame("#5e5a4a", "#a9a58e", "#26241c", "#3b382d", "#12110d")
    field((x, y) => (((x * 3 + y * 5) % 9 === 0) ? "#1a1913" : "#12110d"))
    drawContract(tools)
    innerLine("#5e5a4a"); brackets("#c9c3a6"); word("#c9c3a6", "#12110d", wordY)
  }
}

function drawClover({ fill, plot, cx, w, h, mixc, disc, stroke }) {
  const radius = Math.max(4, w * 0.11), reach = radius * 1.2
  const centreY = h * 0.34, groundY = Math.round(h * 0.7)
  const pale = "#a3a874", brown = "#7d6440", ink = "#0e0f0a"
  stroke(cx, centreY, cx + radius * 0.4, groundY - 1, Math.max(1, Math.round(w * 0.02)), "#8a7a4c")
  fill(Math.round(w * 0.2), groundY, Math.round(w * 0.6), 1, "#2f3322")
  const leaf = (x, y, base) => disc(x, y, radius, (dx, dy, t) => (t > 0.82 ? mixc(base, ink, 0.55) : mixc(mixc(base, "#ffffff", 0.12), base, (dy + radius) / (2 * radius)) ))
  const vein = (x, y, base) => stroke(cx, centreY, cx + (x - cx) * 0.8, centreY + (y - centreY) * 0.8, 1, mixc(base, ink, 0.45))
  const droop = radius * 0.6
  const leaves = [
    [cx, centreY - reach, pale], [cx - reach, centreY, pale],
    [cx + reach, centreY + droop, brown], [cx, centreY + reach + droop, brown],
  ]
  for (const [x, y, base] of leaves) leaf(x, y, base)
  for (const [x, y, base] of leaves) vein(x, y, base)
  plot(cx, centreY, "#c9cd98")
  const fallenX = cx - radius * 1.6, fallenY = groundY - radius * 0.45
  disc(fallenX, fallenY, radius * 0.45, (_dx, dy, t) => (t > 0.75 ? mixc(brown, ink, 0.55) : mixc("#9a7f52", brown, (dy + radius * 0.45) / (radius * 0.9))))
}

function drawTick({ fill, cx, w, h, stroke }) {
  const side = Math.round(w * 0.5), left = Math.round(cx - side / 2), top = Math.round(h * 0.17)
  const line = Math.max(1, Math.round(w * 0.025)), thickness = Math.max(2, Math.round(w * 0.05))
  fill(left, top, side, side, "#101706")
  fill(left, top, side, line, "#a4d007"); fill(left, top + side - line, side, line, "#a4d007")
  fill(left, top, line, side, "#a4d007"); fill(left + side - line, top, line, side, "#a4d007")
  const point = [left + side * 0.42, top + side * 0.78]
  stroke(left + side * 0.18 + 1, top + side * 0.5 + 1, point[0] + 1, point[1] + 1, thickness, "#222a0a")
  stroke(point[0] + 1, point[1] + 1, left + side * 1.12 + 1, top - side * 0.2 + 1, thickness, "#222a0a")
  stroke(left + side * 0.18, top + side * 0.5, point[0], point[1], thickness, "#d4ec6a")
  stroke(point[0], point[1], left + side * 1.12, top - side * 0.2, thickness, "#d4ec6a")
  const square = Math.max(2, Math.round(w * 0.055)), gap = Math.max(1, Math.round(square * 0.7))
  const rowWidth = 7 * square + 6 * gap, rowLeft = Math.round(cx - rowWidth / 2 + 0.5), rowTop = top + side + Math.round(h * 0.07)
  for (let i = 0; i < 7; i++) {
    fill(rowLeft + i * (square + gap), rowTop, square, square, "#a4d007")
    fill(rowLeft + i * (square + gap), rowTop, square, 1, "#d4ec6a")
  }
}

function drawTower({ fill, plot, cx, w, h, mixc, clamp, random }) {
  const horizon = Math.round(h * 0.76)
  const stops = ["#241632", "#4a2a46", "#7a3a48", "#a84e44", "#c8643c"]
  for (let y = 3; y < h - 3; y++) {
    const t = clamp(y / horizon, 0, 1) * (stops.length - 1), i = Math.min(stops.length - 2, Math.floor(t))
    const band = mixc(stops[i], stops[i + 1], t - i)
    for (let x = 3; x < w - 3; x++) plot(x, y, y >= horizon ? "#140808" : band)
  }
  for (let i = 0; i < w * h / 160; i++) plot(5 + random() * (w - 10), 5 + random() * h * 0.3, random() < 0.4 ? "#ffcf9a" : "#b88a8a")
  const dark = "#140808", window = "#ffcf9a", dim = "#8a5a3a"
  const towerWidth = Math.max(8, Math.round(w * 0.16)), towerLeft = Math.round(cx - towerWidth / 2 + 0.5)
  const towerTop = Math.round(h * 0.17)
  fill(towerLeft, towerTop, towerWidth, horizon - towerTop, dark)
  fill(towerLeft + towerWidth / 2 - 0.5, towerTop - Math.round(h * 0.05), 1, Math.round(h * 0.05), dark)
  fill(towerLeft - 1, towerTop + 2, towerWidth + 2, 2, dark)
  const step = 2
  for (let y = towerTop + 6; y < horizon - 3; y += step + 1) {
    for (let x = towerLeft + 2; x < towerLeft + towerWidth - 2; x += step) plot(x, y, random() < 0.82 ? window : dim)
  }
  let x = 3
  while (x < w - 3) {
    const width = 3 + Math.floor(random() * 5), height = Math.round(h * (0.04 + random() * 0.07))
    if (x + width > towerLeft - 2 && x < towerLeft + towerWidth + 2) { x = towerLeft + towerWidth + 2; continue }
    const right = Math.min(x + width, w - 3)
    fill(x, horizon - height, right - x, height, dark)
    for (let wy = horizon - height + 2; wy < horizon - 2; wy += 3) if (random() < 0.7) plot(x + 1 + Math.floor(random() * Math.max(1, right - x - 2)), wy, window)
    x = right
  }
  fill(3, horizon, w - 6, h - 3 - horizon, dark)
  fill(3, horizon, w - 6, 1, mixc("#c8643c", dark, 0.5))
}

function drawContract({ fill, plot, cx, w, h, mixc, disc }) {
  const paperWidth = Math.round(w * 0.5), paperHeight = Math.round(h * 0.5)
  const left = Math.round(cx - paperWidth / 2 + 0.5), top = Math.round(h * 0.14)
  const ivory = "#f2ecd8", fold = "#cfc8ae", ink = "#7d766a", signature = "#2a3a7a"
  fill(left + 2, top + 2, paperWidth, paperHeight, "#0a0a07")
  fill(left, top, paperWidth, paperHeight, ivory)
  fill(left, top, paperWidth, 1, "#ffffff"); fill(left, top, 1, paperHeight, "#ffffff")
  fill(left + paperWidth - 1, top, 1, paperHeight, fold); fill(left, top + paperHeight - 1, paperWidth, 1, fold)
  const margin = Math.max(3, Math.round(paperWidth * 0.12)), line = Math.max(2, Math.round(h * 0.02))
  const lines = 6
  for (let i = 0; i < lines; i++) {
    const y = top + margin + i * line * 2
    fill(left + margin, y, paperWidth - 2 * margin - (i === lines - 1 ? Math.round(paperWidth * 0.3) : 0), Math.max(1, line - 1), ink)
  }
  const signY = top + paperHeight - margin - 2, signWidth = Math.round((paperWidth - 3 * margin) / 2)
  for (const x0 of [left + margin, left + paperWidth - margin - signWidth]) {
    for (let i = 0; i < signWidth; i++) plot(x0 + i, signY + (Math.floor(i / 2) % 2 === 0 ? 0 : -1), signature)
    fill(x0, signY + 2, signWidth, 1, fold)
  }
  const sealRadius = Math.max(4, w * 0.09), sealX = cx, sealY = top + paperHeight
  for (const direction of [-1, 1]) {
    for (let i = 0; i < Math.round(sealRadius * 1.3); i++) fill(sealX + direction * (1 + i * 0.35) - 1, sealY + sealRadius * 0.4 + i, 3, 1, i % 3 === 2 ? "#2f7a52" : "#1f5a3a")
  }
  disc(sealX, sealY, sealRadius, (dx, dy, t) => (t > 0.85 ? "#12351f" : t > 0.62 ? mixc("#3f8a5e", "#1f5a3a", (dy + sealRadius) / (2 * sealRadius)) : mixc("#2f7a52", "#1f5a3a", (dy + sealRadius) / (2 * sealRadius))))
  fill(sealX - 1, sealY - 1, 2, 2, "#b6dcc0")
}
