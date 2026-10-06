import { Controller } from "@hotwired/stimulus"
import { attachTilt } from "../lib/tilt"
import { observeInView } from "../lib/in_view"

// A card face's tilt, glare and in-view mark (CardComponent; lib/tilt.ts):
// holo and foil run only while `data-in-view` is set (styles/card.css). A
// Turbo snapshot keeps the attributes and properties of the moment it was
// taken: each connect starts from a clean face, each disconnect leaves one.
export default class extends Controller<HTMLElement> {
  static values = { max: { type: Number, default: 10 } }

  declare readonly maxValue: number

  private detach?: () => void
  private unobserve?: () => void

  connect(): void {
    this.reset()
    this.unobserve = observeInView(this.element, (inView) => {
      this.element.toggleAttribute("data-in-view", inView)
    })
    this.detach = attachTilt(this.element, { max: this.maxValue })
  }

  disconnect(): void {
    this.detach?.()
    this.unobserve?.()
    this.detach = this.unobserve = undefined
    this.reset()
  }

  private reset(): void {
    for (const property of ["--tilt-rx", "--tilt-ry", "--glare-dx", "--glare-dy"]) this.element.style.removeProperty(property)
    this.element.removeAttribute("data-in-view")
    this.element.removeAttribute("data-tilt")
    this.element.removeAttribute("data-tilting")
    // An emptied style attribute goes, so the face is as the server wrote it.
    if (this.element.getAttribute("style") === "") this.element.removeAttribute("style")
  }
}
