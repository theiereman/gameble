import { Controller } from "@hotwired/stimulus"
import type { CoverageCell } from "../lib/deck_editor"
import { writeHidden, writeText } from "../lib/dom_writes"

export default class DeckCoverageController extends Controller<HTMLElement> {
  static targets = ["cell", "count", "none"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly countTarget: HTMLElement
  declare readonly noneTarget: HTMLElement

  render(coverage: readonly CoverageCell[]): void {
    for (const cell of this.cellTargets) {
      const call = coverage.find((each) => each.call === cell.dataset.call)
      if (!call) continue
      writeHidden(cell, !call.gap)
      writeText(cell.querySelector("[data-deck-coverage-target~='best']"), call.best === null ? "" : String(call.best))
    }
    const missing = coverage.filter((call) => call.gap).length
    writeText(this.countTarget, String(missing))
    writeHidden(this.noneTarget, missing > 0)
  }

  choose(event: Event): void {
    const cell = (event.currentTarget as Element).closest<HTMLElement>("[data-deck-coverage-target~='cell']")
    if (cell?.dataset.call) this.dispatch("gap", { detail: { call: cell.dataset.call } })
  }
}
