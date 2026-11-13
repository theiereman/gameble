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
  type Layout,
} from "../lib/entrust"
import { PHONE_QUERY, layoutAsked, layoutFor, sheetShown } from "../lib/entrust_layout"
import { filtersViewOf, gridViewOf, recapViewOf, type EntrustStrings } from "../lib/entrust_view"
import type { Intent } from "../lib/screen"
import type EntrustFiltersController from "./entrust_filters_controller"
import type EntrustGridController from "./entrust_grid_controller"
import type { MoveIntent } from "./entrust_grid_controller"
import type EntrustRecapController from "./entrust_recap_controller"
import type EntrustResultController from "./entrust_result_controller"

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
  static values = {
    locale: String,
    capLeft: Number,
    open: Boolean,
    doubles: { type: Boolean, default: true },
    query: String,
    rarities: Array,
    dailyCap: Number,
    capBefore: Number,
    strings: Object,
  }
  static outlets = ["entrust-filters", "entrust-grid", "entrust-recap", "entrust-result"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly localeValue: string
  declare readonly capLeftValue: number
  declare readonly openValue: boolean
  declare readonly doublesValue: boolean
  declare readonly queryValue: string
  declare readonly raritiesValue: Rarity[]
  declare readonly dailyCapValue: number
  declare readonly capBeforeValue: number
  declare readonly hasCapBeforeValue: boolean
  declare readonly stringsValue: EntrustStrings
  declare readonly hasEntrustFiltersOutlet: boolean
  declare readonly entrustFiltersOutlet: EntrustFiltersController
  declare readonly hasEntrustGridOutlet: boolean
  declare readonly entrustGridOutlet: EntrustGridController
  declare readonly hasEntrustRecapOutlet: boolean
  declare readonly entrustRecapOutlet: EntrustRecapController
  declare readonly hasEntrustResultOutlet: boolean
  declare readonly entrustResultOutlet: EntrustResultController

  private state?: EntrustState
  private media?: MediaQueryList
  private placed: Layout = "wide"
  private placedKnown = false
  private arrival?: number

  // Esc here closes an overlay and nothing else: it never clears the ticks nor leaves the screen.
  private readonly guardEscape = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || !this.state || document.querySelector("dialog[open]")) return
    if (Object.keys(this.state.ticked).length === 0) return
    event.preventDefault()
    event.stopPropagation()
  }

  connect(): void {
    this.state = this.startFromMarkup()
    this.arrival = this.hasCapBeforeValue ? Math.max(this.dailyCapValue - this.capBeforeValue, 0) : undefined
    document.addEventListener("keydown", this.guardEscape, true)
    this.watchLayout()
    this.render()
  }

  disconnect(): void {
    document.removeEventListener("keydown", this.guardEscape, true)
    this.media?.removeEventListener("change", this.layoutChanged)
    this.media = undefined
    this.placedKnown = false
    this.arrival = undefined
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

  entrustResultOutletConnected(): void {
    this.render()
  }

  resultClosed(): void {
    this.grid()?.focusActive()
  }

  sheetShown(): void {
    const recap = this.recap()
    if (!this.state || !recap) return
    this.apply(sheetShown(this.state, recap.sheetIsOpen()))
    recap.refreshStatus()
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

  private readonly layoutChanged = (): void => {
    if (this.state && this.media) this.apply(layoutAsked(this.state, layoutFor(this.media.matches)))
  }

  private watchLayout(): void {
    if (typeof window.matchMedia !== "function" || !this.state) return
    this.media = window.matchMedia(PHONE_QUERY)
    this.media.addEventListener("change", this.layoutChanged)
    this.state = layoutAsked(this.state, layoutFor(this.media.matches))
  }

  // The recap moves only when the applied layout changes; a first look at the real DOM covers a restored page.
  private placeRecap(layout: Layout): void {
    const recap = this.recap()
    if (!recap) return
    if (!this.placedKnown) {
      this.placed = recap.placedIn() === "sheet" ? "phone" : "wide"
      this.placedKnown = true
    }
    if (layout === this.placed) return
    recap.place(layout)
    this.placed = layout
  }

  private startFromMarkup(): EntrustState {
    const copies = this.cellTargets.map(copyFrom)
    const ticked = Object.fromEntries(
      this.cellTargets.map((cell) => [cell.dataset.ref ?? "", Number(cell.dataset.ticked ?? 0)]),
    )
    const filter = { query: this.queryValue, rarities: this.raritiesValue, doubles: this.doublesValue }
    return start(copies, this.capLeftValue, ticked, filter)
  }

  private render(): void {
    const state = this.state
    if (!state) return
    const strings = this.stringsValue
    const picking = Object.keys(state.ticked).length > 0
    this.element.toggleAttribute("data-pending-edit", picking)
    if (picking) this.result()?.dismiss()
    this.element.dataset.layout = state.layout
    this.placeRecap(state.layout)
    this.filters()?.render(filtersViewOf(state))
    this.grid()?.render(gridViewOf(state, strings))
    this.recap()?.render(
      recapViewOf(state, strings, {
        open: this.openValue,
        dailyCap: this.dailyCapValue,
        locale: this.localeValue,
        accessible: strings.amount,
      }),
    )
    this.playArrival()
  }

  private playArrival(): void {
    const recap = this.recap()
    if (this.arrival === undefined || !recap) return
    recap.growFrom(this.arrival)
    this.arrival = undefined
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

  private result(): EntrustResultController | null {
    return this.hasEntrustResultOutlet ? this.entrustResultOutlet : null
  }
}
