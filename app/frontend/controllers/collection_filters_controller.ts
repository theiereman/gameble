import { Controller } from "@hotwired/stimulus"
import { reloadOnChange, reloadsSets, SET_OPTIONS_FRAME, submitToFrame } from "../lib/collection_filters"
import { Debounce, summaryOf } from "../lib/set_search"

const TYPING_PAUSE_MS = 250
const ALL_STATE = "all"

export default class extends Controller<HTMLFormElement> {
  static targets = ["search", "count", "number", "group", "clear", "setQuery", "setStatus"]

  declare readonly searchTarget: HTMLInputElement
  declare readonly countTarget: HTMLElement
  declare readonly numberTarget: HTMLElement
  declare readonly clearTarget: HTMLElement
  declare readonly groupTargets: HTMLElement[]
  declare readonly hasSearchTarget: boolean
  declare readonly setQueryTarget: HTMLInputElement
  declare readonly hasSetQueryTarget: boolean
  declare readonly setStatusTarget: HTMLElement
  declare readonly hasSetStatusTarget: boolean

  private timer: number | undefined
  private readonly setsTyping = new Debounce(TYPING_PAUSE_MS)

  disconnect(): void {
    window.clearTimeout(this.timer)
    this.setsTyping.cancel()
  }

  changed(event: Event): void {
    const field = event.target as HTMLInputElement
    const reload = reloadOnChange(field)
    if (reload === "sets") this.submitSets()
    if (reload !== "grid") return
    this.setsTyping.cancel()

    const state = this.groupTargets.find((group) => group.dataset.group === "state")
    if (state && state.contains(field)) {
      const boxes = this.boxes(state)
      if (field.checked) {
        const everything = field.value === ALL_STATE
        for (const other of boxes)
          if (other !== field && (other.value === ALL_STATE) !== everything) other.checked = false
      }
      if (!boxes.some((b) => b.checked)) {
        const fallback = boxes.find((b) => b.value === (state.dataset.default ?? ALL_STATE))
        if (fallback) fallback.checked = true
      }
    }
    this.refresh()
    this.submit()
  }

  typed(event: Event): void {
    if ((event as InputEvent).isComposing) return
    if (this.hasSetQueryTarget && event.target === this.setQueryTarget) {
      this.setsTyping.call(() => this.submitSets())
      return
    }
    if (!this.hasSearchTarget || event.target !== this.searchTarget) return
    this.refresh()
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.submit(), TYPING_PAUSE_MS)
  }

  setKeydown(event: KeyboardEvent): void {
    if (event.key !== "Enter" || event.isComposing) return
    event.preventDefault()
    this.submitSets()
  }

  submitted(event: SubmitEvent): void {
    if (reloadsSets(event.submitter)) this.setsTyping.cancel()
    else window.clearTimeout(this.timer)
  }

  setsLoaded(event: Event): void {
    const frame = event.target
    if (!(frame instanceof HTMLElement) || frame.id !== SET_OPTIONS_FRAME || !this.hasSetStatusTarget) return

    this.setStatusTarget.textContent = summaryOf(frame.querySelector("[data-set-filter-summary]")?.textContent)
  }

  private submit(): void {
    window.clearTimeout(this.timer)
    this.element.requestSubmit()
  }

  private submitSets(): void {
    this.setsTyping.cancel()
    submitToFrame(this.element, document.createElement("button"), SET_OPTIONS_FRAME)
  }

  private boxes(group: HTMLElement): HTMLInputElement[] {
    return Array.from(group.querySelectorAll<HTMLInputElement>('input[type="checkbox"]'))
  }

  private refresh(): void {
    let count = 0
    for (const group of this.groupTargets) {
      const checked = this.boxes(group)
        .filter((b) => b.checked)
        .map((b) => b.value)
      if (group.dataset.group === "state") {
        const fallback = group.dataset.default ?? ALL_STATE
        if (!(checked.length === 1 && checked[0] === fallback)) count += checked.length
      } else {
        count += checked.length
      }
    }
    this.numberTarget.textContent = String(count)
    this.countTarget.hidden = count === 0
    const searching = this.hasSearchTarget && this.searchTarget.value.trim() !== ""
    this.clearTarget.hidden = count === 0 && !searching
  }
}
