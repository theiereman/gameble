import { Controller } from "@hotwired/stimulus"
import { onMotionChange } from "../lib/motion"
import { clearSweep, endSweep, startSweep } from "../lib/wordmark_shine"

// A top-bar wordmark, link or not (lib/wordmark_shine.ts): a mouse entering
// it sweeps the shine once; keyboard focus, a pen or a finger do not, nor
// does a link the booster has locked (`aria-disabled`, by navigation-lock).
// Motion reduced mid-sweep puts the wordmark back at rest. A Turbo snapshot
// keeps the attribute of the moment it was taken: each connect starts at
// rest, each disconnect leaves it there.
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
