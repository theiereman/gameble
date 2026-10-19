import { Controller } from "@hotwired/stimulus"
import { clearsOnEscape, Debounce, summaryOf } from "../lib/set_search"

export default class extends Controller<HTMLElement> {
  static targets = ["form", "field", "status"]
  static values = { frame: String }

  declare readonly formTarget: HTMLFormElement
  declare readonly fieldTarget: HTMLInputElement
  declare readonly statusTarget: HTMLElement
  declare readonly frameValue: string

  private readonly debounce = new Debounce()

  disconnect(): void {
    this.debounce.cancel()
  }

  typed(event: Event): void {
    if (event.target !== this.fieldTarget) return
    // A composition (IME) is not text yet: wait for compositionend.
    if ((event as InputEvent).isComposing) return
    this.debounce.call(() => this.formTarget.requestSubmit())
  }

  escape(event: KeyboardEvent): void {
    if (event.target !== this.fieldTarget || event.isComposing) return
    if (!clearsOnEscape(event.key, this.fieldTarget.value)) return

    event.preventDefault()
    event.stopPropagation()
    this.fieldTarget.value = ""
    this.debounce.cancel()
    this.formTarget.requestSubmit()
  }

  submitted(): void {
    this.debounce.cancel()
  }

  loaded(event: Event): void {
    const frame = event.target
    if (!(frame instanceof HTMLElement) || frame.id !== this.frameValue) return

    this.statusTarget.textContent = summaryOf(frame.querySelector("[data-set-search-summary]")?.textContent)
  }
}
