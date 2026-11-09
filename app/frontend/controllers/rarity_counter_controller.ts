import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"
import { fetchChip } from "../lib/countdown"
import { onGameble } from "../lib/events"
import { formatNumber } from "../lib/i18n"
import { RarityLegendRefresh } from "../lib/rarity_legend_refresh"

const CHANGED_MS = 700

export default class extends Controller<HTMLElement> {
  static targets = ["count"]
  static values = { delimiter: { type: String, default: "," }, legendUrl: String }

  declare readonly countTargets: HTMLElement[]
  declare readonly delimiterValue: string
  declare readonly legendUrlValue: string

  private stopListening?: () => void
  private stopWatchingOpenings?: () => void
  private timers = new Set<number>()
  private legendRefresh?: RarityLegendRefresh

  connect(): void {
    const legendRefresh = new RarityLegendRefresh({
      fetchLegend: () => fetchChip(this.legendUrlValue),
      render: (html) => window.Turbo.renderStreamMessage(html),
    })
    this.legendRefresh = legendRefresh
    this.stopWatchingOpenings = onGameble("gameble:opening-revealing", ({ revealing }) =>
      legendRefresh.openingChanged(revealing),
    )
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
    this.legendRefresh?.stop()
    this.legendRefresh = undefined
    this.stopWatchingOpenings?.()
    this.stopWatchingOpenings = undefined
    this.stopListening?.()
    this.stopListening = undefined
    this.timers.forEach((timer) => window.clearTimeout(timer))
    this.timers.clear()
    this.countTargets.forEach((target) => delete target.dataset.changed)
  }
}
