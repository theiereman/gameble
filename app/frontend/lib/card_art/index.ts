import { DEFAULT_COLORS, renderArt } from "./renderer"

const COLORS = DEFAULT_COLORS

export async function drawCardArt(
  container: HTMLElement,
  canvas: HTMLCanvasElement,
  url: string,
  {
    width,
    height,
    paletteWidth = width,
    paletteHeight = height,
    signal,
  }: { width: number; height: number; paletteWidth?: number; paletteHeight?: number; signal: AbortSignal },
): Promise<void> {
  delete container.dataset.art
  canvas.hidden = false
  try {
    if (!url) throw new Error("No art for this card")
    container.dataset.art = await renderArt(url, canvas, {
      width,
      height,
      paletteWidth,
      paletteHeight,
      colors: COLORS,
      signal,
    })
  } catch (error) {
    if (signal.aborted || (error instanceof DOMException && error.name === "AbortError")) return
    canvas.hidden = true
    container.dataset.art = "failed"
  }
}
