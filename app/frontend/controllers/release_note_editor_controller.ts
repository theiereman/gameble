import { Controller } from "@hotwired/stimulus"
import { Debounce } from "../lib/set_search"

const PREVIEW_PAUSE_MS = 400

export default class extends Controller<HTMLFormElement> {
  static targets = ["previewButton", "titleFr", "bodyFr"]

  declare readonly previewButtonTarget: HTMLButtonElement
  declare readonly titleFrTarget: HTMLInputElement
  declare readonly bodyFrTarget: HTMLTextAreaElement

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

  apply({ params }: { params: { title?: unknown; body?: unknown } }): void {
    this.titleFrTarget.value = String(params.title ?? "")
    this.bodyFrTarget.value = String(params.body ?? "")
    this.bodyFrTarget.focus()
    this.changed()
  }
}
