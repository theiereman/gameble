import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["status"]

  declare readonly statusTarget: HTMLElement

  tabChanged(): void {
    this.element.querySelector<HTMLElement>('[aria-pressed="true"]')?.focus()
    this.statusTarget.textContent =
      this.element.querySelector("[data-fortune-gauge-summary]")?.textContent ?? ""
  }
}
