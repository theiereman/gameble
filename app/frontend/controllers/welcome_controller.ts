import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLDialogElement> {
  static values = { heading: String }

  declare readonly headingValue: string

  private readonly beforeCache = (): void => {
    this.element.remove()
  }

  connect(): void {
    document.addEventListener("turbo:before-cache", this.beforeCache)
    if (!this.element.open) this.element.showModal()
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  close(): void {
    if (this.element.open) this.element.close()
  }

  closeOnScrim(event: MouseEvent): void {
    if (event.target === this.element) this.close()
  }

  closed(): void {
    this.element.remove()
    document.getElementById(this.headingValue)?.focus()
  }

  submitted(event: CustomEvent<{ success: boolean }>): void {
    if (event.detail.success) this.close()
  }
}
