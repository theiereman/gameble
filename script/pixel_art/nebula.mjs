// The nebula tile (atmosphere): faint clouds of blue and violet gas behind
// the star field, and a pale band of the galaxy across them. Every noise lattice wraps around the tile, so the tile
// repeats with no seam in both directions. Alpha is quantised to a few
// levels with an ordered dither, so the clouds read as pixel art.

export const NEBULA_WIDTH = 480
export const NEBULA_HEIGHT = 720

const BAYER = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
].map((row) => row.map((v) => (v + 0.5) / 16))

const CLOUDS = [
  { seed: 20261104, colour: [42, 111, 154], strength: 0.8, threshold: 0.52 },
  { seed: 20261105, colour: [112, 84, 186], strength: 0.7, threshold: 0.56 },
]
const BAND = { seed: 20261106, colour: [150, 168, 196], width: 0.11, strength: 0.9 }
const ALPHA_STEP = 0.0075
const ALPHA_MAX = 0.06
const WARP = 0.18

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

const smooth = (t) => t * t * (3 - 2 * t)

function periodicNoise(seed, period) {
  const next = random(seed)
  const values = Float64Array.from({ length: period * period }, next)
  const at = (x, y) => values[((y % period) + period) % period * period + ((x % period) + period) % period]
  return (u, v) => {
    const x = u * period, y = v * period
    const x0 = Math.floor(x), y0 = Math.floor(y)
    const tx = smooth(x - x0), ty = smooth(y - y0)
    const top = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * tx
    const bottom = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * tx
    return top + (bottom - top) * ty
  }
}

function fractal(seed, periods = [2, 4, 8, 16, 32, 64]) {
  const octaves = periods.map((period, i) => ({ noise: periodicNoise(seed + i * 7919, period), weight: 0.55 ** i }))
  const total = octaves.reduce((sum, { weight }) => sum + weight, 0)
  return (u, v) => octaves.reduce((sum, { noise, weight }) => sum + noise(u, v) * weight, 0) / total
}

function warped(seed) {
  const shape = fractal(seed)
  const warpU = fractal(seed + 101)
  const warpV = fractal(seed + 202)
  return (u, v) => shape(u + WARP * (warpU(u, v) - 0.5), v + WARP * (warpV(u, v) - 0.5))
}

function cloudDensity({ seed, threshold, strength }) {
  const shape = warped(seed)
  return (u, v) => Math.max(0, Math.min(1, (shape(u, v) - threshold) / (1 - threshold) * 2.4)) * strength
}

// One diagonal band, from the tile's top-left corner to its bottom-right, wraps
// onto itself across the tile's edges; dark dust lanes cut through it.
function bandDensity({ seed, width, strength }) {
  const along = warped(seed)
  const dust = warped(seed + 31)
  const length = Math.hypot(NEBULA_WIDTH, NEBULA_HEIGHT)
  const spacing = NEBULA_WIDTH * NEBULA_HEIGHT / length
  return (u, v) => {
    const x = u * NEBULA_WIDTH, y = v * NEBULA_HEIGHT
    const offset = (x * NEBULA_HEIGHT - y * NEBULA_WIDTH) / length
    const distance = Math.abs((((offset + spacing / 2) % spacing) + spacing) % spacing - spacing / 2) / spacing
    const wobble = (along(u, v) - 0.5) * 0.12
    const core = Math.exp(-(((distance + wobble) / width) ** 2))
    const rift = Math.max(0, (dust(u, v) - 0.5) * 3)
    return Math.max(0, core * (0.55 + along(u, v)) - rift * core) * strength
  }
}

export function drawNebula() {
  const width = NEBULA_WIDTH, height = NEBULA_HEIGHT
  const rgba = Buffer.alloc(width * height * 4)
  const sources = [...CLOUDS.map((cloud) => ({ colour: cloud.colour, density: cloudDensity(cloud) })), { colour: BAND.colour, density: bandDensity(BAND) }]
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const u = x / width, v = y / height
      const amounts = sources.map(({ density }) => density(u, v))
      const total = amounts.reduce((a, b) => a + b, 0)
      const alpha = Math.min(ALPHA_MAX, total * ALPHA_MAX)
      const level = Math.min(ALPHA_MAX, Math.floor(alpha / ALPHA_STEP + BAYER[y % 4][x % 4]) * ALPHA_STEP)
      if (level <= 0) continue
      const colour = [0, 1, 2].map((c) => Math.round(sources.reduce((sum, { colour }, i) => sum + colour[c] * amounts[i], 0) / total))
      rgba.set([...colour, Math.round(level * 255)], (y * width + x) * 4)
    }
  }
  return { width, height, rgba }
}
