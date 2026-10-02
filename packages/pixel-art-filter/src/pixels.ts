/** An RGBA image: `data` holds `width × height × 4` bytes, row by row. */
export type Pixels = {
  width: number
  height: number
  data: Uint8ClampedArray<ArrayBuffer>
}

/** A palette colour, `[red, green, blue]`. */
export type Color = [number, number, number]

export function assertSize(name: string, value: number): void {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(`${name} must be a positive integer, got ${value}`)
  }
}

export function assertColors(colors: number): void {
  if (!Number.isInteger(colors) || colors < 1 || colors > 256) {
    throw new RangeError(`colors must be an integer from 1 to 256, got ${colors}`)
  }
}

export function assertPixels(pixels: Pixels): void {
  assertSize("width", pixels.width)
  assertSize("height", pixels.height)
  const expected = pixels.width * pixels.height * 4
  if (pixels.data.length !== expected) {
    throw new RangeError(`data must hold ${expected} bytes, got ${pixels.data.length}`)
  }
}
