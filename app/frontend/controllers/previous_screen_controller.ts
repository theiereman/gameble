import { Controller } from "@hotwired/stimulus"
import { currentIndex, entryBefore, labelBefore, sessionTrailStorage } from "../lib/history_trail"

export default class extends Controller<HTMLAnchorElement> {
  static targets = ["label"]

  declare readonly labelTarget: HTMLElement

  connect(): void {
    this.sync()
  }

  sync(): void {
    const storage = sessionTrailStorage()
    const index = currentIndex()
    const label = labelBefore(index, storage)
    const pathname = entryBefore(index, storage)
    if (!label || !pathname) {
      this.element.hidden = true
      this.element.removeAttribute("href")
      return
    }
    this.labelTarget.textContent = label
    this.element.setAttribute("href", pathname)
    this.element.hidden = false
  }

  back(event: MouseEvent): void {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    history.back()
  }
}
