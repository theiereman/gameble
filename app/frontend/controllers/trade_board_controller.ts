import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"
import { dispatchGameble, onGameble } from "../lib/events"
import { currentIndex, currentScreenLabel, recordEntry, sessionTrailStorage } from "../lib/history_trail"
import { holdLiveRefresh } from "../lib/live_refresh_hold"
import { forgetDraft } from "../lib/trade_draft"

const opensElsewhere = (event: Event): boolean =>
  event instanceof MouseEvent && (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)

export default class extends Controller<HTMLElement> {
  static targets = ["chip", "editingChip", "readActions", "editActions", "editButton", "undoDialog"]
  static values = {
    editing: Boolean,
    focus: Boolean,
    forget: String,
    draft: String,
    counterUrl: String,
    boardUrl: String,
  }

  declare readonly chipTargets: HTMLElement[]
  declare readonly editingChipTargets: HTMLElement[]
  declare readonly readActionsTargets: HTMLElement[]
  declare readonly editActionsTargets: HTMLElement[]
  declare readonly editButtonTargets: HTMLElement[]
  declare readonly hasUndoDialogTarget: boolean
  declare readonly undoDialogTarget: HTMLDialogElement
  declare editingValue: boolean
  declare readonly focusValue: boolean
  declare readonly forgetValue: string
  declare readonly draftValue: string
  declare readonly counterUrlValue: string
  declare readonly boardUrlValue: string

  private changed = false
  private stopListening?: () => void

  connect(): void {
    if (this.editingValue) holdLiveRefresh(this.element, true)
    if (this.forgetValue) forgetDraft(this.forgetValue)
    this.stopListening = onGameble("gameble:trade-changed", ({ changed }) => {
      this.changed = changed
    })
    if (this.focusValue) this.element.querySelector<HTMLElement>("#trade-board-heading")?.focus({ preventScroll: true })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }

  edit(event: Event): void {
    if (opensElsewhere(event)) return
    event.preventDefault()
    this.show(true)
    dispatchGameble("gameble:trade-editing", { editing: true })
    this.replaceUrl(this.counterUrlValue)
  }

  undo(event: Event): void {
    if (opensElsewhere(event)) return
    event.preventDefault()
    const opener = (event.target as Element | null)?.closest<HTMLElement>("a, button")
    if (this.changed && this.hasUndoDialogTarget && opener) {
      openDialog(this.undoDialogTarget, opener)
      return
    }
    this.restore()
  }

  restore(): void {
    if (this.hasUndoDialogTarget && this.undoDialogTarget.open) this.undoDialogTarget.close()
    this.show(false)
    dispatchGameble("gameble:trade-editing", { editing: false })
    this.replaceUrl(this.boardUrlValue)
    this.editButtonTargets[0]?.querySelector<HTMLElement>("a, button")?.focus()
  }

  abandon(): void {
    if (this.draftValue) forgetDraft(this.draftValue)
  }

  private show(editing: boolean): void {
    this.editingValue = editing
    holdLiveRefresh(this.element, editing)
    this.element.classList.toggle("trade-board--editing", editing)
    this.chipTargets.forEach((element) => (element.hidden = editing))
    this.readActionsTargets.forEach((element) => (element.hidden = editing))
    this.editingChipTargets.forEach((element) => (element.hidden = !editing))
    this.editActionsTargets.forEach((element) => (element.hidden = !editing))
  }

  private replaceUrl(url: string): void {
    if (!url) return
    const next = new URL(url, window.location.href)
    if (next.pathname === window.location.pathname) return
    window.history.replaceState(window.history.state, "", next)
    recordEntry(currentIndex(), next.pathname, sessionTrailStorage(), currentScreenLabel())
  }
}
