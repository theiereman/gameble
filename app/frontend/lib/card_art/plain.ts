import { downscale, type Surface } from "./downscale"
import { abortable, abortError, ArtMissingError, isAbortError } from "./errors"
import { isTooSmall } from "./placeholder"

export type PlainOptions = { width: number; height: number; signal?: AbortSignal }

/** Draws `url` on `canvas` without palette; see `renderPlain`. */
export type PlainRenderer = (url: string, canvas: HTMLCanvasElement, options: PlainOptions) => Promise<void>

/**
 * The main-thread path, for a CORS refusal and for browsers without a worker,
 * `OffscreenCanvas` or `createImageBitmap` (AD-17): a plain image (no
 * `crossOrigin`, no referrer), cropped anchored at 42 % and halved on scratch
 * canvases to the art size, drawn without palette. The image taints the
 * canvases, so its pixels are never read: no palette, no grey check, only the
 * size check. Rejects with `ArtMissingError` when the image does not load or is
 * too small, and with `AbortError`, drawing nothing, once `signal` aborts.
 */
export const renderPlain: PlainRenderer = async (url, canvas, { width, height, signal }) => {
  if (signal?.aborted) throw abortError()
  const image = new Image()
  image.referrerPolicy = "no-referrer"
  image.src = url
  try {
    await abortable(image.decode(), signal)
  } catch (error) {
    if (isAbortError(error)) throw error
    throw new ArtMissingError(url)
  }
  if (isTooSmall(image.naturalWidth, image.naturalHeight)) throw new ArtMissingError(url)

  const last = downscale(image, image.naturalWidth, image.naturalHeight, width, height, scratch)
  if (!last) throw new Error("No 2D context on a scratch canvas")
  if (signal?.aborted) throw abortError()

  const context = canvas.getContext("2d")
  if (!context) throw new Error("No 2D context on the target canvas")
  canvas.width = width
  canvas.height = height
  context.imageSmoothingEnabled = true
  context.imageSmoothingQuality = "high"
  context.drawImage(last.canvas, 0, 0, last.width, last.height, 0, 0, width, height)
}

function scratch(width: number, height: number): Surface<CanvasRenderingContext2D> | null {
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const context = canvas.getContext("2d")
  return context ? { canvas, context } : null
}
