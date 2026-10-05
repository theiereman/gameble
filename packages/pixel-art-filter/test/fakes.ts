import type { Pixels } from "../src/index"

/** Something a fake context can draw from. */
type Drawable = { width: number; height: number; pixels: Pixels }

/** An `ImageBitmap` holding pixels. */
export class FakeBitmap implements Drawable {
  closed = false
  constructor(readonly pixels: Pixels) {}

  get width(): number {
    return this.pixels.width
  }

  get height(): number {
    return this.pixels.height
  }

  close(): void {
    this.closed = true
  }
}

export class FakeImageData {
  constructor(readonly data: Uint8ClampedArray<ArrayBuffer>, readonly width: number, readonly height: number) {}
}

export type DrawCall = { source: unknown; args: number[] }

/** A scratch canvas whose `drawImage` samples the nearest source pixel. */
export class FakeSurface implements Drawable {
  readonly canvas = this
  readonly context: FakeContext
  pixels: Pixels

  constructor(readonly width: number, readonly height: number) {
    this.pixels = { width, height, data: new Uint8ClampedArray(width * height * 4) }
    this.context = new FakeContext(this)
  }

  transferToImageBitmap(): FakeBitmap {
    return new FakeBitmap({ width: this.width, height: this.height, data: new Uint8ClampedArray(this.pixels.data) })
  }
}

export class FakeContext {
  imageSmoothingEnabled = false
  imageSmoothingQuality = "low"
  readonly draws: DrawCall[] = []

  constructor(readonly surface: FakeSurface) {}

  drawImage(source: Drawable, sx: number, sy: number, sw: number, sh: number, dx: number, dy: number, dw: number, dh: number): void {
    this.draws.push({ source, args: [sx, sy, sw, sh, dx, dy, dw, dh] })
    const target = this.surface.pixels
    for (let y = 0; y < dh; y++) {
      for (let x = 0; x < dw; x++) {
        const fromX = Math.min(source.width - 1, Math.floor(sx + ((x + 0.5) * sw) / dw))
        const fromY = Math.min(source.height - 1, Math.floor(sy + ((y + 0.5) * sh) / dh))
        const from = (fromY * source.width + fromX) * 4
        target.data.set(source.pixels.data.subarray(from, from + 4), ((dy + y) * target.width + dx + x) * 4)
      }
    }
  }

  getImageData(x: number, y: number, width: number, height: number): FakeImageData {
    if (x !== 0 || y !== 0 || width !== this.surface.width || height !== this.surface.height) throw new Error("partial read")
    return new FakeImageData(new Uint8ClampedArray(this.surface.pixels.data), width, height)
  }

  putImageData(imageData: FakeImageData, x: number, y: number): void {
    if (x !== 0 || y !== 0) throw new Error("offset write")
    this.surface.pixels = { width: imageData.width, height: imageData.height, data: new Uint8ClampedArray(imageData.data) }
  }
}

/** The colours of an image's opaque pixels. */
export function opaqueColors({ data }: Pixels): Set<string> {
  const colors = new Set<string>()
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] !== 0) colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]}`)
  }
  return colors
}
