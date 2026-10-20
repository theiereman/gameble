import { Controller } from "@hotwired/stimulus"
import { takeOpener } from "../lib/dialog"

// A modal <dialog> (EXPERIENCE.md, Modal): its "✕"
// closes it, as do Esc (the browser's own cancel) and a click on the scrim
// (a click whose target is the dialog itself, outside its panel). Once
// closed, the focus goes back to the button that opened it. It closes
// before Turbo caches the page, so a restored page never shows it open, and
// when it leaves the page.
export default class extends Controller<HTMLDialogElement> {
  private readonly closed = (): void => {
    const opener = takeOpener(this.element)
    if (opener?.isConnected) opener.focus()
  }

  private readonly beforeCache = (): void => {
    this.close()
  }

  connect(): void {
    this.element.addEventListener("close", this.closed)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.showSentOpenAsModal()
  }

  disconnect(): void {
    this.element.removeEventListener("close", this.closed)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    if (this.element.open) this.element.close()
    takeOpener(this.element)
  }

  // The `open` attribute shows a dialog non-modal: no scrim, no focus trap.
  private showSentOpenAsModal(): void {
    if (!this.element.open || this.element.matches(":modal")) return
    this.element.close()
    this.element.showModal()
  }

  close(): void {
    if (this.element.open) this.element.close()
  }

  // The panel fills the dialog: a click landing on the dialog element itself
  // is on its backdrop.
  closeOnScrim(event: MouseEvent): void {
    if (event.target === this.element) this.close()
  }
}
