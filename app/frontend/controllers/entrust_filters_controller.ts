import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import { writeText } from "../lib/dom_writes"
import type { EntrustFilter } from "../lib/entrust"
import type { FiltersView } from "../lib/entrust_view"

export default class EntrustFiltersController extends Controller<HTMLElement> {
  static targets = ["search", "rarity", "doubles", "count", "number", "clear"]

  declare readonly searchTarget: HTMLInputElement
  declare readonly rarityTargets: HTMLInputElement[]
  declare readonly doublesTarget: HTMLInputElement
  declare readonly countTarget: HTMLElement
  declare readonly numberTarget: HTMLElement
  declare readonly clearTarget: HTMLElement

  render({ filter, count, filtering }: FiltersView): void {
    if (this.searchTarget.value !== filter.query) this.searchTarget.value = filter.query
    for (const box of this.rarityTargets) box.checked = filter.rarities.includes(box.value as Rarity)
    this.doublesTarget.checked = filter.doubles
    this.countTarget.hidden = count === 0
    writeText(this.numberTarget, String(count))
    this.clearTarget.hidden = !filtering
  }

  focusSearch(): void {
    this.searchTarget.focus()
  }

  filter(): void {
    const filter: EntrustFilter = {
      query: this.searchTarget.value,
      rarities: this.rarityTargets.filter((box) => box.checked).map((box) => box.value as Rarity),
      doubles: this.doublesTarget.checked,
    }
    this.dispatch("change", { detail: filter })
  }

  // Enter in the search field filters; it must not submit the form.
  hold(event: Event): void {
    event.preventDefault()
  }

  clear(): void {
    this.dispatch("clear")
  }
}
