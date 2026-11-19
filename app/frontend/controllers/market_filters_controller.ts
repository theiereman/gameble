import { Controller } from "@hotwired/stimulus"
import { PRICE_BOUNDS, reloadOnChange, reloadsSets, SET_OPTIONS_FRAME, submitToFrame } from "../lib/collection_filters"
import { Debounce, summaryOf } from "../lib/set_search"

export default class MarketFiltersController extends Controller<HTMLFormElement> {
  static targets = ["setQuery", "setStatus"]

  declare readonly setQueryTarget: HTMLInputElement
  declare readonly hasSetQueryTarget: boolean
  declare readonly setStatusTarget: HTMLElement
  declare readonly hasSetStatusTarget: boolean

  private readonly setsTyping = new Debounce()
  // A bound changes as its field loses focus, often to the Apply button, whose own submit then cancels this one.
  private readonly boundChange = new Debounce()

  disconnect(): void {
    this.setsTyping.cancel()
    this.boundChange.cancel()
  }

  changed(event: Event): void {
    if (!(event.target instanceof HTMLInputElement)) return
    const reload = reloadOnChange(event.target)
    if (reload === "grid" && PRICE_BOUNDS.includes(event.target.name))
      this.boundChange.call(() => this.element.requestSubmit())
    else if (reload === "grid") this.element.requestSubmit()
    if (reload === "sets") this.submitSets()
  }

  submitted(event: SubmitEvent): void {
    if (!reloadsSets(event.submitter)) this.boundChange.cancel()
  }

  typed(event: Event): void {
    if ((event as InputEvent).isComposing) return
    if (this.hasSetQueryTarget && event.target === this.setQueryTarget) this.setsTyping.call(() => this.submitSets())
  }

  setKeydown(event: KeyboardEvent): void {
    if (event.key !== "Enter" || event.isComposing) return
    event.preventDefault()
    this.submitSets()
  }

  setsLoaded(event: Event): void {
    const frame = event.target
    if (!(frame instanceof HTMLElement) || frame.id !== SET_OPTIONS_FRAME || !this.hasSetStatusTarget) return

    this.setStatusTarget.textContent = summaryOf(frame.querySelector("[data-set-filter-summary]")?.textContent)
  }

  private submitSets(): void {
    this.setsTyping.cancel()
    submitToFrame(this.element, document.createElement("button"), SET_OPTIONS_FRAME)
  }
}
