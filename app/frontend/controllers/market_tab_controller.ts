import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"
import { motionReduced } from "../lib/motion"

// Not data-turbo-action: Hotwire Native turns a frame visit with an action into a new native screen.
export default class extends Controller<HTMLElement> {
  static targets = ["screen", "chips"]

  declare readonly screenTarget: HTMLElement
  declare readonly chipsTarget: HTMLElement
  declare readonly hasChipsTarget: boolean

  private revealing = false

  chipsTargetConnected(chips: HTMLElement): void {
    const current = chips.querySelector<HTMLElement>(".tabs__tab--current")
    if (current) this.clearEdges(chips, current)
  }

  showChip(event: FocusEvent): void {
    this.clearEdges(this.chipsTarget, event.target as HTMLElement)
  }

  arrive(): void {
    const source = this.element.getAttribute("src")
    if (source) this.takeAddress(new URL(source, document.baseURI))
    const title = this.screenTarget.dataset.title
    if (title) document.title = title
    if (this.revealing) this.revealTab()
  }

  reveal(event: MouseEvent): void {
    const link = event.currentTarget as HTMLAnchorElement
    if (new URL(link.href).pathname === window.location.pathname) {
      event.preventDefault()
      this.revealTab()
    } else {
      this.revealing = true
    }
  }

  private revealTab(): void {
    this.revealing = false
    if (!this.hasChipsTarget) return
    this.chipsTarget.scrollIntoView({ behavior: motionReduced() ? "auto" : "smooth", block: "start" })
  }

  // Browsers leave a partly visible chip where it is on focus, half under the row's fade.
  private clearEdges(chips: HTMLElement, chip: HTMLElement): void {
    const clearance = parseFloat(getComputedStyle(chip).scrollMarginInlineEnd) || 0
    const row = chips.getBoundingClientRect()
    const box = chip.getBoundingClientRect()
    chips.scrollLeft += Math.max(0, box.right + clearance - row.right) - Math.max(0, row.left - box.left)
  }

  private takeAddress(location: URL): void {
    const { history, view } = window.Turbo.session
    history.replace(location, history.restorationIdentifier)
    view.lastRenderedLocation = location
  }
}
