import type { Pixels } from "pixelcrush"

export const SAMPLE_WIDTH = 96

const MIN_SAMPLE_ROWS = 24
const SHARP_RATIO = 0.35
const MIN_SHARP_DETAIL = 12
const MAX_GAP_ROWS = 2
const MIN_BAND_WIDTHS = 0.4
const MAX_BAND_WIDTHS = 0.7
const MIN_PADDING = 0.2
const PADDING_CONTRAST = 0.4

export type Band = { start: number; end: number }

/** Steam builds some covers from a wide banner: a sharp band between two blurred fills of its colours. */
export function findSharpBand({ width, height, data }: Pixels): Band | null {
  if (height < MIN_SAMPLE_ROWS || width < 2) return null
  const detail = rowDetail(width, height, data)
  const threshold = Math.max(MIN_SHARP_DETAIL, SHARP_RATIO * percentile(detail, 0.8))
  const run = longestSharpRun(detail, threshold)
  if (!run) return null

  const [first, last] = run
  const rows = last - first + 1
  if (rows < MIN_BAND_WIDTHS * width || rows > MAX_BAND_WIDTHS * width) return null
  if ((height - rows) / height < MIN_PADDING) return null
  if (mean(padding(detail, first, last)) > PADDING_CONTRAST * mean(detail.slice(first, last + 1))) return null

  // The rows at each edge straddle the band and its fill.
  const start = first + 1
  const end = last
  return { start: start / height, end: end / height }
}

function rowDetail(width: number, height: number, data: Uint8ClampedArray): number[] {
  const luma = (x: number, y: number) => {
    const at = (y * width + x) * 4
    return 0.299 * data[at] + 0.587 * data[at + 1] + 0.114 * data[at + 2]
  }
  const detail: number[] = []
  for (let y = 0; y < height; y++) {
    let sum = 0
    for (let x = 0; x < width; x++) {
      const here = luma(x, y)
      if (x + 1 < width) sum += Math.abs(luma(x + 1, y) - here)
      if (y + 1 < height) sum += Math.abs(luma(x, y + 1) - here)
    }
    detail.push(sum / width)
  }
  return detail
}

function longestSharpRun(detail: number[], threshold: number): [number, number] | null {
  let best: [number, number] | null = null
  let first = -1
  let last = -1
  const close = () => {
    if (first >= 0 && (!best || last - first > best[1] - best[0])) best = [first, last]
  }
  detail.forEach((value, row) => {
    if (value < threshold) return
    if (first >= 0 && row - last - 1 > MAX_GAP_ROWS) {
      close()
      first = -1
    }
    if (first < 0) first = row
    last = row
  })
  close()
  return best
}

function padding(detail: number[], first: number, last: number): number[] {
  return [...detail.slice(0, first), ...detail.slice(last + 1)]
}

function mean(values: number[]): number {
  return values.length === 0 ? 0 : values.reduce((sum, value) => sum + value, 0) / values.length
}

function percentile(values: number[], fraction: number): number {
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.min(sorted.length - 1, Math.floor(fraction * sorted.length))]
}
