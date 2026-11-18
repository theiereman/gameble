import { Controller } from "@hotwired/stimulus"
import type { CollectionView, DeckStrings } from "../lib/deck_editor"
import { writeAttribute, writeChecked, writeFlag, writeHidden, writeText } from "../lib/dom_writes"
import { columnsOf } from "../lib/grid_keys"

export type MoveIntent = { key: string; columns: number }

const sortOf = (option: HTMLAnchorElement): string => new URL(option.href).searchParams.get("sort") ?? ""

export default class DeckCollectionController extends Controller<HTMLElement> {
  static targets = ["empty", "entry", "list", "more", "sortOption", "trump"]

  declare readonly entryTargets: HTMLElement[]
  declare readonly hasListTarget: boolean
  declare readonly listTarget: HTMLElement
  declare readonly sortOptionTargets: HTMLAnchorElement[]
  declare readonly trumpTargets: HTMLInputElement[]
  declare readonly hasEmptyTarget: boolean
  declare readonly emptyTarget: HTMLElement
  declare readonly hasMoreTarget: boolean
  declare readonly moreTarget: HTMLElement

  render({ sort, trump, remaining, matches, entries }: CollectionView, strings: DeckStrings): void {
    this.reorder([...entries.keys()])
    for (const entry of this.entryTargets) {
      const state = entries.get(entry.dataset.ref ?? "")
      if (!state) continue
      writeHidden(entry.closest("li"), state.hidden)
      writeAttribute(entry, "tabindex", state.tabbable ? "0" : "-1")
      writeAttribute(entry, "aria-pressed", String(state.inDeck))
      writeAttribute(entry, "aria-label", `${entry.dataset.label ?? ""}${state.inDeck ? strings.inDeckSuffix : ""}`)
      writeText(
        entry.querySelector("[data-deck-collection-target~='action']"),
        state.inDeck ? strings.inDeck : strings.add,
      )
    }
    for (const option of this.sortOptionTargets) {
      const current = sortOf(option) === sort
      writeFlag(option, "aria-current", current)
      if (current) writeText(this.element.querySelector(".sort__current"), option.textContent ?? "")
    }
    if (this.hasEmptyTarget) writeHidden(this.emptyTarget, matches > 0)
    if (this.hasMoreTarget) writeHidden(this.moreTarget, remaining === 0)
    for (const radio of this.trumpTargets) writeChecked(radio, radio.value === trump)
  }

  focusActive(): void {
    this.entryTargets.find((entry) => entry.getAttribute("tabindex") === "0")?.focus()
  }

  choose(event: Event): void {
    const ref = (event.currentTarget as HTMLElement).dataset.ref
    if (ref) this.dispatch("choose", { detail: { ref } })
  }

  search(event: Event): void {
    this.dispatch("search", { detail: { query: (event.currentTarget as HTMLInputElement).value } })
  }

  more(event: Event): void {
    if (event.target instanceof Element && event.target.closest("button")) this.dispatch("more")
  }

  sort(event: Event): void {
    event.preventDefault()
    const option = event.currentTarget as HTMLAnchorElement
    const menu = option.closest("details")
    if (menu) {
      menu.open = false
      menu.querySelector("summary")?.focus()
    }
    this.dispatch("sort", { detail: { sort: sortOf(option) } })
  }

  filter(event: Event): void {
    const radio = event.currentTarget as HTMLInputElement
    if (radio.checked) this.dispatch("filter", { detail: { trump: radio.value } })
  }

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof HTMLElement) || !this.entryTargets.includes(event.target)) return
    const detail: MoveIntent = { key: event.key, columns: columnsOf(this.firstRowTops()) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  private reorder(order: readonly string[]): void {
    if (!this.hasListTarget) return
    const items = new Map(this.entryTargets.map((entry) => [entry.dataset.ref ?? "", entry.closest("li")]))
    const wanted = order
      .map((ref) => items.get(ref))
      .filter((item): item is HTMLLIElement => item instanceof HTMLLIElement)
    const current = Array.from(this.listTarget.children)
    if (wanted.every((item, index) => current[index] === item)) return
    this.listTarget.append(...wanted)
  }

  private firstRowTops(): number[] {
    const tops: number[] = []
    for (const entry of this.entryTargets) {
      if (entry.closest("li")?.hidden) continue
      tops.push(entry.offsetTop)
      if (entry.offsetTop !== tops[0]) break
    }
    return tops
  }
}
