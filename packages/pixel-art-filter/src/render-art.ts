import { filter } from "./filter"
import { assertColors, assertSize, type Pixels } from "./pixels"

export type RenderArtOptions = { width: number; height: number; colors?: number; signal?: AbortSignal }

/** Most filtered images kept in memory; the least recently used is dropped first. */
export const MEMO_LIMIT = 200

const memo = new Map<string, Promise<Pixels>>()

/**
 * Loads the image at `url` cross-origin, filters it to `width × height` and
 * `colors` colours, and draws it on `canvas` at that size. Rejects when the
 * image cannot be loaded or decoded, when a 2D context is missing, or when the
 * image taints the canvas, so the caller can show the card without art. After
 * `signal` aborts, it rejects with an `AbortError` and draws nothing.
 */
export async function renderArt(url: string, canvas: HTMLCanvasElement, { width, height, colors = 16, signal }: RenderArtOptions): Promise<void> {
  assertSize("width", width)
  assertSize("height", height)
  assertColors(colors)
  if (signal?.aborted) throw abortError()

  const pixels = await abortable(memoised(url, width, height, colors), signal)
  if (signal?.aborted) throw abortError()

  const context = canvas.getContext("2d")
  if (!context) throw new Error("No 2D context on the target canvas")
  canvas.width = width
  canvas.height = height
  context.putImageData(new ImageData(pixels.data, width, height), 0, 0)
}

function memoised(url: string, width: number, height: number, colors: number): Promise<Pixels> {
  const key = `${url} ${width}x${height} ${colors}`
  let pending = memo.get(key)
  if (pending) {
    memo.delete(key)
  } else {
    pending = load(url, width, height, colors)
    const settled = pending
    settled.catch(() => {
      if (memo.get(key) === settled) memo.delete(key)
    })
  }
  memo.set(key, pending)
  while (memo.size > MEMO_LIMIT) memo.delete(memo.keys().next().value!)
  return pending
}

async function load(url: string, width: number, height: number, colors: number): Promise<Pixels> {
  const image = new Image()
  image.crossOrigin = "anonymous"
  image.src = url
  await image.decode()
  if (!image.naturalWidth || !image.naturalHeight) throw new Error(`Image has no size: ${url}`)

  // Drawn at about twice the grid size, covering it, so the browser smooths the
  // first reduction; the filter then crops and averages to the grid.
  const scale = Math.max((width * 2) / image.naturalWidth, (height * 2) / image.naturalHeight)
  const scratch = document.createElement("canvas")
  scratch.width = Math.max(1, Math.round(image.naturalWidth * scale))
  scratch.height = Math.max(1, Math.round(image.naturalHeight * scale))
  const context = scratch.getContext("2d", { willReadFrequently: true })
  if (!context) throw new Error("No 2D context on the scratch canvas")
  context.drawImage(image, 0, 0, scratch.width, scratch.height)
  const source = context.getImageData(0, 0, scratch.width, scratch.height)

  return filter({ width: source.width, height: source.height, data: source.data }, { width, height, colors }).pixels
}

function abortable<T>(promise: Promise<T>, signal: AbortSignal | undefined): Promise<T> {
  if (!signal) return promise
  return new Promise<T>((resolve, reject) => {
    const onAbort = () => reject(abortError())
    signal.addEventListener("abort", onAbort, { once: true })
    promise.then(
      (value) => {
        signal.removeEventListener("abort", onAbort)
        resolve(value)
      },
      (error: unknown) => {
        signal.removeEventListener("abort", onAbort)
        reject(error)
      },
    )
  })
}

function abortError(): DOMException {
  return new DOMException("The art render was aborted", "AbortError")
}
