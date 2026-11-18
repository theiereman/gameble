import { Controller } from "@hotwired/stimulus"
import type { CoverageCell } from "../lib/deck_editor"
import { writeHidden } from "../lib/dom_writes"

export default class DeckCoverageController extends Controller<HTMLElement> {
  static targets = ["advantage", "drawback", "noAdvantage", "noDrawback"]

  declare readonly advantageTargets: HTMLElement[]
  declare readonly drawbackTargets: HTMLElement[]
  declare readonly noAdvantageTarget: HTMLElement
  declare readonly noDrawbackTarget: HTMLElement

  render(coverage: readonly CoverageCell[]): void {
    const byCall = new Map(coverage.map((cell) => [cell.call, cell]))
    for (const line of this.advantageTargets) writeHidden(line, !byCall.get(line.dataset.call ?? "")?.many)
    for (const line of this.drawbackTargets) writeHidden(line, !byCall.get(line.dataset.call ?? "")?.gap)
    writeHidden(
      this.noAdvantageTarget,
      coverage.some((cell) => cell.many),
    )
    writeHidden(
      this.noDrawbackTarget,
      coverage.some((cell) => cell.gap),
    )
  }

  choose(event: Event): void {
    const line = (event.currentTarget as Element).closest<HTMLElement>("[data-deck-coverage-target~='drawback']")
    if (line?.dataset.call) this.dispatch("gap", { detail: { call: line.dataset.call } })
  }
}
