import { Controller } from "@hotwired/stimulus"
import { TILT_PROPERTIES, attachTilt } from "../lib/tilt"
import { attachGlitter, glitterSeed, type Glitter } from "../lib/glitter"
import { observeInView } from "../lib/in_view"

const pixels = (value: string): number | undefined => {
  const trimmed = value.trim()
  return trimmed.endsWith("px") ? Number.parseFloat(trimmed) || 0 : undefined
}

// A card face's tilt, reflection, glitter and in-view mark. A Turbo snapshot keeps the attributes and flakes of the moment it was taken,
// so each connect starts from a clean face and each disconnect leaves one.
export default class extends Controller<HTMLElement> {
  static values = { max: { type: Number, default: 10 } }
  static targets = ["glitter"]

  declare readonly maxValue: number
  declare readonly hasGlitterTarget: boolean
  declare readonly glitterTarget: HTMLElement

  private detach?: () => void
  private unobserve?: () => void
  private glitter?: Glitter

  connect(): void {
    this.reset()
    this.unobserve = observeInView(this.element, (inView) => {
      this.element.toggleAttribute("data-in-view", inView)
    })
    this.glitter = this.attachGlitter()
    this.glitter?.update(0, 0)
    this.detach = attachTilt(this.element, { max: this.maxValue, onTilt: this.glitter?.update })
  }

  disconnect(): void {
    this.detach?.()
    this.unobserve?.()
    this.glitter?.detach()
    this.detach = this.unobserve = this.glitter = undefined
    this.reset()
  }

  private attachGlitter(): Glitter | undefined {
    if (!this.hasGlitterTarget) return undefined
    const style = getComputedStyle(this.element)
    return attachGlitter(this.glitterTarget, {
      seed: glitterSeed(this.glitterTarget.dataset.glitterSeed),
      width: pixels(style.getPropertyValue("--card-width")) ?? this.element.offsetWidth,
      height: pixels(style.getPropertyValue("--card-height")) ?? this.element.offsetHeight,
    })
  }

  private reset(): void {
    for (const property of TILT_PROPERTIES) this.element.style.removeProperty(property)
    this.element.removeAttribute("data-in-view")
    this.element.removeAttribute("data-tilt")
    this.element.removeAttribute("data-tilting")
    if (this.element.getAttribute("style") === "") this.element.removeAttribute("style")
  }
}
