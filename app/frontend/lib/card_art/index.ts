// Draws a card's art: the Steam image pixelated and reduced to 32 colours
// with pixelcrush (AD-17), in the card-art worker (renderer.ts), on the
// card's canvas. Used by the card-art Stimulus controller (CardComponent).
import { DEFAULT_COLORS, renderArt } from "./renderer"

const COLORS = DEFAULT_COLORS

/**
 * Draws `url` on `canvas` at `width` × `height` art pixels and marks
 * `container` with `data-art`: `drawn` (filtered with the game's palette)
 * or `plain` (pixelated without palette, when the image host refuses CORS
 * or the browser lacks the APIs). The palette is computed at `paletteWidth`
 * × `paletteHeight` (the largest art drawn, so a card shows the same colours
 * at every size), the art size by default. On a failure (missing art,
 * Steam's placeholder) the canvas is hidden, so the frame and title remain,
 * and the mark is `failed`. An abort (`signal`, on disconnect) leaves both
 * as they are.
 */
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
  // A Turbo snapshot keeps the last mark and a hidden canvas: start afresh.
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
