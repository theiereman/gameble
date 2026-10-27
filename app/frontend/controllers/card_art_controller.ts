import { Controller } from "@hotwired/stimulus"
import { drawCardArt } from "../lib/card_art"
import { type ArtSize, artPixels, sameArtSize, type Settle, settle } from "../lib/card_art/fluid_size"

// How near the viewport a card comes before its art is drawn.
const NEAR_VIEWPORT = "300px"

const RESIZE_SETTLE_MS = 150

// Draws the art of a server-rendered card face once it nears the viewport. Each connect waits and draws again, so a Turbo restore shows the art;
// a fluid art box draws at its rendered size and again when a resize settles.
export default class extends Controller<HTMLElement> {
  static targets = ["canvas"]
  static values = {
    url: String,
    width: Number,
    height: Number,
    paletteWidth: Number,
    paletteHeight: Number,
    fluid: Boolean,
  }

  declare readonly canvasTarget: HTMLCanvasElement
  declare readonly urlValue: string
  declare readonly widthValue: number
  declare readonly heightValue: number
  declare readonly paletteWidthValue: number
  declare readonly paletteHeightValue: number
  declare readonly fluidValue: boolean

  private abort?: AbortController
  private observer?: IntersectionObserver
  private resizeObserver?: ResizeObserver
  private resize?: Settle
  private drawn?: ArtSize

  connect(): void {
    this.abort = new AbortController()
    this.drawn = undefined
    if (this.fluidValue) this.watchResizes()
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
    this.stopWatchingResizes()
    this.abort?.abort()
  }

  private draw(): void {
    if (!this.abort) return
    const size = this.artSize()
    this.drawn = size
    void drawCardArt(this.element, this.canvasTarget, this.urlValue, {
      ...size,
      paletteWidth: this.paletteWidthValue || this.widthValue,
      paletteHeight: this.paletteHeightValue || this.heightValue,
      signal: this.abort.signal,
    })
  }

  private redrawAtNewSize(): void {
    if (!this.drawn || !this.hasLayout()) return
    if (sameArtSize(this.drawn, this.artSize())) return
    this.abort?.abort()
    this.abort = new AbortController()
    this.draw()
  }

  private artSize(): ArtSize {
    const served = { width: this.widthValue, height: this.heightValue }
    if (!this.fluidValue) return served
    return artPixels(this.element.clientWidth, this.element.clientHeight, served)
  }

  private hasLayout(): boolean {
    return this.element.clientWidth > 0 && this.element.clientHeight > 0
  }

  private watchResizes(): void {
    if (typeof ResizeObserver === "undefined") return
    const resize = settle(() => this.redrawAtNewSize(), RESIZE_SETTLE_MS)
    this.resize = resize
    this.resizeObserver = new ResizeObserver(() => {
      if (this.drawn) resize.schedule()
    })
    this.resizeObserver.observe(this.element)
  }

  private stopWatching(): void {
    this.observer?.disconnect()
    this.observer = undefined
  }

  private stopWatchingResizes(): void {
    this.resizeObserver?.disconnect()
    this.resizeObserver = undefined
    this.resize?.cancel()
    this.resize = undefined
  }
}
