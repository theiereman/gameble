// Draws a card's art: the Steam image pixelated and reduced to 32 colours by
// pixel-art-filter (AD-17), in its worker, on the card's canvas. Shared by
// the card-art Stimulus controller (CardComponent) and the React Card.
import { renderArt } from "pixel-art-filter"

export type CardSize = "small" | "large"

type ArtSize = { width: number; height: number }

/** The art window, in art pixels (one art pixel is 2 CSS pixels). */
export const CARD_ART: Record<CardSize, ArtSize> = {
  small: { width: 68, height: 108 },
  large: { width: 104, height: 164 },
}

/**
 * The size each game's palette is computed at: the largest art drawn, so a
 * card shows the same colours at every size.
 */
export const PALETTE_SIZE: ArtSize = Object.values(CARD_ART).reduce((largest, size) =>
  size.width * size.height > largest.width * largest.height ? size : largest,
)

const COLORS = 32

/**
 * Draws `url` on `canvas` and marks `container` with `data-art`: `drawn`
 * (filtered with the game's palette) or `plain` (pixelated without palette,
 * when the image host refuses CORS or the browser lacks the APIs). On a
 * failure (missing art, Steam's placeholder) the canvas is hidden, so the
 * frame and title remain, and the mark is `failed`. An abort (`signal`, on
 * disconnect or unmount) leaves both as they are.
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
    container.dataset.art = await renderArt(url, canvas, {
      width,
      height,
      paletteWidth: PALETTE_SIZE.width,
      paletteHeight: PALETTE_SIZE.height,
      colors: COLORS,
      signal,
    })
  } catch (error) {
    if (signal.aborted || (error instanceof DOMException && error.name === "AbortError")) return
    canvas.hidden = true
    container.dataset.art = "failed"
  }
}
