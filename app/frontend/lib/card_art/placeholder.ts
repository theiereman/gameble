import type { Pixels } from "pixelcrush"

/**
 * The smallest image taken for a cover. Steam answers a missing cover with a
 * grey 300 × 450 placeholder, so an image under this size, or with nearly
 * uniform grey tones, counts as missing.
 */
export const MIN_SOURCE = { width: 300, height: 450 } as const

/** How far apart R, G and B may be for a pixel to count as grey. */
export const GREY_CHANNEL_TOLERANCE = 2

/** The Steam placeholder's JPEG noise spans 18 tone values. */
export const GREY_TONE_RANGE = 24

/** Whether a decoded image is too small to be a cover. */
export function isTooSmall(width: number, height: number): boolean {
  return width < MIN_SOURCE.width || height < MIN_SOURCE.height
}

/**
 * Whether every opaque pixel is grey and the image has almost no tonal range.
 * An image with no opaque pixel counts too.
 */
export function isFlatGrey(
  pixels: Pixels,
  channelTolerance = GREY_CHANNEL_TOLERANCE,
  toneRange = GREY_TONE_RANGE,
): boolean {
  const { data } = pixels
  let darkest = 255
  let lightest = 0
  let hasOpaquePixel = false
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] === 0) continue
    hasOpaquePixel = true
    const red = data[offset]
    const green = data[offset + 1]
    const blue = data[offset + 2]
    const minimum = Math.min(red, green, blue)
    const maximum = Math.max(red, green, blue)
    if (maximum - minimum > channelTolerance) return false
    darkest = Math.min(darkest, minimum)
    lightest = Math.max(lightest, maximum)
  }
  return !hasOpaquePixel || lightest - darkest <= toneRange
}

/** Whether `source`, a decoded image, counts as a missing cover. */
export function isPlaceholder(source: Pixels): boolean {
  return isTooSmall(source.width, source.height) || isFlatGrey(source)
}
