import { Controller } from "@hotwired/stimulus"
import { takeOpener } from "../lib/dialog"

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

  private showSentOpenAsModal(): void {
    if (!this.element.open || this.element.matches(":modal")) return
    this.element.close()
    this.element.showModal()
  }

  close(): void {
    if (this.element.open) this.element.close()
  }

  closeOnScrim(event: MouseEvent): void {
    if (event.target === this.element) this.close()
  }
}
