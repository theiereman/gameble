import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { heading: String }

  declare readonly headingValue: string

  closed(event: CustomEvent<{ success: boolean }>): void {
    if (!event.detail.success) return

    document.getElementById(this.headingValue)?.focus()
  }
}
