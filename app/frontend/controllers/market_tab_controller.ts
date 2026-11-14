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

  private takeAddress(location: URL): void {
    const { history, view } = window.Turbo.session
    history.replace(location, history.restorationIdentifier)
    view.lastRenderedLocation = location
  }
}
