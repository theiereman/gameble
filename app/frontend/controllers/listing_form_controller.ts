import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import {
  back,
  choose,
  know,
  layoutAsked,
  refusal,
  setDuration,
  setStart,
  start,
  validate,
  type Edition,
  type Field,
  type ListingState,
} from "../lib/listing_form"
import { PHONE_QUERY, layoutFor } from "../lib/entrust_layout"
import {
  fieldsViewOf,
  gridViewOf,
  stepText,
  summaryViewOf,
  type Forms,
  type ListingStrings,
} from "../lib/listing_form_view"
import { writeText } from "../lib/dom_writes"
import type { Intent } from "../lib/screen"
import type CopyFiltersController from "./copy_filters_controller"
import type ListingFieldsController from "./listing_fields_controller"
import type ListingGridController from "./listing_grid_controller"
import type ListingSummaryController from "./listing_summary_controller"

function editionFrom(element: HTMLElement): Edition {
  const data = element.dataset
  return {
    ref: data.ref ?? "",
    title: data.title ?? "",
    rarity: (data.rarity ?? "common") as Rarity,
    rarityName: data.rarityName ?? "",
    season: Number(data.season),
    free: Number(data.free),
    minimum: Number(data.minimum),
    stamp: Number(data.stamp),
  }
}

export default class ListingFormController extends Controller<HTMLFormElement> {
  static targets = ["cell", "edition", "ref", "priceTemplate", "start", "duration", "step"]
  static values = { locale: String, basisPoints: Number, open: Boolean, available: Number, strings: Object }
  static outlets = ["copy-filters", "listing-grid", "listing-fields", "listing-summary"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly editionTargets: HTMLElement[]
  declare readonly hasRefTarget: boolean
  declare readonly refTarget: HTMLInputElement
  declare readonly priceTemplateTargets: HTMLTemplateElement[]
  declare readonly startTarget: HTMLInputElement
  declare readonly durationTargets: HTMLInputElement[]
  declare readonly hasStepTarget: boolean
  declare readonly stepTarget: HTMLElement
  declare readonly localeValue: string
  declare readonly basisPointsValue: number
  declare readonly openValue: boolean
  declare readonly availableValue: number
  declare readonly stringsValue: ListingStrings
  declare readonly hasCopyFiltersOutlet: boolean
  declare readonly copyFiltersOutlet: CopyFiltersController
  declare readonly hasListingGridOutlet: boolean
  declare readonly listingGridOutlet: ListingGridController
  declare readonly hasListingFieldsOutlet: boolean
  declare readonly listingFieldsOutlet: ListingFieldsController
  declare readonly hasListingSummaryOutlet: boolean
  declare readonly listingSummaryOutlet: ListingSummaryController

  private state?: ListingState
  private media?: MediaQueryList
  private arrived: HTMLElement[] = []
  private cellsChanged = false

  connect(): void {
    this.arrived = []
    this.state = this.startFromMarkup()
    this.watchLayout()
    this.render()
  }

  disconnect(): void {
    this.media?.removeEventListener("change", this.layoutChanged)
    this.media = undefined
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

  clear(): void {
    if (this.hasCopyFiltersOutlet) this.copyFiltersOutlet.clear()
  }

  listingGridOutletConnected(): void {
    this.render()
  }

  listingFieldsOutletConnected(): void {
    this.render()
  }

  listingSummaryOutletConnected(): void {
    this.render()
  }

  chosen({ detail: { ref } }: Intent<{ ref: string }>): void {
    if (!this.state) return
    const phone = this.state.layout === "phone"
    this.apply(choose(this.state, ref), () => (phone ? this.fields()?.focusField("start") : undefined))
  }

  typed({ detail: { value } }: Intent<{ field: Field; value: string }>): void {
    if (this.state) this.apply(setStart(this.state, value))
  }

  duration({ detail: { hours } }: Intent<{ hours: string }>): void {
    if (this.state) this.apply(setDuration(this.state, hours))
  }

  entered({ detail: { field } }: Intent<{ field: Field | "duration" }>): void {
    if (field === "start") this.fields()?.focusDuration()
    else this.summary()?.focusSubmit()
  }

  back(): void {
    if (this.state) this.apply(back(this.state), () => this.grid()?.focusChosen())
  }

  submit(event: Event): void {
    const state = this.state
    if (!state) return
    const problem = refusal(state)
    if (state.chosen === null || problem) event.preventDefault()
    if (problem) this.apply(validate(state), () => this.fields()?.focusField(problem.field))
  }

  private apply(next: ListingState, then?: () => void): void {
    if (next !== this.state) {
      this.state = next
      this.render()
    }
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

  private noteCells(): void {
    if (this.cellsChanged) return
    this.cellsChanged = true
    queueMicrotask(() => {
      this.cellsChanged = false
      const arrived = this.arrived.filter((cell) => cell.isConnected).map(editionFrom)
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

  private startFromMarkup(): ListingState {
    const cells = this.cellTargets
    const editions = [...this.editionTargets, ...cells].map(editionFrom)
    const chosen = this.hasRefTarget && this.refTarget.value !== "" ? this.refTarget.value : null
    const duration = this.durationTargets.find((radio) => radio.checked)?.value ?? ""
    const typed = { start: this.startTarget.value, duration }
    const loaded = cells.map((cell) => cell.dataset.ref ?? "")
    return start(editions, this.basisPointsValue, typed, chosen, "wide", loaded)
  }

  private forms(): Forms {
    return { locale: this.localeValue, strings: this.stringsValue }
  }

  private render(): void {
    const state = this.state
    if (!state) return
    const forms = this.forms()
    this.element.dataset.layout = state.layout
    this.element.dataset.step = String(state.step)
    this.element.dataset.chosen = String(state.chosen !== null)
    if (this.hasStepTarget) writeText(this.stepTarget, stepText(state, forms))
    if (this.hasRefTarget && this.refTarget.value !== (state.chosen ?? "")) this.refTarget.value = state.chosen ?? ""
    this.grid()?.render(gridViewOf(state))
    this.fields()?.render(fieldsViewOf(state, forms))
    this.fields()?.showPrice(state.chosen ?? "", this.priceTemplateFor(state.chosen))
    this.summary()?.render(summaryViewOf(state, forms, { open: this.openValue, available: this.availableValue }))
  }

  private priceTemplateFor(ref: string | null): HTMLTemplateElement | null {
    return ref === null ? null : (this.priceTemplateTargets.find((template) => template.dataset.ref === ref) ?? null)
  }

  private grid(): ListingGridController | null {
    return this.hasListingGridOutlet ? this.listingGridOutlet : null
  }

  private fields(): ListingFieldsController | null {
    return this.hasListingFieldsOutlet ? this.listingFieldsOutlet : null
  }

  private summary(): ListingSummaryController | null {
    return this.hasListingSummaryOutlet ? this.listingSummaryOutlet : null
  }
}
