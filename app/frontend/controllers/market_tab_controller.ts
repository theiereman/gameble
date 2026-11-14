import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"

// Not data-turbo-action: Hotwire Native turns a frame visit with an action into a new native screen.
export default class extends Controller<HTMLElement> {
  static targets = ["screen"]

  declare readonly screenTarget: HTMLElement

  arrive(): void {
    const source = this.element.getAttribute("src")
    if (source) this.takeAddress(new URL(source, document.baseURI))
    const title = this.screenTarget.dataset.title
    if (title) document.title = title
  }

  private takeAddress(location: URL): void {
    const { history, view } = window.Turbo.session
    history.replace(location, history.restorationIdentifier)
    view.lastRenderedLocation = location
  }
}
