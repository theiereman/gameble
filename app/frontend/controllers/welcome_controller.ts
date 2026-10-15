import { Controller } from "@hotwired/stimulus"

// The hub's welcome panel. Once its close is answered, the panel goes away
// with the button that had the focus, so the hub's heading (`heading`, an
// element id) takes it.
export default class extends Controller<HTMLElement> {
  static values = { heading: String }

  declare readonly headingValue: string

  // turbo:submit-end from the panel's close form.
  closed(event: CustomEvent<{ success: boolean }>): void {
    if (!event.detail.success) return

    document.getElementById(this.headingValue)?.focus()
  }
}
