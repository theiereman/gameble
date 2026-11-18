import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"

export const FOLD_MS = 220

export default class extends Controller<HTMLButtonElement> {
  static values = { remember: String }

  declare readonly rememberValue: string

  connect(): void {
    const saved = this.readSaved()
    if (saved !== null) this.element.setAttribute("aria-expanded", saved)
  }

  toggle(): void {
    const panel = this.element.closest<HTMLElement>(".panel")
    const from = panel?.offsetHeight ?? 0
    const expanded = this.element.getAttribute("aria-expanded") === "true"
    this.element.setAttribute("aria-expanded", String(!expanded))
    this.save(String(!expanded))
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

  private readSaved(): string | null {
    if (!this.rememberValue) return null
    try {
      return window.localStorage.getItem(this.rememberValue)
    } catch {
      return null
    }
  }

  private save(expanded: string): void {
    if (!this.rememberValue) return
    try {
      window.localStorage.setItem(this.rememberValue, expanded)
    } catch {
      // storage blocked: the fold simply is not remembered
    }
  }
}
