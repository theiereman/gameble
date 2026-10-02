import type { Pixels } from "../src/index"

export type Rgba = [number, number, number, number]

/** An image whose pixel at (x, y) is `colorAt(x, y)`. */
export function image(width: number, height: number, colorAt: (x: number, y: number) => Rgba): Pixels {
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) data.set(colorAt(x, y), (y * width + x) * 4)
  }
  return { width, height, data }
}

/** An image of the given pixels, row by row. */
export function fromPixels(width: number, height: number, pixels: Rgba[]): Pixels {
  return image(width, height, (x, y) => pixels[y * width + x])
}

/** The pixels of an image, row by row. */
export function toPixels({ data }: Pixels): Rgba[] {
  const pixels: Rgba[] = []
  for (let offset = 0; offset < data.length; offset += 4) {
    pixels.push([data[offset], data[offset + 1], data[offset + 2], data[offset + 3]])
  }
  return pixels
}

export function distinctColors(pixels: Pixels): Set<string> {
  return new Set(toPixels(pixels).filter((pixel) => pixel[3] !== 0).map((pixel) => pixel.slice(0, 3).join(",")))
}
