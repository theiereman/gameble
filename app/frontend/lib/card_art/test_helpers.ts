import type { Pixels } from "pixelcrush"

export type Rgba = [number, number, number, number]

export function image(width: number, height: number, colorAt: (x: number, y: number) => Rgba): Pixels {
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) data.set(colorAt(x, y), (y * width + x) * 4)
  }
  return { width, height, data }
}

export function fromPixels(width: number, height: number, pixels: Rgba[]): Pixels {
  return image(width, height, (x, y) => pixels[y * width + x])
}
