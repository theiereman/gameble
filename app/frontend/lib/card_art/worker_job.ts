import { applyPalette, buildPalette, pixelate, type Color, type Pixels } from "pixelcrush"
import { downscale } from "./downscale"
import { isFlatGrey, isTooSmall } from "./placeholder"

/** One art to draw: `url` at `width × height`, with the game's palette computed at `paletteWidth × paletteHeight`. */
export type ArtJob = {
  url: string
  width: number
  height: number
  paletteWidth: number
  paletteHeight: number
  colors: number
}

/** `drawn` the filtered art; `missing` an HTTP error, undecodable image or placeholder; `cors` the request failed (retry once without CORS); `unsupported` no 2D context. */
export type JobResult =
  | { status: "drawn"; bitmap: ImageBitmap }
  | { status: "missing" }
  | { status: "cors" }
  | { status: "unsupported" }

export type JobRequest = ArtJob & { id: number }
export type JobResponse = JobResult & { id: number }

/** The image request: no added header, no referrer, no cookie. */
export const IMAGE_REQUEST: Readonly<RequestInit> = Object.freeze({ mode: "cors", credentials: "omit", referrerPolicy: "no-referrer" })

/** How long the image request and its body may take before the art counts as missing. */
export const FETCH_TIMEOUT_MS = 20_000

/** Games whose palette the worker keeps. */
export const PALETTE_LIMIT = 256

export type WorkerContext = Pick<
  OffscreenCanvasRenderingContext2D,
  "drawImage" | "imageSmoothingEnabled" | "imageSmoothingQuality" | "getImageData" | "putImageData"
>

export type WorkerSurface = {
  canvas: CanvasImageSource & { transferToImageBitmap(): ImageBitmap }
  context: WorkerContext
}

/** What a job needs from the worker, injected so it can be tested. */
export type JobEnvironment = {
  fetch: (url: string, init: RequestInit) => Promise<Pick<Response, "ok" | "blob">>
  createImageBitmap: (blob: Blob) => Promise<ImageBitmap>
  /** A scratch `OffscreenCanvas` and its 2D context, or `null` when there is none. */
  createSurface: (width: number, height: number) => WorkerSurface | null
  palettes: PaletteCache
  /** Defaults to `FETCH_TIMEOUT_MS`. */
  fetchTimeout?: number
}

/** One palette per game, keyed by URL and computed once at the palette size so every card size shares its colours; least recently used dropped past `limit`. */
export class PaletteCache {
  readonly limit: number
  #entries = new Map<string, { colors: number; palette: Color[] }>()

  constructor(limit = PALETTE_LIMIT) {
    this.limit = limit
  }

  get size(): number {
    return this.#entries.size
  }

  get(url: string, colors: number): Color[] | undefined {
    const entry = this.#entries.get(url)
    if (!entry || entry.colors !== colors) return undefined
    this.#entries.delete(url)
    this.#entries.set(url, entry)
    return entry.palette
  }

  set(url: string, colors: number, palette: Color[]): void {
    this.#entries.delete(url)
    this.#entries.set(url, { colors, palette })
    while (this.#entries.size > this.limit) this.#entries.delete(this.#entries.keys().next().value!)
  }
}

const MISSING: JobResult = { status: "missing" }
const UNSUPPORTED: JobResult = { status: "unsupported" }

/** Fetches, decodes, crops (anchored at 42 %), downsizes and remaps one art to the game's palette. Never rejects. */
export async function runJob(job: ArtJob, environment: JobEnvironment): Promise<JobResult> {
  const timeout = new AbortController()
  const timer = setTimeout(
    () => timeout.abort(new DOMException("The image request timed out", "TimeoutError")),
    environment.fetchTimeout ?? FETCH_TIMEOUT_MS,
  )
  let blob: Blob
  try {
    let response: Pick<Response, "ok" | "blob">
    try {
      response = await environment.fetch(job.url, { ...IMAGE_REQUEST, signal: timeout.signal })
    } catch {
      return timeout.signal.aborted ? MISSING : { status: "cors" }
    }
    if (!response.ok) return MISSING
    try {
      blob = await response.blob()
    } catch {
      return MISSING
    }
  } finally {
    clearTimeout(timer)
  }

  let bitmap: ImageBitmap
  try {
    bitmap = await environment.createImageBitmap(blob)
  } catch {
    return MISSING
  }

  try {
    if (isTooSmall(bitmap.width, bitmap.height)) return MISSING
    const art = artPixels(bitmap, job.width, job.height, environment)
    if (!art) return UNSUPPORTED

    let palette = environment.palettes.get(job.url, job.colors)
    if (!palette) {
      const atPaletteSize = job.paletteWidth === job.width && job.paletteHeight === job.height
        ? art
        : artPixels(bitmap, job.paletteWidth, job.paletteHeight, environment)
      if (!atPaletteSize) return UNSUPPORTED
      if (isFlatGrey(atPaletteSize)) return MISSING
      palette = buildPalette(atPaletteSize, job.colors)
      environment.palettes.set(job.url, job.colors, palette)
    }

    const output = environment.createSurface(job.width, job.height)
    if (!output) return UNSUPPORTED
    const filtered = applyPalette(art, palette)
    // pixelcrush types the data as a Uint8ClampedArray on any buffer; applyPalette allocates a plain ArrayBuffer.
    const data = filtered.data as Uint8ClampedArray<ArrayBuffer>
    output.context.putImageData(new ImageData(data, filtered.width, filtered.height), 0, 0)
    return { status: "drawn", bitmap: output.canvas.transferToImageBitmap() }
  } catch {
    return MISSING
  } finally {
    bitmap.close()
  }
}

/** The bitmap cropped and averaged to `width × height`, or `null` without a 2D context. */
function artPixels(bitmap: ImageBitmap, width: number, height: number, { createSurface }: JobEnvironment): Pixels | null {
  const last = downscale(bitmap, bitmap.width, bitmap.height, width, height, createSurface)
  if (!last) return null
  const { data } = last.context.getImageData(0, 0, last.width, last.height)
  return pixelate({ width: last.width, height: last.height, data }, { width, height, crop: "none" })
}

/** Runs jobs one URL at a time, so a game's next job finds its palette computed; other URLs run side by side. */
export function createJobRunner(environment: JobEnvironment): (job: ArtJob) => Promise<JobResult> {
  const chains = new Map<string, Promise<JobResult>>()
  return (job) => {
    const previous = chains.get(job.url)
    const result = previous ? previous.then(() => runJob(job, environment)) : runJob(job, environment)
    chains.set(job.url, result)
    void result.then(() => {
      if (chains.get(job.url) === result) chains.delete(job.url)
    })
    return result
  }
}
