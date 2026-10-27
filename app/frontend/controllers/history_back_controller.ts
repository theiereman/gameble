import { Controller } from "@hotwired/stimulus"
import {
  currentIndex,
  currentScreenLabel,
  currentScreenLabels,
  entryAfter,
  recordEntry,
  resetTrail,
  sessionTrailStorage,
  stepsBackTo,
} from "../lib/history_trail"

const storage = sessionTrailStorage()
resetTrail(storage)
const record = (): void =>
  recordEntry(currentIndex(), location.pathname, storage, currentScreenLabel(), currentScreenLabels())
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

export default class extends Controller<HTMLAnchorElement> {
  private renderedHref: string | null = null

  connect(): void {
    this.renderedHref = this.element.getAttribute("href")
  }

  back(event: MouseEvent): void {
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    )
      return
    if (this.element.getAttribute("href") !== this.renderedHref) return
    const target = new URL(this.element.href, location.href)
    if (target.origin !== location.origin) return
    const steps = stepsBackTo(target.pathname, currentIndex(), storage)
    if (steps === null) return
    event.preventDefault()
    history.go(-steps)
  }
}
