import type { Pixels } from "pixelcrush"

/**
 * The smallest image taken for a cover. Steam answers a missing cover with a
 * grey 300 × 450 placeholder, so an image under this size, or with a single
 * channel, counts as missing (AD-17).
 */
export const MIN_SOURCE = { width: 300, height: 450 } as const

/** How far apart R, G and B may be for a pixel to count as grey. */
export const GREY_TOLERANCE = 2

/** Whether a decoded image is too small to be a cover. */
export function isTooSmall(width: number, height: number): boolean {
  return width < MIN_SOURCE.width || height < MIN_SOURCE.height
}

/**
 * Whether every pixel that is not fully transparent is grey: its R, G and B
 * within `tolerance` of each other. An image with no such pixel counts too.
 */
export function isSingleChannel(pixels: Pixels, tolerance = GREY_TOLERANCE): boolean {
  const { data } = pixels
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] === 0) continue
    const red = data[offset]
    const green = data[offset + 1]
    const blue = data[offset + 2]
    if (Math.max(red, green, blue) - Math.min(red, green, blue) > tolerance) return false
  }
  return true
}

/** Whether `source`, a decoded image, counts as a missing cover. */
export function isPlaceholder(source: Pixels): boolean {
  return isTooSmall(source.width, source.height) || isSingleChannel(source)
}
