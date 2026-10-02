import { Controller } from "@hotwired/stimulus"

// The attic is wider than a phone screen: it pans sideways inside its frame
// and opens centred on the chest (EXPERIENCE.md, Responsive & Platform).
export default class extends Controller<HTMLElement> {
  static targets = ["chest"]

  declare readonly chestTarget: HTMLElement

  connect(): void {
    const frame = this.element
    // Only a frame that scrolls is a tab stop, so keyboard users can pan it.
    if (frame.scrollWidth <= frame.clientWidth) {
      frame.removeAttribute("tabindex")
      return
    }
    frame.tabIndex = 0

    const frameBox = frame.getBoundingClientRect()
    const chestBox = this.chestTarget.getBoundingClientRect()
    const chestCentre = chestBox.left - frameBox.left - frame.clientLeft + frame.scrollLeft + chestBox.width / 2
    frame.scrollLeft = Math.round(chestCentre - frame.clientWidth / 2)
  }
}
