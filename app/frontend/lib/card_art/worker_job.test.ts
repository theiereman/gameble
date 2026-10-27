import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { Pixels } from "pixelcrush"
import {
  createJobRunner,
  FETCH_TIMEOUT_MS,
  IMAGE_REQUEST,
  PaletteCache,
  runJob,
  type ArtJob,
  type JobEnvironment,
  type JobResult,
} from "./worker_job"
import { FakeBitmap, FakeImageData, FakeSurface, opaqueColors } from "./test_fakes"
import { image } from "./test_helpers"

/** A colourful 600 × 900 cover, in the size of a Steam library capsule. */
const COVER = image(600, 900, (x, y) => [(x * 255) / 599, (y * 255) / 899, ((x + y) * 7) % 256, 255])

const SMALL = { width: 68, height: 108 }
const LARGE = { width: 104, height: 164 }

function job(url: string, size = SMALL, palette = LARGE, colors = 32): ArtJob {
  return {
    url,
    width: size.width,
    height: size.height,
    paletteWidth: palette.width,
    paletteHeight: palette.height,
    colors,
  }
}

let images: Map<string, Pixels>
let surfaces: FakeSurface[]
let bitmaps: FakeBitmap[]
let environment: JobEnvironment & { fetch: ReturnType<typeof vi.fn> }

beforeEach(() => {
  images = new Map()
  surfaces = []
  bitmaps = []
  vi.stubGlobal("ImageData", FakeImageData)
  environment = {
    fetch: vi.fn(async (url: string) => {
      if (url.startsWith("https://refused.test/")) throw new TypeError("Failed to fetch")
      const pixels = images.get(url)
      return { ok: pixels !== undefined, blob: async () => new Blob([url]) }
    }),
    createImageBitmap: async (blob: Blob) => {
      const pixels = images.get(await blob.text())
      if (!pixels) throw new DOMException("The source image could not be decoded", "InvalidStateError")
      const bitmap = new FakeBitmap(pixels)
      bitmaps.push(bitmap)
      return bitmap as unknown as ImageBitmap
    },
    createSurface: (width, height) => {
      const surface = new FakeSurface(width, height)
      surfaces.push(surface)
      return surface as unknown as ReturnType<JobEnvironment["createSurface"]>
    },
    palettes: new PaletteCache(),
  }
})

afterEach(() => {
  vi.unstubAllGlobals()
})

function drawnPixels(result: JobResult): Pixels {
  expect(result.status).toBe("drawn")
  return (result as unknown as { bitmap: FakeBitmap }).bitmap.pixels
}

describe("runJob", () => {
  it("fetches with CORS, no added header, no referrer and no cookie", async () => {
    images.set("https://cdn.test/a.jpg", COVER)

    await runJob(job("https://cdn.test/a.jpg"), environment)

    expect(environment.fetch).toHaveBeenCalledWith("https://cdn.test/a.jpg", {
      mode: "cors",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal: expect.any(AbortSignal),
    })
    expect(environment.fetch.mock.calls[0][1]).not.toHaveProperty("headers")
    expect(IMAGE_REQUEST).toEqual({ mode: "cors", credentials: "omit", referrerPolicy: "no-referrer" })
  })

  it("draws the art at its size in at most 32 colours, and closes the decoded image", async () => {
    images.set("https://cdn.test/a.jpg", COVER)

    const pixels = drawnPixels(await runJob(job("https://cdn.test/a.jpg"), environment))

    expect([pixels.width, pixels.height]).toEqual([68, 108])
    const colors = opaqueColors(pixels)
    expect(colors.size).toBeLessThanOrEqual(32)
    expect(colors.size).toBeGreaterThan(16)
    expect(bitmaps.every((bitmap) => bitmap.closed)).toBe(true)
  })

  it("halves on scratch canvases to within twice the art size, cropping anchored at 42 %", async () => {
    // 300 × 600 is taller than the art: the crop keeps 300 × 476.5, 42 % of the way down.
    images.set(
      "https://cdn.test/tall.jpg",
      image(300, 600, () => [200, 40, 40, 255]),
    )

    await runJob(job("https://cdn.test/tall.jpg", SMALL, SMALL), environment)

    const regionHeight = 300 / (68 / 108)
    const [first, ...rest] = surfaces.filter((surface) => surface.context.draws.length > 0)
    const [sx, sy, sw, sh] = first.context.draws[0].args
    expect([sx, sw]).toEqual([0, 300])
    expect(sy).toBeCloseTo((600 - regionHeight) * 0.42)
    expect(sh).toBeCloseTo(regionHeight)
    const last = rest.at(-1)!
    expect(last.width).toBeLessThanOrEqual(2 * 68)
    expect(last.width).toBeGreaterThanOrEqual(68)
    expect(first.context.imageSmoothingQuality).toBe("high")
  })

  it("computes a game's palette once, at the palette size, and draws every size with it", async () => {
    images.set("https://cdn.test/a.jpg", COVER)
    const set = vi.spyOn(environment.palettes, "set")

    const small = drawnPixels(await runJob(job("https://cdn.test/a.jpg", SMALL), environment))
    const large = drawnPixels(await runJob(job("https://cdn.test/a.jpg", LARGE), environment))

    expect(set).toHaveBeenCalledOnce()
    const palette = new Set(environment.palettes.get("https://cdn.test/a.jpg", 32)!.map((color) => color.join(",")))
    expect([pixelsWithin(small, palette), pixelsWithin(large, palette)]).toEqual([true, true])
    // The palette came from the large size: drawing it alone gives the same colours.
    const fresh = { ...environment, palettes: new PaletteCache() }
    drawnPixels(await runJob(job("https://cdn.test/a.jpg", LARGE), fresh))
    expect(fresh.palettes.get("https://cdn.test/a.jpg", 32)).toEqual([
      ...environment.palettes.get("https://cdn.test/a.jpg", 32)!,
    ])
  })

  it("shares the palette whichever size comes first", async () => {
    images.set("https://cdn.test/a.jpg", COVER)
    const set = vi.spyOn(environment.palettes, "set")

    await runJob(job("https://cdn.test/a.jpg", LARGE), environment)
    const small = drawnPixels(await runJob(job("https://cdn.test/a.jpg", SMALL), environment))

    expect(set).toHaveBeenCalledOnce()
    const palette = new Set(environment.palettes.get("https://cdn.test/a.jpg", 32)!.map((color) => color.join(",")))
    expect(pixelsWithin(small, palette)).toBe(true)
  })

  it.each([
    ["narrower than 300", 299, 450],
    ["shorter than 450", 300, 449],
  ])("counts an image %s as missing", async (_name, width, height) => {
    images.set(
      "https://cdn.test/small.jpg",
      image(width, height, (x) => [x % 256, 30, 200, 255]),
    )

    expect(await runJob(job("https://cdn.test/small.jpg"), environment)).toEqual({ status: "missing" })
    expect(bitmaps[0].closed).toBe(true)
  })

  it("counts Steam's grey placeholder as missing at every size, colour within 2 of grey", async () => {
    images.set(
      "https://cdn.test/grey.jpg",
      image(300, 450, (x, y) => [128 + ((x + y) % 3), 129, 128, 255]),
    )

    expect(await runJob(job("https://cdn.test/grey.jpg", SMALL), environment)).toEqual({ status: "missing" })
    expect(await runJob(job("https://cdn.test/grey.jpg", LARGE), environment)).toEqual({ status: "missing" })
    expect(environment.palettes.size).toBe(0)
  })

  it("draws a grayscale cover with a full tonal range", async () => {
    images.set(
      "https://cdn.test/grayscale.jpg",
      image(300, 450, (x, y) => {
        const tone = (x + y) % 256
        return [tone, tone, tone, 255]
      }),
    )

    expect((await runJob(job("https://cdn.test/grayscale.jpg"), environment)).status).toBe("drawn")
    expect(environment.palettes.size).toBe(1)
  })

  it("checks for grey at the palette size, not at the art size", async () => {
    // 300 × 900, grey but for the top 42 rows: the art's crop (from row 178)
    // leaves them out; a palette size of the image's own ratio keeps them.
    images.set(
      "https://cdn.test/top.jpg",
      image(300, 900, (_x, y) => (y < 42 ? [220, 30, 30, 255] : [128, 128, 128, 255])),
    )
    const art = { width: 68, height: 108 }
    const whole = { width: 30, height: 90 }

    expect((await runJob(job("https://cdn.test/top.jpg", art, whole), environment)).status).toBe("drawn")
    environment.palettes = new PaletteCache()
    expect(await runJob(job("https://cdn.test/top.jpg", art, art), environment)).toEqual({ status: "missing" })
  })

  it("trusts a cached palette: the image already passed the grey check", async () => {
    images.set(
      "https://cdn.test/grey.jpg",
      image(300, 450, () => [128, 128, 128, 255]),
    )
    environment.palettes.set("https://cdn.test/grey.jpg", 32, [[200, 40, 40]])

    expect((await runJob(job("https://cdn.test/grey.jpg"), environment)).status).toBe("drawn")
  })

  it("counts a request that outlasts the timeout as missing, not as a CORS failure", async () => {
    environment.fetchTimeout = 5
    environment.fetch.mockImplementationOnce(
      (_url: string, init: RequestInit) =>
        new Promise((_resolve, reject) => init.signal!.addEventListener("abort", () => reject(init.signal!.reason))),
    )

    expect(await runJob(job("https://cdn.test/slow.jpg"), environment)).toEqual({ status: "missing" })
    expect(FETCH_TIMEOUT_MS).toBe(20_000)
  })

  it("counts a body that outlasts the timeout as missing", async () => {
    environment.fetchTimeout = 5
    environment.fetch.mockImplementationOnce(async (_url: string, init: RequestInit) => ({
      ok: true,
      blob: () =>
        new Promise<Blob>((_resolve, reject) =>
          init.signal!.addEventListener("abort", () => reject(init.signal!.reason)),
        ),
    }))

    expect(await runJob(job("https://cdn.test/slow.jpg"), environment)).toEqual({ status: "missing" })
  })

  it("takes an exactly 300 × 450 colour image", async () => {
    images.set(
      "https://cdn.test/min.jpg",
      image(300, 450, (x, y) => [x % 256, y % 256, 90, 255]),
    )

    expect((await runJob(job("https://cdn.test/min.jpg"), environment)).status).toBe("drawn")
  })

  it("answers missing on an HTTP error or an undecodable image", async () => {
    expect(await runJob(job("https://cdn.test/404.jpg"), environment)).toEqual({ status: "missing" })

    environment.createImageBitmap = () => Promise.reject(new DOMException("bad", "InvalidStateError"))
    images.set("https://cdn.test/broken.jpg", COVER)
    expect(await runJob(job("https://cdn.test/broken.jpg"), environment)).toEqual({ status: "missing" })
  })

  it("answers cors when the request itself fails", async () => {
    expect(await runJob(job("https://refused.test/a.jpg"), environment)).toEqual({ status: "cors" })
  })

  it("answers unsupported without a 2D context on OffscreenCanvas", async () => {
    images.set("https://cdn.test/a.jpg", COVER)
    environment.createSurface = () => null

    expect(await runJob(job("https://cdn.test/a.jpg"), environment)).toEqual({ status: "unsupported" })
    expect(bitmaps[0].closed).toBe(true)
  })
})

describe("createJobRunner", () => {
  it("runs two sizes of one game one after the other, computing its palette once", async () => {
    images.set("https://cdn.test/a.jpg", COVER)
    const set = vi.spyOn(environment.palettes, "set")
    const run = createJobRunner(environment)

    const small = run(job("https://cdn.test/a.jpg", SMALL))
    const large = run(job("https://cdn.test/a.jpg", LARGE))
    expect(environment.fetch).toHaveBeenCalledTimes(1)

    const results = await Promise.all([small, large])
    expect(results.map((result) => result.status)).toEqual(["drawn", "drawn"])
    expect(environment.fetch).toHaveBeenCalledTimes(2)
    expect(set).toHaveBeenCalledOnce()
    const palette = new Set(environment.palettes.get("https://cdn.test/a.jpg", 32)!.map((color) => color.join(",")))
    expect(results.every((result) => pixelsWithin(drawnPixels(result), palette))).toBe(true)
  })

  it("runs other games side by side, and starts afresh once a game's jobs have settled", async () => {
    images.set("https://cdn.test/a.jpg", COVER)
    images.set("https://cdn.test/b.jpg", COVER)
    const run = createJobRunner(environment)

    const both = Promise.all([run(job("https://cdn.test/a.jpg")), run(job("https://cdn.test/b.jpg"))])
    expect(environment.fetch).toHaveBeenCalledTimes(2)
    await both

    void run(job("https://cdn.test/a.jpg", LARGE))
    expect(environment.fetch).toHaveBeenCalledTimes(3)
  })
})

describe("PaletteCache", () => {
  it("keys by URL and colour count, dropping the least recently used past its limit", () => {
    const cache = new PaletteCache(2)
    cache.set("a", 32, [[1, 1, 1]])
    cache.set("b", 32, [[2, 2, 2]])
    cache.get("a", 32)
    cache.set("c", 32, [[3, 3, 3]])

    expect(cache.get("a", 32)).toEqual([[1, 1, 1]])
    expect(cache.get("b", 32)).toBeUndefined()
    expect(cache.get("c", 16)).toBeUndefined()
    expect(cache.size).toBe(2)
  })

  it("keeps about 256 games by default", () => {
    expect(new PaletteCache().limit).toBe(256)
  })
})

function pixelsWithin(pixels: Pixels, palette: Set<string>): boolean {
  return [...opaqueColors(pixels)].every((color) => palette.has(color))
}
