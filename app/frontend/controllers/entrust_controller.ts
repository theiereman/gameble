import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import {
  bump,
  clearFilters,
  moveActive,
  setCopies,
  setFilter,
  start,
  toggle,
  type Copy,
  type EntrustFilter,
  type EntrustState,
} from "../lib/entrust"
import { filtersViewOf, gridViewOf, recapViewOf, type EntrustStrings } from "../lib/entrust_view"
import type { Intent } from "../lib/screen"
import type EntrustFiltersController from "./entrust_filters_controller"
import type EntrustGridController from "./entrust_grid_controller"
import type { MoveIntent } from "./entrust_grid_controller"
import type EntrustRecapController from "./entrust_recap_controller"

function copyFrom(cell: HTMLElement): Copy {
  const data = cell.dataset
  return {
    ref: data.ref ?? "",
    title: data.title ?? "",
    rarity: (data.rarity ?? "common") as Rarity,
    season: Number(data.season),
    free: Number(data.free),
    owned: Number(data.owned),
    value: Number(data.value),
  }
}

export default class EntrustController extends Controller<HTMLElement> {
  static targets = ["cell"]
  static values = { locale: String, capLeft: Number, open: Boolean, strings: Object }
  static outlets = ["entrust-filters", "entrust-grid", "entrust-recap"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly localeValue: string
  declare readonly capLeftValue: number
  declare readonly openValue: boolean
  declare readonly stringsValue: EntrustStrings
  declare readonly hasEntrustFiltersOutlet: boolean
  declare readonly entrustFiltersOutlet: EntrustFiltersController
  declare readonly hasEntrustGridOutlet: boolean
  declare readonly entrustGridOutlet: EntrustGridController
  declare readonly hasEntrustRecapOutlet: boolean
  declare readonly entrustRecapOutlet: EntrustRecapController

  private state?: EntrustState

  // Esc here closes an overlay and nothing else: it never clears the ticks nor leaves the screen.
  private readonly guardEscape = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || !this.state || document.querySelector("dialog[open]")) return
    if (Object.keys(this.state.ticked).length > 0) event.stopPropagation()
  }

  connect(): void {
    this.state = this.startFromMarkup()
    document.addEventListener("keydown", this.guardEscape, true)
    this.render()
  }

  disconnect(): void {
    document.removeEventListener("keydown", this.guardEscape, true)
    this.state = undefined
  }

  entrustFiltersOutletConnected(): void {
    this.render()
  }

  entrustGridOutletConnected(): void {
    this.render()
  }

  entrustRecapOutletConnected(): void {
    this.render()
  }

  filter({ detail }: Intent<EntrustFilter>): void {
    if (this.state) this.apply(setFilter(this.state, detail))
  }

  clear(): void {
    if (this.state) this.apply(clearFilters(this.state), () => this.filters()?.focusSearch())
  }

  toggle({ detail: { ref } }: Intent<{ ref: string }>): void {
    if (this.state) this.apply(toggle(this.state, ref))
  }

  copies({ detail: { ref, copies } }: Intent<{ ref: string; copies: number }>): void {
    if (this.state) this.apply(setCopies(this.state, ref, copies))
  }

  bump({ detail: { ref, step } }: Intent<{ ref: string; step: number }>): void {
    if (this.state) this.apply(bump(this.state, ref, step))
  }

  move(event: Intent<MoveIntent>): void {
    if (!this.state) return
    const next = moveActive(this.state, event.detail.key, event.detail.columns)
    if (next === this.state) return
    event.preventDefault()
    this.apply(next, () => this.grid()?.focusActive())
  }

  private apply(next: EntrustState, then?: () => void): void {
    if (next === this.state) return
    this.state = next
    this.render()
    then?.()
  }

  private startFromMarkup(): EntrustState {
    const copies = this.cellTargets.map(copyFrom)
    const ticked = Object.fromEntries(
      this.cellTargets.map((cell) => [cell.dataset.ref ?? "", Number(cell.dataset.ticked ?? 0)]),
    )
    return start(copies, this.capLeftValue, ticked)
  }

  private render(): void {
    const state = this.state
    if (!state) return
    const strings = this.stringsValue
    this.element.toggleAttribute("data-pending-edit", Object.keys(state.ticked).length > 0)
    this.filters()?.render(filtersViewOf(state))
    this.grid()?.render(gridViewOf(state, strings))
    this.recap()?.render(
      recapViewOf(state, strings, {
        open: this.openValue,
        locale: this.localeValue,
        accessible: strings.amount,
      }),
    )
  }

  private filters(): EntrustFiltersController | null {
    return this.hasEntrustFiltersOutlet ? this.entrustFiltersOutlet : null
  }

  private grid(): EntrustGridController | null {
    return this.hasEntrustGridOutlet ? this.entrustGridOutlet : null
  }

  private recap(): EntrustRecapController | null {
    return this.hasEntrustRecapOutlet ? this.entrustRecapOutlet : null
  }
}
