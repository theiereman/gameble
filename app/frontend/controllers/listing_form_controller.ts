import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import {
  back,
  choose,
  layoutAsked,
  refusal,
  setBuyNow,
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
import type ListingFieldsController from "./listing_fields_controller"
import type ListingGridController from "./listing_grid_controller"
import type ListingSummaryController from "./listing_summary_controller"

function editionFrom(cell: HTMLElement): Edition {
  const data = cell.dataset
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
  static targets = ["cell", "start", "buyNow", "duration", "step"]
  static values = { locale: String, basisPoints: Number, open: Boolean, strings: Object }
  static outlets = ["listing-grid", "listing-fields", "listing-summary"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly startTarget: HTMLInputElement
  declare readonly buyNowTarget: HTMLInputElement
  declare readonly durationTargets: HTMLInputElement[]
  declare readonly hasStepTarget: boolean
  declare readonly stepTarget: HTMLElement
  declare readonly localeValue: string
  declare readonly basisPointsValue: number
  declare readonly openValue: boolean
  declare readonly stringsValue: ListingStrings
  declare readonly hasListingGridOutlet: boolean
  declare readonly listingGridOutlet: ListingGridController
  declare readonly hasListingFieldsOutlet: boolean
  declare readonly listingFieldsOutlet: ListingFieldsController
  declare readonly hasListingSummaryOutlet: boolean
  declare readonly listingSummaryOutlet: ListingSummaryController

  private state?: ListingState
  private media?: MediaQueryList

  connect(): void {
    this.state = this.startFromMarkup()
    this.watchLayout()
    this.render()
  }

  disconnect(): void {
    this.media?.removeEventListener("change", this.layoutChanged)
    this.media = undefined
    this.state = undefined
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

  typed({ detail: { field, value } }: Intent<{ field: Field; value: string }>): void {
    if (!this.state) return
    this.apply(field === "start" ? setStart(this.state, value) : setBuyNow(this.state, value))
  }

  duration({ detail: { hours } }: Intent<{ hours: string }>): void {
    if (this.state) this.apply(setDuration(this.state, hours))
  }

  // Enter moves to the next field and never submits.
  entered({ detail: { field } }: Intent<{ field: Field | "duration" }>): void {
    if (field === "start") this.fields()?.focusBuyNow()
    else if (field === "buyNow") this.fields()?.focusDuration()
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

  private startFromMarkup(): ListingState {
    const editions = this.cellTargets.map(editionFrom)
    const chosen = this.cellTargets.find((cell) => cell.getAttribute("aria-selected") === "true")?.dataset.ref ?? null
    const duration = this.durationTargets.find((radio) => radio.checked)?.value ?? ""
    const typed = { start: this.startTarget.value, buyNow: this.buyNowTarget.value, duration }
    return start(editions, this.basisPointsValue, typed, chosen, "wide")
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
    this.grid()?.render(gridViewOf(state))
    this.fields()?.render(fieldsViewOf(state, forms))
    this.summary()?.render(summaryViewOf(state, forms, this.openValue))
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
