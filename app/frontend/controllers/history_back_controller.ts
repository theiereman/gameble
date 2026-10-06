import { Controller } from "@hotwired/stimulus"
import { backSteps, currentIndex, entryAfter, recordEntry, resetTrail, sessionTrailStorage } from "../lib/history_trail"

// A contextual back link (DESIGN.md, Back button: "◀ GRILLE" on a phone;
// EXPERIENCE.md, Phone navigation): when the page it leads to, or one of
// its alternates, is an earlier entry of this tab's history (the grid the
// card detail was opened from, ◀ ▶ having only replaced entries since), it
// goes back through history,
// so Turbo restores that page at its scroll, as browser Back would. Else
// the link navigates as usual.
//
// The trail it reads (lib/history_trail.ts) must know every page, not only
// those holding a back link: it is recorded once for the whole app, from
// this module, on every page load and on every frame visit that changes
// the URL. Those listeners live as long as the app, like Turbo's own.
// This module runs once per full document load. Turbo then reads its
// restoration index back from history.state (a reload, a back/forward
// document load), but the pages an earlier document recorded may no longer
// match those indexes: the trail starts afresh, so history.go is never sent
// to the wrong page (a reload loses the trail; the back is then a plain
// visit). A page restored from the back/forward cache runs neither this
// module nor turbo:load, and the trail may hold a later document's
// entries: it starts afresh there too, with the current entry.
//
// A page shown again by a restore visit (browser Back, or this link's
// history.go) focuses its card link leading to the page the user came back
// from (EXPERIENCE.md, Focus after each step: "Back … → the element that
// opened it"), without scrolling, so the scroll Turbo restores is kept.
const storage = sessionTrailStorage()
resetTrail(storage)
const record = (): void => recordEntry(currentIndex(), location.pathname, storage)
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

// Focuses the card link on this page leading to the page recorded right
// after the current entry, if there is one.
function focusReturnLink(): void {
  const pathname = entryAfter(currentIndex(), storage)
  if (!pathname) return
  const link = Array.from(document.querySelectorAll<HTMLAnchorElement>("a.card-link")).find(
    (anchor) => new URL(anchor.href, location.href).pathname === pathname,
  )
  link?.focus({ preventScroll: true })
}

// Alternates (`data-history-back-alternates-value`, pathnames): other pages
// the link goes back to when the detail was opened from one of them (the
// whole season's collection, whose links name each card's tome while the
// link's href is that tome's grid), i.e. when one is the entry right before
// the current one (◀ ▶ only replace entries). An alternate further back is
// not where the detail came from and is ignored (lib/history_trail.ts,
// backSteps). Else the href's page when it is an earlier entry; else the
// link visits its href.
export default class extends Controller<HTMLAnchorElement> {
  static values = { alternates: Array }

  declare readonly alternatesValue: string[]

  back(event: MouseEvent): void {
    // A new tab, a new window or a download keeps the browser's own way.
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const target = new URL(this.element.href, location.href)
    if (target.origin !== location.origin) return
    const steps = backSteps(target.pathname, this.alternatesValue, currentIndex(), storage)
    if (steps === null) return
    event.preventDefault()
    history.go(-steps)
  }
}
