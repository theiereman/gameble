import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"

export const FOLD_MS = 220

export default class extends Controller<HTMLButtonElement> {
  toggle(): void {
    const panel = this.element.closest<HTMLElement>(".panel")
    const from = panel?.offsetHeight ?? 0
    const expanded = this.element.getAttribute("aria-expanded") === "true"
    this.element.setAttribute("aria-expanded", String(!expanded))
    if (!panel || motionReduced()) return

    const to = panel.offsetHeight
    const clipPath = `inset(${getComputedStyle(panel).getPropertyValue("--corner-brackets-offset").trim() || "0"})`
    panel.animate(
      [
        { height: `${from}px`, clipPath },
        { height: `${to}px`, clipPath },
      ],
      {
        duration: FOLD_MS,
        easing: "ease-out",
      },
    )
  }
}
