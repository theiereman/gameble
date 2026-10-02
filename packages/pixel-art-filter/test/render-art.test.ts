import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { renderArt } from "../src/index"
import { MEMO_LIMIT } from "../src/render-art"

type Deferred = { promise: Promise<void>; resolve: () => void; reject: (error: unknown) => void }

function deferred(): Deferred {
  let resolve!: () => void
  let reject!: (error: unknown) => void
  const promise = new Promise<void>((done, fail) => {
    resolve = done
    reject = fail
  })
  return { promise, resolve, reject }
}

/** How the stubbed browser behaves for the next renders. */
let browser: {
  decode: (image: FakeImage) => Promise<void>
  scratchContext: boolean
  tainted: boolean
}

const images: FakeImage[] = []
const scratches: FakeScratch[] = []

class FakeImage {
  crossOrigin: string | null = null
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
    this.crossOriginAtSrc = this.crossOrigin
    this.#src = value
  }

  decode(): Promise<void> {
    return browser.decode(this)
  }
}

class FakeImageData {
  constructor(readonly data: Uint8ClampedArray, readonly width: number, readonly height: number) {}
}

class FakeScratch {
  width = 0
  height = 0
  contextOptions: unknown
  drawn: unknown[] = []

  getContext(type: string, options: unknown) {
    this.contextOptions = options
    if (type !== "2d" || !browser.scratchContext) return null
    return {
      drawImage: (...args: unknown[]) => this.drawn.push(args),
      getImageData: (_x: number, _y: number, width: number, height: number) => {
        if (browser.tainted) throw new DOMException("The canvas has been tainted", "SecurityError")
        const data = new Uint8ClampedArray(width * height * 4)
        for (let offset = 0; offset < data.length; offset += 4) data.set([200, 100, 50, 255], offset)
        return { width, height, data }
      },
    }
  }
}

function target(withContext = true) {
  const put = vi.fn()
  const canvas = {
    width: 300,
    height: 150,
    getContext: vi.fn((type: string) => (withContext && type === "2d" ? { putImageData: put } : null)),
  }
  return { canvas, put, element: canvas as unknown as HTMLCanvasElement }
}

let urlCount = 0
/** A URL no earlier test has rendered, so the memo starts empty for it. */
function freshUrl(): string {
  urlCount++
  return `https://shared.steamstatic.com/store_item_assets/steam/apps/${urlCount}/library_600x900.jpg`
}

beforeEach(() => {
  images.length = 0
  scratches.length = 0
  browser = { decode: () => Promise.resolve(), scratchContext: true, tainted: false }
  vi.stubGlobal("Image", FakeImage)
  vi.stubGlobal("ImageData", FakeImageData)
  vi.stubGlobal("document", {
    createElement: vi.fn((tag: string) => {
      if (tag !== "canvas") throw new Error(`unexpected element ${tag}`)
      const scratch = new FakeScratch()
      scratches.push(scratch)
      return scratch
    }),
  })
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("renderArt", () => {
  it("loads the image cross-origin and draws it filtered at grid size", async () => {
    const { canvas, put, element } = target()
    const url = freshUrl()

    await renderArt(url, element, { width: 80, height: 120, colors: 16 })

    expect(images).toHaveLength(1)
    expect(images[0].src).toBe(url)
    expect(images[0].crossOriginAtSrc).toBe("anonymous")
    expect(scratches[0].contextOptions).toEqual({ willReadFrequently: true })
    expect([scratches[0].width, scratches[0].height]).toEqual([160, 240])
    expect([canvas.width, canvas.height]).toEqual([80, 120])
    expect(put).toHaveBeenCalledOnce()
    const [imageData, x, y] = put.mock.calls[0] as [FakeImageData, number, number]
    expect(imageData).toBeInstanceOf(FakeImageData)
    expect([imageData.width, imageData.height, x, y]).toEqual([80, 120, 0, 0])
    expect(Array.from(imageData.data.slice(0, 4))).toEqual([200, 100, 50, 255])
  })

  it("covers twice the grid when the image has another ratio", async () => {
    const { element } = target()
    browser.decode = (image) => {
      image.naturalWidth = 460
      image.naturalHeight = 215
      return Promise.resolve()
    }

    await renderArt(freshUrl(), element, { width: 80, height: 120 })

    expect([scratches[0].width, scratches[0].height]).toEqual([513, 240])
  })

  it("loads the same URL and size once", async () => {
    const url = freshUrl()

    await renderArt(url, target().element, { width: 80, height: 120 })
    const second = target()
    await renderArt(url, second.element, { width: 80, height: 120 })

    expect(images).toHaveLength(1)
    expect(second.put).toHaveBeenCalledOnce()
  })

  it("loads again for another size or colour count", async () => {
    const url = freshUrl()

    await renderArt(url, target().element, { width: 80, height: 120 })
    await renderArt(url, target().element, { width: 120, height: 180 })
    await renderArt(url, target().element, { width: 80, height: 120, colors: 8 })

    expect(images).toHaveLength(3)
  })

  it(`keeps at most ${MEMO_LIMIT} results, dropping the least recently used`, async () => {
    const urls = Array.from({ length: MEMO_LIMIT }, freshUrl)
    for (const url of urls) await renderArt(url, target().element, { width: 2, height: 3 })
    await renderArt(urls[0], target().element, { width: 2, height: 3 })
    expect(images).toHaveLength(MEMO_LIMIT)

    await renderArt(freshUrl(), target().element, { width: 2, height: 3 })
    await renderArt(urls[0], target().element, { width: 2, height: 3 })
    expect(images).toHaveLength(MEMO_LIMIT + 1)

    await renderArt(urls[1], target().element, { width: 2, height: 3 })
    expect(images).toHaveLength(MEMO_LIMIT + 2)
  })

  it("rejects when the image fails to load, and tries again next time", async () => {
    const url = freshUrl()
    browser.decode = () => Promise.reject(new DOMException("The source image cannot be decoded", "EncodingError"))
    const { put, element } = target()

    await expect(renderArt(url, element, { width: 80, height: 120 })).rejects.toThrow("cannot be decoded")
    expect(put).not.toHaveBeenCalled()

    browser.decode = () => Promise.resolve()
    await renderArt(url, element, { width: 80, height: 120 })
    expect(images).toHaveLength(2)
  })

  it("rejects when the image taints the canvas", async () => {
    browser.tainted = true
    const { put, element } = target()

    await expect(renderArt(freshUrl(), element, { width: 80, height: 120 })).rejects.toMatchObject({ name: "SecurityError" })
    expect(put).not.toHaveBeenCalled()
  })

  it("rejects without a 2D context on the scratch canvas", async () => {
    browser.scratchContext = false

    await expect(renderArt(freshUrl(), target().element, { width: 80, height: 120 })).rejects.toThrow("2D context")
  })

  it("rejects without a 2D context on the target canvas", async () => {
    const { canvas, element } = target(false)

    await expect(renderArt(freshUrl(), element, { width: 80, height: 120 })).rejects.toThrow("2D context")
    expect([canvas.width, canvas.height]).toEqual([300, 150])
  })

  it("rejects with AbortError and draws nothing once aborted", async () => {
    const decoding = deferred()
    browser.decode = () => decoding.promise
    const { canvas, put, element } = target()
    const controller = new AbortController()

    const rendering = renderArt(freshUrl(), element, { width: 80, height: 120, signal: controller.signal })
    controller.abort()
    decoding.resolve()

    await expect(rendering).rejects.toMatchObject({ name: "AbortError" })
    await decoding.promise
    expect(put).not.toHaveBeenCalled()
    expect(canvas.getContext).not.toHaveBeenCalled()
    expect([canvas.width, canvas.height]).toEqual([300, 150])
  })

  it("loads nothing when the signal is already aborted", async () => {
    const controller = new AbortController()
    controller.abort()

    await expect(renderArt(freshUrl(), target().element, { width: 80, height: 120, signal: controller.signal })).rejects.toMatchObject({ name: "AbortError" })
    expect(images).toHaveLength(0)
  })

  it("rejects bad sizes and colour counts before loading", async () => {
    await expect(renderArt(freshUrl(), target().element, { width: 0, height: 120 })).rejects.toThrow(RangeError)
    await expect(renderArt(freshUrl(), target().element, { width: 80, height: 120, colors: 300 })).rejects.toThrow(RangeError)
    expect(images).toHaveLength(0)
  })

  it("touches no DOM global until called", async () => {
    vi.unstubAllGlobals()
    vi.resetModules()

    await expect(import("../src/index")).resolves.toHaveProperty("renderArt")
  })
})
