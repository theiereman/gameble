// The art size of a card face drawn at its rendered size (CardComponent's
// grid face), and the wait for a resize to settle before drawing it again.

export type ArtSize = { width: number; height: number }

const CSS_PIXELS_PER_ART_PIXEL = 2

export function artPixels(cssWidth: number, cssHeight: number, fallback: ArtSize): ArtSize {
  const width = Math.floor(cssWidth / CSS_PIXELS_PER_ART_PIXEL)
  const height = Math.floor(cssHeight / CSS_PIXELS_PER_ART_PIXEL)
  return width > 0 && height > 0 ? { width, height } : fallback
}

export function sameArtSize(a: ArtSize | undefined, b: ArtSize): boolean {
  return a !== undefined && a.width === b.width && a.height === b.height
}

export type Settle = { schedule(): void; cancel(): void }

export function settle(callback: () => void, delay: number): Settle {
  let timer: ReturnType<typeof setTimeout> | undefined
  const cancel = () => {
    if (timer !== undefined) clearTimeout(timer)
    timer = undefined
  }
  return {
    schedule() {
      cancel()
      timer = setTimeout(() => {
        timer = undefined
        callback()
      }, delay)
    },
    cancel,
  }
}
