// The worker entry: one job per message, one URL at a time, its bitmap transferred back.
import { createJobRunner, PaletteCache, type JobEnvironment, type JobRequest, type JobResponse, type WorkerSurface } from "./worker_job"

type WorkerScope = {
  addEventListener(type: "message", listener: (event: MessageEvent<JobRequest>) => void): void
  postMessage(message: JobResponse, transfer: Transferable[]): void
}

const scope = globalThis as unknown as WorkerScope

function createSurface(width: number, height: number): WorkerSurface | null {
  if (typeof OffscreenCanvas === "undefined") return null
  try {
    const canvas = new OffscreenCanvas(width, height)
    const context = canvas.getContext("2d", { willReadFrequently: true })
    return context ? { canvas, context } : null
  } catch {
    return null
  }
}

const environment: JobEnvironment = {
  fetch: (url, init) => fetch(url, init),
  createImageBitmap: (blob) => createImageBitmap(blob),
  createSurface,
  palettes: new PaletteCache(),
}

const run = createJobRunner(environment)

scope.addEventListener("message", (event) => {
  const { id, ...job } = event.data
  void run(job).then((result) => {
    scope.postMessage({ id, ...result }, result.status === "drawn" ? [result.bitmap] : [])
  })
})
