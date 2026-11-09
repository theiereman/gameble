import { Controller } from "@hotwired/stimulus"
import { Debounce } from "../lib/set_search"

const PREVIEW_PAUSE_MS = 400

export default class extends Controller<HTMLFormElement> {
  static targets = ["previewButton"]

  declare readonly previewButtonTarget: HTMLButtonElement

  private readonly debounce = new Debounce(PREVIEW_PAUSE_MS)

  disconnect(): void {
    this.debounce.cancel()
  }

  changed(): void {
    this.debounce.call(() => this.element.requestSubmit(this.previewButtonTarget))
  }

  submitted(event: SubmitEvent): void {
    if (event.submitter !== this.previewButtonTarget) this.debounce.cancel()
  }
}
