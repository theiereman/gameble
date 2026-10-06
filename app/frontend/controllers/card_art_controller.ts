import { Controller } from "@hotwired/stimulus"
import { drawCardArt } from "../lib/card_art"

// How near the viewport a card comes before its art is drawn.
const NEAR_VIEWPORT = "300px"

// Draws the art of a server-rendered card face (CardComponent), only once
// the card nears the viewport, so a page of hundreds of cards (a large set)
// does not fetch and filter every image at once. Each connect waits and
// draws again, so a Turbo restore visit, whose cached snapshot keeps no
// canvas pixels, shows the art again; a disconnect stops the wait and aborts
// a draw under way. The palette size defaults to the art size (0 or absent).
export default class extends Controller<HTMLElement> {
  static targets = ["canvas"]
  static values = { url: String, width: Number, height: Number, paletteWidth: Number, paletteHeight: Number }

  declare readonly canvasTarget: HTMLCanvasElement
  declare readonly urlValue: string
  declare readonly widthValue: number
  declare readonly heightValue: number
  declare readonly paletteWidthValue: number
  declare readonly paletteHeightValue: number

  private abort?: AbortController
  private observer?: IntersectionObserver

  connect(): void {
    this.abort = new AbortController()
    if (typeof IntersectionObserver === "undefined") {
      this.draw()
      return
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return
        this.stopWatching()
        this.draw()
      },
      { rootMargin: NEAR_VIEWPORT },
    )
    this.observer.observe(this.element)
  }

  disconnect(): void {
    this.stopWatching()
    this.abort?.abort()
  }

  private draw(): void {
    if (!this.abort) return
    void drawCardArt(this.element, this.canvasTarget, this.urlValue, {
      width: this.widthValue,
      height: this.heightValue,
      paletteWidth: this.paletteWidthValue || this.widthValue,
      paletteHeight: this.paletteHeightValue || this.heightValue,
      signal: this.abort.signal,
    })
  }

  private stopWatching(): void {
    this.observer?.disconnect()
    this.observer = undefined
  }
}
