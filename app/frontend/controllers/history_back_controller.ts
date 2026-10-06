import { Controller } from "@hotwired/stimulus"
import { currentIndex, recordEntry, resetTrail, sessionTrailStorage, stepsBackTo } from "../lib/history_trail"

// A contextual back link (DESIGN.md, Back button: "◀ GRILLE" on a phone;
// EXPERIENCE.md, Phone navigation): when the page it leads to is an earlier
// entry of this tab's history (the grid the card detail was opened from,
// ◀ ▶ having only replaced entries since), it goes back through history,
// so Turbo restores that page at its scroll, as browser Back would. Else
// the link navigates as usual.
//
// The trail it reads (lib/history_trail.ts) must know every page, not only
// those holding a back link: it is recorded once for the whole app, from
// this module, on every page load and on every frame visit that changes
// the URL. Those two listeners live as long as the app, like Turbo's own.
// This module runs once per full document load, where Turbo's restoration
// index restarts at 0: the trail starts afresh, so an index recorded by an
// earlier document never sends history.go to the wrong page.
resetTrail(sessionTrailStorage())
const record = (): void => recordEntry(currentIndex(), location.pathname, sessionTrailStorage())
document.addEventListener("turbo:load", record)
document.addEventListener("turbo:frame-load", record)

export default class extends Controller<HTMLAnchorElement> {
  back(event: MouseEvent): void {
    // A new tab, a new window or a download keeps the browser's own way.
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const target = new URL(this.element.href, location.href)
    if (target.origin !== location.origin) return
    const steps = stepsBackTo(target.pathname, currentIndex(), sessionTrailStorage())
    if (steps === null) return
    event.preventDefault()
    history.go(-steps)
  }
}
