import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { ArtMissingError } from "../src/index"
import { renderPlain } from "../src/plain"

/** How the stubbed browser decodes the next images. */
let decode: (image: FakeImage) => Promise<void>
const images: FakeImage[] = []
const scratches: FakeCanvas[] = []

class FakeImage {
  crossOrigin: string | null = null
  referrerPolicy = ""
  referrerPolicyAtSrc: string | null = null
  crossOriginAtSrc: string | null = null
  naturalWidth = 600
  naturalHeight = 900
  #src = ""

  constructor() {
    images.push(this)
  }

  get src(): string {
    return this.#src
  }

  set src(value: string) {
    this.referrerPolicyAtSrc = this.referrerPolicy
    this.crossOriginAtSrc = this.crossOrigin
    this.#src = value
  }

  decode(): Promise<void> {
    return decode(this)
  }
}

class FakeCanvas {
  width = 300
  height = 150
  readonly draws: unknown[][] = []
  readonly context = {
    imageSmoothingEnabled: false,
    imageSmoothingQuality: "low",
    drawImage: (...args: unknown[]) => this.draws.push(args),
  }

  getContext(type: string) {
    return type === "2d" ? this.context : null
  }
}

beforeEach(() => {
  images.length = 0
  scratches.length = 0
  decode = () => Promise.resolve()
  vi.stubGlobal("Image", FakeImage)
  vi.stubGlobal("document", {
    createElement: (tag: string) => {
      if (tag !== "canvas") throw new Error(`unexpected element ${tag}`)
      const canvas = new FakeCanvas()
      scratches.push(canvas)
      return canvas
    },
  })
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("renderPlain", () => {
  it("loads a plain image without CORS and without referrer", async () => {
    await renderPlain("https://cdn.test/a.jpg", new FakeCanvas() as unknown as HTMLCanvasElement, { width: 68, height: 108 })

    expect(images).toHaveLength(1)
    expect(images[0].src).toBe("https://cdn.test/a.jpg")
    expect(images[0].crossOriginAtSrc).toBeNull()
    expect(images[0].referrerPolicyAtSrc).toBe("no-referrer")
  })

  it("crops anchored at 42 %, halves on scratch canvases and draws at the art size", async () => {
    decode = (image) => {
      image.naturalWidth = 300
      image.naturalHeight = 600
      return Promise.resolve()
    }
    const target = new FakeCanvas()

    await renderPlain("https://cdn.test/tall.jpg", target as unknown as HTMLCanvasElement, { width: 68, height: 108 })

    const regionHeight = 300 / (68 / 108)
    const [source, sx, sy, sw, sh] = scratches[0].draws[0] as [unknown, number, number, number, number]
    expect(source).toBe(images[0])
    expect([sx, sw]).toEqual([0, 300])
    expect(sy).toBeCloseTo((600 - regionHeight) * 0.42)
    expect(sh).toBeCloseTo(regionHeight)
    const last = scratches.at(-1)!
    expect(last.width).toBeLessThanOrEqual(136)
    expect([target.width, target.height]).toEqual([68, 108])
    expect(target.draws).toEqual([[last, 0, 0, last.width, last.height, 0, 0, 68, 108]])
    expect(target.context.imageSmoothingQuality).toBe("high")
  })

  it("rejects with ArtMissingError when the image does not load, drawing nothing", async () => {
    decode = () => Promise.reject(new DOMException("The source image cannot be decoded", "EncodingError"))
    const target = new FakeCanvas()

    await expect(renderPlain("https://cdn.test/404.jpg", target as unknown as HTMLCanvasElement, { width: 68, height: 108 })).rejects.toBeInstanceOf(ArtMissingError)
    expect(target.draws).toHaveLength(0)
  })

  it("rejects with ArtMissingError when the image is under 300 × 450", async () => {
    decode = (image) => {
      image.naturalWidth = 300
      image.naturalHeight = 449
      return Promise.resolve()
    }

    await expect(renderPlain("https://cdn.test/small.jpg", new FakeCanvas() as unknown as HTMLCanvasElement, { width: 68, height: 108 })).rejects.toBeInstanceOf(ArtMissingError)
  })

  it("rejects with AbortError and leaves the canvas untouched once aborted", async () => {
    let finish!: () => void
    decode = () => new Promise((resolve) => (finish = resolve))
    const target = new FakeCanvas()
    const controller = new AbortController()

    const rendering = renderPlain("https://cdn.test/a.jpg", target as unknown as HTMLCanvasElement, { width: 68, height: 108, signal: controller.signal })
    controller.abort()
    finish()

    await expect(rendering).rejects.toMatchObject({ name: "AbortError" })
    expect([target.width, target.height]).toEqual([300, 150])
    expect(target.draws).toHaveLength(0)
  })
})
