// The anatomy shared by the 47 set backs: a frame, a field, an inner line,
// corner brackets, a ring with the set's motif and its one-word lettering.
// A hall of fame back adds a second inner line and lightens its frame. The
// colours come from the design's two colours; the motif is scaled by the
// largest whole number that keeps it inside the ring and centred on it.
import { SET_BACK_DESIGNS } from "./set_back_designs.mjs"

export { SET_BACK_DESIGNS }

const GROUND = "#0b0f15"
const OUTLINE = "#06090d"
const FRAME_WIDTH = 5
const LETTERING_MARGIN = 16

const MOTIF_COLOURS = {
  r: "#d6403a", R: "#8e2420", o: "#e8833a", y: "#fff09a", Y: "#f4c542", w: "#e6eef5", g: "#8f98a0", G: "#4a5560",
  n: "#c4945e", N: "#7a5530", s: "#ffc49a", m: "#3fcf8e", M: "#1f7f55", u: "#66c0f4", U: "#2a6f9a", p: "#ff9ad5",
  v: "#b47cff", k: "#10161e",
}

export const setBackName = ({ kind, key }) => `${kind}-${key}`

function motifLayout(motif, ringRadius) {
  const filled = []
  motif.forEach((row, y) => [...row].forEach((cell, x) => { if (cell !== ".") filled.push([x, y]) }))
  const xs = filled.map(([x]) => x), ys = filled.map(([, y]) => y)
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys)
  const centreX = (minX + maxX + 1) / 2, centreY = (minY + maxY + 1) / 2
  const reach = Math.max(...filled.map(([x, y]) => Math.hypot(Math.abs(x + 0.5 - centreX) + 0.5, Math.abs(y + 0.5 - centreY) + 0.5)))
  return { minX, maxX, minY, maxY, scale: Math.max(1, Math.floor((ringRadius - 1) / reach)) }
}

export function drawSetBack(g, width, height, design, { mixc, ptext, ptw }) {
  const { kind, word, primary, secondary, motif } = design
  const hallOfFame = kind === "hall_of_fame"
  const fill = (x, y, w, h, colour) => { g.fillStyle = colour; g.fillRect(x, y, w, h) }
  const plot = (x, y, colour) => fill(Math.round(x), Math.round(y), 1, 1, colour)
  const frameLine = (inset, colour) => {
    fill(inset, inset, width - 2 * inset, 1, colour)
    fill(inset, height - inset - 1, width - 2 * inset, 1, colour)
    fill(inset, inset, 1, height - 2 * inset, colour)
    fill(width - inset - 1, inset, 1, height - 2 * inset, colour)
  }

  const ringRadius = width * 0.3
  const layout = motifLayout(motif, ringRadius)
  const scale = layout.scale
  const motifWidth = (layout.maxX - layout.minX + 1) * scale
  const motifHeight = (layout.maxY - layout.minY + 1) * scale
  const left = Math.round(width / 2 - motifWidth / 2)
  const top = Math.round(height / 2 - height * 0.04 - motifHeight / 2)
  const centreX = left + motifWidth / 2 - 0.5
  const centreY = top + motifHeight / 2 - 0.5

  const edge = mixc(primary, GROUND, 0.55)
  const lit = mixc(primary, "#ffffff", hallOfFame ? 0.35 : 0.1)
  const shade = mixc(primary, GROUND, 0.85)
  const band = mixc(primary, GROUND, 0.72)
  const well = mixc(primary, GROUND, 0.92)
  fill(0, 0, width, height, edge)
  fill(0, 0, width, 1, lit)
  fill(0, 0, 1, height, lit)
  fill(0, height - 1, width, 1, shade)
  fill(width - 1, 0, 1, height, shade)
  fill(1, 1, width - 2, height - 2, band)
  fill(2, 2, width - 4, height - 4, well)

  const fieldLight = mixc(primary, GROUND, 0.88)
  for (let y = 3; y < height - 3; y++) {
    for (let x = 3; x < width - 3; x++) {
      const fade = (y / height) * 0.35
      const weave = ((x + y) >> 1) % 3 === 0
      plot(x, y, weave ? mixc(mixc(primary, GROUND, 0.84), GROUND, fade) : mixc(fieldLight, GROUND, fade))
    }
  }
  const line = mixc(primary, GROUND, 0.7)
  frameLine(FRAME_WIDTH, line)
  if (hallOfFame) frameLine(FRAME_WIDTH + 2, primary)

  const bracketLength = Math.max(4, Math.round(width * 0.08))
  const corner = FRAME_WIDTH + 2 + (hallOfFame ? 2 : 0)
  for (const [x, y, dx, dy] of [[corner, corner, 1, 1], [width - corner - 1, corner, -1, 1], [corner, height - corner - 1, 1, -1], [width - corner - 1, height - corner - 1, -1, -1]]) {
    for (let i = 0; i < bracketLength; i++) {
      plot(x + i * dx, y, secondary)
      plot(x, y + i * dy, secondary)
    }
  }

  const ringFloor = mixc(primary, GROUND, 0.8)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const distance = Math.hypot(x - centreX, y - centreY)
      if (distance < ringRadius - 1.2) plot(x, y, mixc(ringFloor, GROUND, (distance / ringRadius) * 0.6))
      else if (Math.abs(distance - ringRadius) < 0.62) plot(x, y, primary)
      else if (Math.abs(distance - (ringRadius + 5)) < 0.5 && (x + y) & 1) plot(x, y, edge)
    }
  }
  for (let i = 0; i < 32; i++) {
    const angle = (i / 32) * Math.PI * 2
    const long = i % 8 === 0
    for (let r = ringRadius + 2; r <= ringRadius + (long ? 4.2 : 3); r += 0.5) {
      plot(centreX + Math.cos(angle) * r, centreY + Math.sin(angle) * r, long ? secondary : mixc(primary, GROUND, 0.45))
    }
  }

  const palette = {
    ...MOTIF_COLOURS,
    x: primary,
    d: mixc(primary, GROUND, 0.45),
    l: mixc(primary, "#ffffff", 0.35),
    h: mixc(primary, "#ffffff", 0.7),
    b: secondary,
    e: mixc(secondary, GROUND, 0.45),
  }
  const covered = new Map()
  motif.forEach((row, gridY) => [...row].forEach((cell, gridX) => {
    const colour = palette[cell]
    if (cell === "." || !colour) return
    const originX = left + (gridX - layout.minX) * scale
    const originY = top + (gridY - layout.minY) * scale
    for (let dy = 0; dy < scale; dy++) {
      for (let dx = 0; dx < scale; dx++) {
        const x = originX + dx, y = originY + dy
        if (x >= 0 && y >= 0 && x < width && y < height) covered.set(y * width + x, colour)
      }
    }
  }))
  const isCovered = (x, y) => x >= 0 && y >= 0 && x < width && y < height && covered.has(y * width + x)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (covered.has(y * width + x)) continue
      if (isCovered(x - 1, y) || isCovered(x + 1, y) || isCovered(x, y - 1) || isCovered(x, y + 1)) fill(x, y, 1, 1, OUTLINE)
    }
  }
  for (const [index, colour] of covered) fill(index % width, Math.floor(index / width), 1, 1, colour)

  if (ptw(word) <= width - LETTERING_MARGIN) {
    const x = Math.round((width - ptw(word)) / 2)
    const y = height - FRAME_WIDTH - 12
    ptext(g, word, x, y + 1, OUTLINE)
    ptext(g, word, x, y, secondary)
  }
  for (let x = FRAME_WIDTH + 4; x < width - FRAME_WIDTH - 4; x += 3) plot(x, height - FRAME_WIDTH - 16, line)
}
