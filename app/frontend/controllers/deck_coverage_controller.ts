import { Controller } from "@hotwired/stimulus"
import type { CoverageCell } from "../lib/deck_editor"
import { writeHidden, writeText } from "../lib/dom_writes"
import { t } from "../lib/i18n"

export default class DeckCoverageController extends Controller<HTMLElement> {
  static targets = ["cell"]

  declare readonly cellTargets: HTMLElement[]

  render(coverage: readonly CoverageCell[], covered: string): void {
    for (const cell of this.cellTargets) {
      const call = coverage.find((each) => each.call === cell.dataset.call)
      if (!call) continue
      const best = call.best === null ? "" : String(call.best)
      writeHidden(cell.querySelector<HTMLElement>(".deck-coverage__value"), call.gap)
      writeText(cell.querySelector(".deck-coverage__number"), best)
      writeText(cell.querySelector(".deck-coverage__words"), t(covered, { call: cell.dataset.label ?? "", best }))
      writeHidden(cell.querySelector<HTMLElement>(".deck-coverage__gap"), !call.gap)
    }
  }

  choose(event: Event): void {
    if (!(event.target instanceof Element) || !event.target.closest("button")) return
    const cell = event.target.closest<HTMLElement>("[data-deck-coverage-target~='cell']")
    if (cell?.dataset.call) this.dispatch("gap", { detail: { call: cell.dataset.call } })
  }

  fill(event: Event): void {
    if (event.target instanceof Element && event.target.closest("button")) this.dispatch("fill")
  }
}
