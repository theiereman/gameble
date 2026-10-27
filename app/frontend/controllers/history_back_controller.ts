import { Controller } from "@hotwired/stimulus"
import { currentIndex, currentScreenLabel, currentScreenLabels, entryAfter, recordEntry, resetTrail, sessionTrailStorage, stepsBackTo } from "../lib/history_trail"

// A contextual back link: when its target is an earlier entry of this tab's history, it goes back through history so Turbo restores
// that page at its scroll; otherwise it navigates as usual.
// This module also records the history trail for the whole app, afresh on each full document load and bfcache restore.
// A page shown again by a restore visit focuses the card link leading to the page the user came back from, without scrolling.
const storage = sessionTrailStorage()
resetTrail(storage)
const record = (): void => recordEntry(currentIndex(), location.pathname, storage, currentScreenLabel(), currentScreenLabels())
let restoring = false
document.addEventListener("turbo:visit", (event) => {
  restoring = (event as CustomEvent<{ action?: string }>).detail?.action === "restore"
})
document.addEventListener("turbo:load", () => {
  record()
  if (restoring) focusReturnLink()
  restoring = false
})
document.addEventListener("turbo:frame-load", record)
window.addEventListener("pageshow", (event) => {
  if (!event.persisted) return
  resetTrail(storage)
  record()
})

function focusReturnLink(): void {
  const pathname = entryAfter(currentIndex(), storage)
  if (!pathname) return
  const link = Array.from(document.querySelectorAll<HTMLAnchorElement>("a.card-link, a.set-row")).find(
    (anchor) => new URL(anchor.href, location.href).pathname === pathname,
  )
  link?.focus({ preventScroll: true })
}

// The trail matches pathnames only: once a step of the detail pointed the link at another grid page, it visits that href instead.
export default class extends Controller<HTMLAnchorElement> {
  private renderedHref: string | null = null

  connect(): void {
    this.renderedHref = this.element.getAttribute("href")
  }

  back(event: MouseEvent): void {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (this.element.getAttribute("href") !== this.renderedHref) return
    const target = new URL(this.element.href, location.href)
    if (target.origin !== location.origin) return
    const steps = stepsBackTo(target.pathname, currentIndex(), storage)
    if (steps === null) return
    event.preventDefault()
    history.go(-steps)
  }
}
