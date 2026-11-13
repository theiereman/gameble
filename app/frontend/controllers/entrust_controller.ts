import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import { writeData, writeValue } from "../lib/dom_writes"
import {
  bump,
  know,
  moveActive,
  selectAll,
  selecting,
  setCopies,
  start,
  toggle,
  type Copy,
  type EntrustState,
  type Layout,
} from "../lib/entrust"
import { PHONE_QUERY, layoutAsked, layoutFor, sheetShown } from "../lib/entrust_layout"
import { fetchMatches } from "../lib/entrust_matches"
import { gridViewOf, recapViewOf, selectionOf, ticksOf, type EntrustStrings, type TickView } from "../lib/entrust_view"
import type { Intent } from "../lib/screen"
import { cloneFirstElement } from "../lib/templates"
import type CopyFiltersController from "./copy_filters_controller"
import type EntrustGridController from "./entrust_grid_controller"
import type { MoveIntent } from "./entrust_grid_controller"
import type EntrustRecapController from "./entrust_recap_controller"
import type EntrustResultController from "./entrust_result_controller"

function copyFrom(element: HTMLElement): Copy {
  const data = element.dataset
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

function describe(tick: HTMLElement, { copy, copies }: TickView): void {
  writeData(tick, "ref", copy.ref)
  writeData(tick, "title", copy.title)
  writeData(tick, "rarity", copy.rarity)
  writeData(tick, "season", String(copy.season))
  writeData(tick, "free", String(copy.free))
  writeData(tick, "owned", String(copy.owned))
  writeData(tick, "value", String(copy.value))
  writeData(tick, "copies", String(copies))
}

export default class EntrustController extends Controller<HTMLElement> {
  static targets = ["cell", "selection", "ticks", "tickTemplate"]
  static values = {
    locale: String,
    capLeft: Number,
    open: Boolean,
    dailyCap: Number,
    capBefore: Number,
    strings: Object,
  }
  static outlets = ["copy-filters", "entrust-grid", "entrust-recap", "entrust-result"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly hasSelectionTarget: boolean
  declare readonly selectionTarget: HTMLInputElement
  declare readonly hasTicksTarget: boolean
  declare readonly ticksTarget: HTMLElement
  declare readonly hasTickTemplateTarget: boolean
  declare readonly tickTemplateTarget: HTMLTemplateElement
  declare readonly localeValue: string
  declare readonly capLeftValue: number
  declare readonly openValue: boolean
  declare readonly dailyCapValue: number
  declare readonly capBeforeValue: number
  declare readonly hasCapBeforeValue: boolean
  declare readonly stringsValue: EntrustStrings
  declare readonly hasCopyFiltersOutlet: boolean
  declare readonly copyFiltersOutlet: CopyFiltersController
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
  private arrived: HTMLElement[] = []
  private cellsChanged = false

  // Esc here closes an overlay and nothing else: it never clears the ticks nor leaves the screen.
  private readonly guardEscape = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || !this.state || document.querySelector("dialog[open]")) return
    if (Object.keys(this.state.ticked).length === 0) return
    event.preventDefault()
    event.stopPropagation()
  }

  connect(): void {
    this.arrived = []
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

  // A page appended by the infinite scroll or a grid reloaded by the filters: the cells are read once they all landed.
  cellTargetConnected(cell: HTMLElement): void {
    this.arrived.push(cell)
    this.noteCells()
  }

  cellTargetDisconnected(): void {
    this.noteCells()
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

  clear(): void {
    this.filters()?.clear()
  }

  async selectAll({ detail: { url } }: Intent<{ url: string }>): Promise<void> {
    if (!this.state || this.state.selecting === "loading") return
    this.apply(selecting(this.state, "loading"))
    const copies = await fetchMatches(url)
    if (!this.state) return
    this.apply(copies ? selectAll(this.state, copies) : selecting(this.state, "failed"))
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

  private noteCells(): void {
    if (this.cellsChanged) return
    this.cellsChanged = true
    queueMicrotask(() => {
      this.cellsChanged = false
      const arrived = this.arrived.filter((cell) => cell.isConnected).map(copyFrom)
      this.arrived = []
      if (this.state)
        this.apply(
          know(
            this.state,
            arrived,
            this.cellTargets.map((cell) => cell.dataset.ref ?? ""),
          ),
        )
    })
  }

  private tickNodes(): HTMLElement[] {
    return this.hasTicksTarget ? Array.from(this.ticksTarget.querySelectorAll<HTMLElement>("[data-ref]")) : []
  }

  private startFromMarkup(): EntrustState {
    const cells = this.cellTargets
    const ticks = this.tickNodes()
    const ticked = Object.fromEntries(ticks.map((tick) => [tick.dataset.ref ?? "", Number(tick.dataset.copies)]))
    const copies = [...ticks, ...cells].map(copyFrom)
    return start(
      copies,
      this.capLeftValue,
      ticked,
      cells.map((cell) => cell.dataset.ref ?? ""),
    )
  }

  // Every tick, wherever its cell is (on a page not loaded or hidden by a filter): posted in one field,
  // and kept beside it with what the recap needs, for a page restored from the cache.
  private renderTicks(ticks: readonly TickView[]): void {
    if (this.hasSelectionTarget) writeValue(this.selectionTarget, selectionOf(ticks))
    if (!this.hasTicksTarget || !this.hasTickTemplateTarget) return
    const wanted = new Map(ticks.map((tick) => [tick.copy.ref, tick]))
    const present = new Map<string, HTMLElement>()
    for (const node of this.tickNodes()) {
      const ref = node.dataset.ref ?? ""
      if (wanted.has(ref) && !present.has(ref)) present.set(ref, node)
      else node.remove()
    }
    for (const tick of ticks) {
      let node = present.get(tick.copy.ref)
      if (!node) {
        node = cloneFirstElement<HTMLElement>(this.tickTemplateTarget) ?? undefined
        if (!node) continue
        this.ticksTarget.append(node)
      }
      describe(node, tick)
    }
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
    this.renderTicks(ticksOf(state))
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

  private filters(): CopyFiltersController | null {
    return this.hasCopyFiltersOutlet ? this.copyFiltersOutlet : null
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
