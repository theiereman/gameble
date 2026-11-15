import { Controller } from "@hotwired/stimulus"
import type { DeckStrings, EntryView } from "../lib/deck_editor"
import { writeAttribute, writeText } from "../lib/dom_writes"
import { columnsOf } from "../lib/grid_keys"

export type MoveIntent = { key: string; columns: number }

export default class DeckCollectionController extends Controller<HTMLElement> {
  static targets = ["entry"]

  declare readonly entryTargets: HTMLElement[]

  render(view: ReadonlyMap<string, EntryView>, strings: DeckStrings): void {
    for (const entry of this.entryTargets) {
      const state = view.get(entry.dataset.ref ?? "")
      if (!state) continue
      writeAttribute(entry, "tabindex", state.tabbable ? "0" : "-1")
      writeAttribute(entry, "aria-pressed", String(state.inDeck))
      writeAttribute(entry, "aria-label", `${entry.dataset.label ?? ""}${state.inDeck ? strings.inDeckSuffix : ""}`)
      writeText(
        entry.querySelector("[data-deck-collection-target~='action']"),
        state.inDeck ? strings.inDeck : strings.add,
      )
    }
  }

  focusActive(): void {
    this.entryTargets.find((entry) => entry.getAttribute("tabindex") === "0")?.focus()
  }

  choose(event: Event): void {
    const ref = (event.currentTarget as HTMLElement).dataset.ref
    if (ref) this.dispatch("choose", { detail: { ref } })
  }

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof HTMLElement) || !this.entryTargets.includes(event.target)) return
    const detail: MoveIntent = { key: event.key, columns: columnsOf(this.firstRowTops()) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  private firstRowTops(): number[] {
    const tops: number[] = []
    for (const entry of this.entryTargets) {
      tops.push(entry.offsetTop)
      if (entry.offsetTop !== tops[0]) break
    }
    return tops
  }
}
