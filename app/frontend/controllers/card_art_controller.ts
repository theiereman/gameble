import { Controller } from "@hotwired/stimulus"
import { drawCardArt } from "../lib/card_art"

// Draws the art of a server-rendered card face (CardComponent). Each connect
// draws again, so a Turbo restore visit, whose cached snapshot keeps no
// canvas pixels, shows the art again; a disconnect aborts a draw under way.
export default class extends Controller<HTMLElement> {
  static targets = ["canvas"]
  static values = { url: String, width: Number, height: Number }

  declare readonly canvasTarget: HTMLCanvasElement
  declare readonly urlValue: string
  declare readonly widthValue: number
  declare readonly heightValue: number

  private abort?: AbortController

  connect(): void {
    this.abort = new AbortController()
    void drawCardArt(this.element, this.canvasTarget, this.urlValue, {
      width: this.widthValue,
      height: this.heightValue,
      signal: this.abort.signal,
    })
  }

  disconnect(): void {
    this.abort?.abort()
  }
}
