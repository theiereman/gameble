import { describe, expect, it, vi } from "vitest"
import { ArtMissingError } from "./errors"
import { createArtRenderer, type ArtRendererOptions } from "./renderer"
import type { JobRequest, JobResult } from "./worker_job"

class FakeWorker {
  readonly posted: JobRequest[] = []
  terminated = false
  #listeners: Record<string, ((event: unknown) => void)[]> = { message: [], error: [] }

  postMessage(message: JobRequest): void {
    this.posted.push(message)
  }

  addEventListener(type: "message" | "error", listener: (event: unknown) => void): void {
    this.#listeners[type].push(listener)
  }

  terminate(): void {
    this.terminated = true
  }

  /** Answers the job posted for `url` (the first one still unanswered). */
  answer(url: string, result: JobResult): void {
    const index = this.posted.findIndex((message) => message.url === url)
    if (index === -1) throw new Error(`no job for ${url}`)
    const [{ id }] = this.posted.splice(index, 1)
    for (const listener of this.#listeners.message) listener({ data: { id, ...result } })
  }

  fail(): void {
    for (const listener of this.#listeners.error) listener(new Event("error"))
  }
}

class Bitmap {
  closed = false
  close(): void {
    this.closed = true
  }
}

function drawn(): { status: "drawn"; bitmap: ImageBitmap } & { fake: Bitmap } {
  const fake = new Bitmap()
  return { status: "drawn", bitmap: fake as unknown as ImageBitmap, fake }
}

function target() {
  const drawImage = vi.fn()
  const canvas = { width: 300, height: 150, getContext: vi.fn((type: string) => (type === "2d" ? { drawImage } : null)) }
  return { canvas, drawImage, element: canvas as unknown as HTMLCanvasElement }
}

function setup(options: ArtRendererOptions = {}) {
  const workers: FakeWorker[] = []
  const plain = vi.fn(async (_url: string, _canvas: HTMLCanvasElement, _options: { width: number; height: number; signal?: AbortSignal }) => {})
  const renderer = createArtRenderer({
    createWorker: () => {
      const worker = new FakeWorker()
      workers.push(worker)
      return worker
    },
    supported: () => true,
    plain,
    ...options,
  })
  return { renderer, workers, plain, worker: () => workers[0] }
}

const SIZE = { width: 68, height: 108 }
const flush = () => new Promise((resolve) => setTimeout(resolve, 0))
const url = (n: number) => `https://cdn.test/${n}.jpg`

describe("createArtRenderer", () => {
  it("starts the worker on the first render only", async () => {
    const { renderer, workers } = setup()
    expect(workers).toHaveLength(0)

    void renderer.render(url(1), target().element, SIZE)
    void renderer.render(url(2), target().element, SIZE)

    expect(workers).toHaveLength(1)
  })

  it("posts the job with its defaults and draws the bitmap with a 2D context", async () => {
    const { renderer, worker } = setup()
    const { canvas, drawImage, element } = target()

    const rendering = renderer.render(url(1), element, SIZE)
    expect(worker().posted).toEqual([{ id: 1, url: url(1), width: 68, height: 108, paletteWidth: 68, paletteHeight: 108, colors: 32 }])
    const result = drawn()
    worker().answer(url(1), result)

    await expect(rendering).resolves.toBe("drawn")
    expect(canvas.getContext).toHaveBeenCalledWith("2d")
    expect(drawImage).toHaveBeenCalledWith(result.bitmap, 0, 0)
    expect([canvas.width, canvas.height]).toEqual([68, 108])
    expect(result.fake.closed).toBe(false)
  })

  it("passes the palette size and colour count", () => {
    const { renderer, worker } = setup()

    void renderer.render(url(1), target().element, { ...SIZE, paletteWidth: 104, paletteHeight: 164, colors: 16 })

    expect(worker().posted[0]).toMatchObject({ paletteWidth: 104, paletteHeight: 164, colors: 16 })
  })

  it("serves the same URL and size from the cache without a job, and shares a job under way", async () => {
    const { renderer, worker } = setup()

    const first = renderer.render(url(1), target().element, SIZE)
    const second = renderer.render(url(1), target().element, SIZE)
    expect(worker().posted).toHaveLength(1)
    worker().answer(url(1), drawn())
    await expect(Promise.all([first, second])).resolves.toEqual(["drawn", "drawn"])

    const third = target()
    await expect(renderer.render(url(1), third.element, SIZE)).resolves.toBe("drawn")
    expect(worker().posted).toHaveLength(0)
    expect(third.drawImage).toHaveBeenCalledOnce()

    void renderer.render(url(1), target().element, { width: 104, height: 164 })
    expect(worker().posted).toHaveLength(1)
  })

  it("runs at most `concurrency` jobs at once, 3 by default, the rest in order", async () => {
    const { renderer, worker } = setup()

    const renders = Array.from({ length: 30 }, (_, index) => renderer.render(url(index), target().element, SIZE))
    expect(worker().posted.map((message) => message.url)).toEqual([url(0), url(1), url(2)])

    worker().answer(url(1), drawn())
    expect(worker().posted.map((message) => message.url)).toEqual([url(0), url(2), url(3)])

    for (let index = 0; index < 30; index++) {
      if (index === 1) continue
      worker().answer(url(index), drawn())
      expect(worker().posted.length).toBeLessThanOrEqual(3)
    }
    await expect(Promise.all(renders)).resolves.toEqual(Array(30).fill("drawn"))
  })

  it("takes a concurrency from 2 to 4", () => {
    const { renderer, worker } = setup({ concurrency: 4 })
    for (let index = 0; index < 10; index++) void renderer.render(url(index), target().element, SIZE)
    expect(worker().posted).toHaveLength(4)

    expect(() => setup({ concurrency: 1 })).toThrow(RangeError)
    expect(() => setup({ concurrency: 5 })).toThrow(RangeError)
  })

  it("drops a queued job once its only render aborts", async () => {
    const { renderer, worker } = setup()
    for (let index = 0; index < 3; index++) void renderer.render(url(index), target().element, SIZE)
    const controller = new AbortController()
    const { drawImage, element } = target()

    const rendering = renderer.render(url(9), element, { ...SIZE, signal: controller.signal })
    controller.abort()

    await expect(rendering).rejects.toMatchObject({ name: "AbortError" })
    worker().answer(url(0), drawn())
    expect(worker().posted.map((message) => message.url)).not.toContain(url(9))
    expect(drawImage).not.toHaveBeenCalled()
  })

  it("keeps a queued job another render still waits for", async () => {
    const { renderer, worker } = setup()
    for (let index = 0; index < 3; index++) void renderer.render(url(index), target().element, SIZE)
    const controller = new AbortController()

    const aborted = renderer.render(url(9), target().element, { ...SIZE, signal: controller.signal })
    const kept = renderer.render(url(9), target().element, SIZE)
    controller.abort()
    await expect(aborted).rejects.toMatchObject({ name: "AbortError" })

    worker().answer(url(0), drawn())
    worker().answer(url(9), drawn())
    await expect(kept).resolves.toBe("drawn")
  })

  it("lets a job in the worker finish into the cache after its render aborts, drawing nothing", async () => {
    const { renderer, worker } = setup()
    const controller = new AbortController()
    const { canvas, drawImage, element } = target()

    const rendering = renderer.render(url(1), element, { ...SIZE, signal: controller.signal })
    controller.abort()
    await expect(rendering).rejects.toMatchObject({ name: "AbortError" })
    worker().answer(url(1), drawn())
    await flush()

    expect(drawImage).not.toHaveBeenCalled()
    expect(canvas.getContext).not.toHaveBeenCalled()
    expect([canvas.width, canvas.height]).toEqual([300, 150])
    await expect(renderer.render(url(1), target().element, SIZE)).resolves.toBe("drawn")
    expect(worker().posted).toHaveLength(0)
  })

  it("rejects an already aborted render without starting anything", async () => {
    const { renderer, workers } = setup()
    const controller = new AbortController()
    controller.abort()

    await expect(renderer.render(url(1), target().element, { ...SIZE, signal: controller.signal })).rejects.toMatchObject({ name: "AbortError" })
    expect(workers).toHaveLength(0)
  })

  it(`keeps at most cacheLimit bitmaps (120 by default), closing the least recently used`, async () => {
    const { renderer, worker } = setup({ cacheLimit: 2 })
    const bitmaps = [drawn(), drawn(), drawn()]

    for (const index of [0, 1]) {
      const rendering = renderer.render(url(index), target().element, SIZE)
      worker().answer(url(index), bitmaps[index])
      await rendering
    }
    await renderer.render(url(0), target().element, SIZE)
    const rendering = renderer.render(url(2), target().element, SIZE)
    worker().answer(url(2), bitmaps[2])
    await rendering

    expect(bitmaps.map((bitmap) => bitmap.fake.closed)).toEqual([false, true, false])
    void renderer.render(url(1), target().element, SIZE)
    expect(worker().posted.map((message) => message.url)).toEqual([url(1)])
  })

  it("rejects a missing art with ArtMissingError and tries again on the next render", async () => {
    const { renderer, worker, plain } = setup()
    const { drawImage, element } = target()

    const rendering = renderer.render(url(1), element, SIZE)
    worker().answer(url(1), { status: "missing" })
    await expect(rendering).rejects.toBeInstanceOf(ArtMissingError)
    expect(drawImage).not.toHaveBeenCalled()
    expect(plain).not.toHaveBeenCalled()

    void renderer.render(url(1), element, SIZE)
    expect(worker().posted).toHaveLength(1)
  })

  it("draws a CORS failure once on the main thread without palette, and caches nothing", async () => {
    const { renderer, worker, plain } = setup()
    const controller = new AbortController()
    const { element } = target()

    const rendering = renderer.render(url(1), element, { ...SIZE, paletteWidth: 104, paletteHeight: 164, signal: controller.signal })
    worker().answer(url(1), { status: "cors" })

    await expect(rendering).resolves.toBe("plain")
    expect(plain).toHaveBeenCalledExactlyOnceWith(url(1), element, { width: 68, height: 108, signal: controller.signal })

    void renderer.render(url(1), element, SIZE)
    expect(worker().posted).toHaveLength(1)
  })

  it("rejects when the plain retry fails", async () => {
    const { renderer, worker, plain } = setup()
    plain.mockRejectedValueOnce(new ArtMissingError(url(1)))

    const rendering = renderer.render(url(1), target().element, SIZE)
    worker().answer(url(1), { status: "cors" })

    await expect(rendering).rejects.toBeInstanceOf(ArtMissingError)
  })

  it("takes the main-thread path for good when the worker has no 2D OffscreenCanvas", async () => {
    const { renderer, worker, workers, plain } = setup()

    const first = renderer.render(url(1), target().element, SIZE)
    const second = renderer.render(url(2), target().element, SIZE)
    worker().answer(url(1), { status: "unsupported" })

    await expect(Promise.all([first, second])).resolves.toEqual(["plain", "plain"])
    expect(worker().terminated).toBe(true)
    await expect(renderer.render(url(3), target().element, SIZE)).resolves.toBe("plain")
    expect(workers).toHaveLength(1)
    expect(plain).toHaveBeenCalledTimes(3)
  })

  it("takes the main-thread path for good when the worker fails to load", async () => {
    const { renderer, worker, workers } = setup()
    const renders = Array.from({ length: 5 }, (_, index) => renderer.render(url(index), target().element, SIZE))

    worker().fail()

    await expect(Promise.all(renders)).resolves.toEqual(Array(5).fill("plain"))
    await expect(renderer.render(url(9), target().element, SIZE)).resolves.toBe("plain")
    expect(workers).toHaveLength(1)
  })

  it("takes the main-thread path when the worker cannot be created", async () => {
    const plain = vi.fn(async () => {})
    const renderer = createArtRenderer({ supported: () => true, plain, createWorker: () => { throw new Error("blocked") } })

    await expect(renderer.render(url(1), target().element, SIZE)).resolves.toBe("plain")
  })

  it("takes the main-thread path in a browser without the APIs, never starting a worker", async () => {
    const { renderer, workers, plain } = setup({ supported: () => false })

    await expect(renderer.render(url(1), target().element, SIZE)).resolves.toBe("plain")
    await expect(renderer.render(url(1), target().element, SIZE)).resolves.toBe("plain")
    expect(workers).toHaveLength(0)
    expect(plain).toHaveBeenCalledTimes(2)
  })

  it("closes every bitmap and stops the worker on dispose, aborting the renders waiting", async () => {
    const { renderer, worker } = setup()
    const result = drawn()
    const first = renderer.render(url(1), target().element, SIZE)
    worker().answer(url(1), result)
    await first
    const waiting = renderer.render(url(2), target().element, SIZE)
    const stopped = worker()

    renderer.dispose()

    expect(result.fake.closed).toBe(true)
    expect(stopped.terminated).toBe(true)
    await expect(waiting).rejects.toMatchObject({ name: "AbortError" })
  })

  it("rejects bad sizes and colour counts before starting anything", async () => {
    const { renderer, workers } = setup()

    await expect(renderer.render(url(1), target().element, { width: 0, height: 108 })).rejects.toThrow(RangeError)
    await expect(renderer.render(url(1), target().element, { ...SIZE, paletteWidth: 1.5 })).rejects.toThrow(RangeError)
    await expect(renderer.render(url(1), target().element, { ...SIZE, colors: 300 })).rejects.toThrow(RangeError)
    expect(workers).toHaveLength(0)
  })

  it("rejects without a 2D context on the target canvas", async () => {
    const { renderer, worker } = setup()
    const canvas = { width: 300, height: 150, getContext: () => null } as unknown as HTMLCanvasElement

    const rendering = renderer.render(url(1), canvas, SIZE)
    worker().answer(url(1), drawn())

    await expect(rendering).rejects.toThrow("2D context")
  })
})

describe("renderArt", () => {
  it("touches no DOM global until called", async () => {
    vi.resetModules()

    await expect(import("./renderer")).resolves.toHaveProperty("renderArt")
  })
})
