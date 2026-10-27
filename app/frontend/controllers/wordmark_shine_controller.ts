import { Controller } from "@hotwired/stimulus"
import { onMotionChange } from "../lib/motion"
import { clearSweep, endSweep, startSweep } from "../lib/wordmark_shine"

export default class extends Controller<HTMLElement> {
  private stopWatchingMotion?: () => void

  connect(): void {
    clearSweep(this.element)
    // Chrome fires no animationcancel when the reduced-motion rule removes the animation.
    this.stopWatchingMotion = onMotionChange((reduced) => {
      if (reduced) clearSweep(this.element)
    })
  }

  disconnect(): void {
    this.stopWatchingMotion?.()
    this.stopWatchingMotion = undefined
    clearSweep(this.element)
  }

  sweep(event: PointerEvent): void {
    if (event.pointerType !== "mouse") return
    if (this.element.getAttribute("aria-disabled") === "true") return
    startSweep(this.element)
  }

  end(event: AnimationEvent): void {
    endSweep(this.element, event.animationName)
  }
}
