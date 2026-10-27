import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  connect(): void {
    const currentChips = this.element.querySelectorAll<HTMLElement>("[aria-current]")
    const lastCurrentChip = currentChips[currentChips.length - 1]
    if (!lastCurrentChip) return

    const visibleRight =
      this.element.getBoundingClientRect().right - parseFloat(getComputedStyle(this.element).paddingRight)
    const overshoot = lastCurrentChip.getBoundingClientRect().right - visibleRight
    if (overshoot > 0) this.element.scrollLeft += overshoot
  }
}
