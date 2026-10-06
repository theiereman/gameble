import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"
import { formatNumber } from "../lib/i18n"

// How long a changed count stays brightened (DESIGN.md, Rarity counter).
const CHANGED_MS = 700

// The top bar's rarity counter (DESIGN.md, Rarity counter; EXPERIENCE.md,
// Rarity counter): a count rises as the booster island reveals each card
// (`gameble:tier-revealed`), never before. Each count target (the button's
// and the legend's) names its tier in `data-tier`; the revealed tier's
// counts are rewritten from the event's counts, grouped with the locale's
// delimiter, and brightened a moment. The listener and the timers go on
// disconnect.
export default class extends Controller<HTMLElement> {
  static targets = ["count"]
  static values = { delimiter: { type: String, default: "," } }

  declare readonly countTargets: HTMLElement[]
  declare readonly delimiterValue: string

  private stopListening?: () => void
  private timers = new Set<number>()

  connect(): void {
    this.stopListening = onGameble("gameble:tier-revealed", ({ tier, counts }) => {
      const count = counts?.[tier]
      if (typeof count !== "number") return
      this.countTargets
        .filter((target) => target.dataset.tier === tier)
        .forEach((target) => {
          target.textContent = formatNumber(count, this.delimiterValue)
          target.dataset.changed = ""
          const timer = window.setTimeout(() => {
            this.timers.delete(timer)
            delete target.dataset.changed
          }, CHANGED_MS)
          this.timers.add(timer)
        })
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
    this.timers.forEach((timer) => window.clearTimeout(timer))
    this.timers.clear()
    this.countTargets.forEach((target) => delete target.dataset.changed)
  }
}
