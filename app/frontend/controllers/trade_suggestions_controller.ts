import { Controller } from "@hotwired/stimulus"
import { holdLiveRefresh } from "../lib/live_refresh_hold"
import { DRAFT_PREFIX } from "../lib/trade_board_draft"
import { draftedKeys, successorOf } from "../lib/trade_suggestion_drafts"

export default class extends Controller<HTMLElement> {
  static targets = ["row"]

  declare readonly rowTargets: HTMLElement[]

  private readonly focusEntered = (): void => holdLiveRefresh(this.element, true)

  private readonly focusLeft = (): void => {
    window.setTimeout(() => holdLiveRefresh(this.element, this.element.contains(document.activeElement)))
  }

  private readonly storageChanged = (event: StorageEvent): void => {
    if (event.key === null || event.key.startsWith(DRAFT_PREFIX)) this.hideDrafted()
  }

  connect(): void {
    this.element.addEventListener("focusin", this.focusEntered)
    this.element.addEventListener("focusout", this.focusLeft)
    window.addEventListener("storage", this.storageChanged)
    holdLiveRefresh(this.element, this.element.contains(document.activeElement))
    this.hideDrafted()
  }

  disconnect(): void {
    this.element.removeEventListener("focusin", this.focusEntered)
    this.element.removeEventListener("focusout", this.focusLeft)
    window.removeEventListener("storage", this.storageChanged)
    holdLiveRefresh(this.element, false)
  }

  private hideDrafted(): void {
    const rows = this.rowTargets
    const drafted = draftedKeys(rows.map((row) => row.dataset.draftKey ?? ""))
    const hidden = rows.map((row) => drafted.has(row.dataset.draftKey ?? ""))
    const focused = rows.findIndex((row) => row.contains(document.activeElement) || row.querySelector("[autofocus]"))
    rows.forEach((row, index) => (row.hidden = hidden[index]))
    this.element.hidden = hidden.every(Boolean)
    if (focused !== -1 && hidden[focused]) {
      const next = successorOf(hidden, focused)
      if (next !== null) rows[next].querySelector<HTMLElement>(".trade-suggestion__opener")?.focus()
    }
  }
}
