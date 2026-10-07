import { Controller } from "@hotwired/stimulus"

// The collection's search and FILTRES zone (EXPERIENCE.md, Filter zone and
// Search): one GET form whose result Turbo loads into the frame that holds
// the grid. The form itself is never replaced, so the field and the chip
// keep focus. A chip switched on or off submits at once; typing in the
// search submits after a short pause. The count of active filters and the
// "clear all" link follow the chips without a round trip. Without
// JavaScript the form still works with its "apply" button.
const TYPING_PAUSE_MS = 250

export default class extends Controller<HTMLFormElement> {
  static targets = ["search", "count", "number", "group", "clear"]

  declare readonly searchTarget: HTMLInputElement
  declare readonly countTarget: HTMLElement
  declare readonly numberTarget: HTMLElement
  declare readonly clearTarget: HTMLElement
  declare readonly groupTargets: HTMLElement[]
  declare readonly hasSearchTarget: boolean

  private timer: number | undefined

  disconnect(): void {
    window.clearTimeout(this.timer)
  }

  // A chip was switched. The state group never stays empty: with every
  // state off, the owned cards come back, as when the page opens.
  changed(event: Event): void {
    const box = event.target as HTMLInputElement
    if (box.type !== "checkbox") return
    const state = this.groupTargets.find((group) => group.dataset.group === "state")
    if (state && state.contains(box)) {
      const boxes = this.boxes(state)
      if (!boxes.some((b) => b.checked)) {
        const owned = boxes.find((b) => b.value === "owned")
        if (owned) owned.checked = true
      }
    }
    this.refresh()
    this.submit()
  }

  typed(event: Event): void {
    if (!this.hasSearchTarget || event.target !== this.searchTarget) return
    this.refresh()
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.submit(), TYPING_PAUSE_MS)
  }

  submitted(): void {
    window.clearTimeout(this.timer)
  }

  private submit(): void {
    window.clearTimeout(this.timer)
    this.element.requestSubmit()
  }

  private boxes(group: HTMLElement): HTMLInputElement[] {
    return Array.from(group.querySelectorAll<HTMLInputElement>('input[type="checkbox"]'))
  }

  // The count shown: the chips on outside the state group, plus the state
  // chips when they differ from the default the page opens on.
  private refresh(): void {
    let count = 0
    for (const group of this.groupTargets) {
      const checked = this.boxes(group).filter((b) => b.checked).map((b) => b.value)
      if (group.dataset.group === "state") {
        const fallback = group.dataset.default ?? "owned"
        if (!(checked.length === 1 && checked[0] === fallback)) count += checked.length
      } else {
        count += checked.length
      }
    }
    this.numberTarget.textContent = String(count)
    this.countTarget.hidden = count === 0
    const searching = this.hasSearchTarget && this.searchTarget.value.trim() !== ""
    this.clearTarget.hidden = count === 0 && !searching
  }
}
