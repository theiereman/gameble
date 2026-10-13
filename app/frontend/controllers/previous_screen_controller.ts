import { Controller } from "@hotwired/stimulus"
import { currentIndex, currentScreenLabel, previousScreen, readTrail, sessionTrailStorage, type PreviousScreen } from "../lib/history_trail"

export default class extends Controller<HTMLAnchorElement> {
  static targets = ["label"]

  declare readonly labelTarget: HTMLElement

  connect(): void {
    this.sync()
  }

  sync(): void {
    const screen = this.previousScreen()
    if (!screen) {
      this.element.hidden = true
      this.element.removeAttribute("href")
      return
    }
    this.labelTarget.textContent = screen.label
    this.element.setAttribute("href", screen.pathname)
    this.element.hidden = false
  }

  back(event: MouseEvent): void {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const screen = this.previousScreen()
    if (!screen) return
    event.preventDefault()
    history.go(-screen.steps)
  }

  private previousScreen(): PreviousScreen | null {
    return previousScreen(readTrail(sessionTrailStorage()), currentIndex(), currentScreenLabel())
  }
}
