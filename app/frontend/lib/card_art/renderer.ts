import { abortError, ArtMissingError } from "./errors"
import { renderPlain, type PlainRenderer } from "./plain"
import type { ArtJob, JobRequest, JobResponse, JobResult } from "./worker_job"

export type RenderArtOptions = {
  width: number
  height: number
  paletteWidth?: number
  paletteHeight?: number
  colors?: number
  signal?: AbortSignal
}

export type RenderResult = "drawn" | "plain"

export type ArtWorker = {
  postMessage(message: JobRequest): void
  addEventListener(type: "message" | "error", listener: (event: any) => void): void
  terminate(): void
}

export type ArtRendererOptions = {
  concurrency?: number
  cacheLimit?: number
  createWorker?: () => ArtWorker
  supported?: () => boolean
  plain?: PlainRenderer
}

export type ArtRenderer = {
  render(url: string, canvas: HTMLCanvasElement, options: RenderArtOptions): Promise<RenderResult>
  dispose(): void
}

export const DEFAULT_COLORS = 32
export const DEFAULT_CONCURRENCY = 3
export const DEFAULT_CACHE_LIMIT = 120

type Settled = JobResult | { status: "disposed" }

type Job = {
  id: number
  key: string
  request: ArtJob
  waiters: number
  running: boolean
  promise: Promise<Settled>
  settle: (result: Settled) => void
}

export function createArtRenderer({
  concurrency = DEFAULT_CONCURRENCY,
  cacheLimit = DEFAULT_CACHE_LIMIT,
  createWorker = startWorker,
  supported = browserSupported,
  plain = renderPlain,
}: ArtRendererOptions = {}): ArtRenderer {
  if (!Number.isInteger(concurrency) || concurrency < 2 || concurrency > 4) {
    throw new RangeError(`concurrency must be an integer from 2 to 4, got ${concurrency}`)
  }
  assertSize("cacheLimit", cacheLimit)

  let mode: "worker" | "plain" | undefined
  let worker: ArtWorker | undefined
  let nextId = 1
  const cache = new Map<string, ImageBitmap>()
  const pending = new Map<string, Job>()
  const queue: Job[] = []
  const running = new Map<number, Job>()

  function useWorker(): boolean {
    mode ??= supported() ? "worker" : "plain"
    return mode === "worker"
  }

  function ensureWorker(): ArtWorker | undefined {
    if (worker) return worker
    try {
      const started = createWorker()
      started.addEventListener("message", (event: MessageEvent<JobResponse>) => {
        if (worker === started) finish(event.data)
      })
      started.addEventListener("error", () => {
        if (worker === started) fallBack()
      })
      worker = started
    } catch {
      fallBack()
    }
    return worker
  }

  function fallBack(): void {
    mode = "plain"
    stop({ status: "unsupported" })
  }

  function stop(result: Settled): void {
    worker?.terminate()
    worker = undefined
    const jobs = [...running.values(), ...queue]
    running.clear()
    queue.length = 0
    pending.clear()
    for (const job of jobs) job.settle(result)
  }

  function finish({ id, ...result }: JobResponse): void {
    const job = running.get(id)
    if (!job) {
      if (result.status === "drawn") result.bitmap.close()
      return
    }
    running.delete(id)
    pending.delete(job.key)
    if (result.status === "drawn") store(job.key, result.bitmap)
    if (result.status === "unsupported") fallBack()
    job.settle(result)
    pump()
  }

  function store(key: string, bitmap: ImageBitmap): void {
    const previous = cache.get(key)
    if (previous && previous !== bitmap) previous.close()
    cache.delete(key)
    cache.set(key, bitmap)
    while (cache.size > cacheLimit) {
      const oldest = cache.keys().next().value!
      cache.get(oldest)!.close()
      cache.delete(oldest)
    }
  }

  function pump(): void {
    while (running.size < concurrency && queue.length > 0) {
      const started = ensureWorker()
      if (!started) return
      const job = queue.shift()!
      job.running = true
      running.set(job.id, job)
      started.postMessage({ id: job.id, ...job.request })
    }
  }

  function jobFor(key: string, request: ArtJob): Job {
    const existing = pending.get(key)
    if (existing) return existing
    let settle!: (result: Settled) => void
    const promise = new Promise<Settled>((resolve) => {
      settle = resolve
    })
    const job: Job = { id: nextId++, key, request, waiters: 0, running: false, promise, settle }
    pending.set(key, job)
    queue.push(job)
    pump()
    return job
  }

  function wait(job: Job, signal: AbortSignal | undefined): Promise<Settled> {
    job.waiters++
    if (!signal) return job.promise
    return new Promise<Settled>((resolve, reject) => {
      const onAbort = () => {
        release(job)
        reject(abortError())
      }
      signal.addEventListener("abort", onAbort, { once: true })
      void job.promise.then((result) => {
        signal.removeEventListener("abort", onAbort)
        resolve(result)
      })
    })
  }

  function release(job: Job): void {
    job.waiters--
    if (job.waiters > 0 || job.running || pending.get(job.key) !== job) return
    pending.delete(job.key)
    const index = queue.indexOf(job)
    if (index !== -1) queue.splice(index, 1)
  }

  async function render(url: string, canvas: HTMLCanvasElement, options: RenderArtOptions): Promise<RenderResult> {
    const { width, height, paletteWidth = width, paletteHeight = height, colors = DEFAULT_COLORS, signal } = options
    assertSize("width", width)
    assertSize("height", height)
    assertSize("paletteWidth", paletteWidth)
    assertSize("paletteHeight", paletteHeight)
    assertColors(colors)
    if (signal?.aborted) throw abortError()

    const key = `${url}|${width}x${height}|${colors}|${paletteWidth}x${paletteHeight}`
    const cached = cache.get(key)
    if (cached) {
      cache.delete(key)
      cache.set(key, cached)
      draw(canvas, cached, width, height)
      return "drawn"
    }

    const plainly = async (): Promise<RenderResult> => {
      await plain(url, canvas, { width, height, signal })
      return "plain"
    }
    if (!useWorker()) return plainly()

    const result = await wait(jobFor(key, { url, width, height, paletteWidth, paletteHeight, colors }), signal)
    if (signal?.aborted) throw abortError()
    switch (result.status) {
      case "drawn":
        draw(canvas, result.bitmap, width, height)
        return "drawn"
      case "missing":
        throw new ArtMissingError(url)
      case "disposed":
        throw abortError()
      case "cors":
      case "unsupported":
        return plainly()
    }
  }

  function dispose(): void {
    stop({ status: "disposed" })
    for (const bitmap of cache.values()) bitmap.close()
    cache.clear()
    mode = undefined
  }

  return { render, dispose }
}

function draw(canvas: HTMLCanvasElement, bitmap: ImageBitmap, width: number, height: number): void {
  const context = canvas.getContext("2d")
  if (!context) throw new Error("No 2D context on the target canvas")
  canvas.width = width
  canvas.height = height
  context.drawImage(bitmap, 0, 0)
}

function assertSize(name: string, value: number): void {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(`${name} must be a positive integer, got ${value}`)
  }
}

function assertColors(colors: number): void {
  if (!Number.isInteger(colors) || colors < 1 || colors > 256) {
    throw new RangeError(`colors must be an integer from 1 to 256, got ${colors}`)
  }
}

function browserSupported(): boolean {
  return typeof Worker !== "undefined" && typeof OffscreenCanvas !== "undefined" && typeof createImageBitmap !== "undefined"
}

function startWorker(): ArtWorker {
  return new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })
}

let shared: ArtRenderer | undefined

export function renderArt(url: string, canvas: HTMLCanvasElement, options: RenderArtOptions): Promise<RenderResult> {
  shared ??= createArtRenderer()
  return shared.render(url, canvas, options)
}
