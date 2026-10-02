// Draws a card's art: the Steam image pixelated and reduced to 16 colours by
// pixel-art-filter (AD-17), on the card's canvas. Shared by the card-art
// Stimulus controller (CardComponent) and the React Card.
import { renderArt } from "pixel-art-filter"

export type CardSize = "small" | "large"

/** The art window, in art pixels (one art pixel is 2 CSS pixels). */
export const CARD_ART: Record<CardSize, { width: number; height: number }> = {
  small: { width: 68, height: 108 },
  large: { width: 104, height: 164 },
}

/**
 * Draws `url` on `canvas` and marks `container` with `data-art="drawn"`. On a
 * failure the canvas is hidden, so the frame and title remain, and the mark is
 * `failed`. An abort (`signal`, on disconnect or unmount) leaves both as they
 * are.
 */
export async function drawCardArt(
  container: HTMLElement,
  canvas: HTMLCanvasElement,
  url: string,
  { width, height, signal }: { width: number; height: number; signal: AbortSignal },
): Promise<void> {
  // A Turbo snapshot keeps the last mark and a hidden canvas: start afresh.
  delete container.dataset.art
  canvas.hidden = false
  try {
    if (!url) throw new Error("No art for this card")
    await renderArt(url, canvas, { width, height, colors: 16, signal })
    container.dataset.art = "drawn"
  } catch (error) {
    if (signal.aborted || (error instanceof DOMException && error.name === "AbortError")) return
    canvas.hidden = true
    container.dataset.art = "failed"
  }
}
