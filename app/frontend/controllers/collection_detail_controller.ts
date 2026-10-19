import { Controller } from "@hotwired/stimulus"
import { openAction, opensBeside, selectedLink } from "../lib/collection_detail"
import { motionReduced } from "../lib/motion"
import { beginStep, PHONE_WIDTH, steppingInto } from "../lib/sub_view_step"

// From 720px, a grid slot opens its card in the `card-detail` frame beside the grid, and its link stays marked while that card shows.

type DetailFrame = HTMLElement & { src: string | null }

const SLOT_LINKS = ".collection-grid a.card-link"

export default class extends Controller<HTMLElement> {
  open(event: MouseEvent): void {
    const link = event.target instanceof Element ? event.target.closest<HTMLAnchorElement>(SLOT_LINKS) : null
    const frame = this.frame()
    if (!link || !frame || !opensBeside(event, window.matchMedia(PHONE_WIDTH).matches)) return
    event.preventDefault()
    if (frame.src && new URL(frame.src, location.href).href === link.href) {
      this.reveal(frame)
      frame.querySelector<HTMLElement>("[data-sub-view-target=heading]")?.focus({ preventScroll: true })
      return
    }
    beginStep("open", "heading")
    window.Turbo.visit(link.href, { frame: frame.id, action: openAction(frame.querySelector(".card-detail") !== null) })
  }

  loaded(event: Event): void {
    const frame = event.target
    if (!(frame instanceof HTMLElement)) return
    if (frame.id === "collection-results") {
      this.mark(null)
    } else if (frame === this.frame()) {
      this.mark(frame.getAttribute("src"))
      if (steppingInto("open")) this.reveal(frame)
    }
  }

  private frame(): DetailFrame | null {
    return this.element.querySelector<DetailFrame>("turbo-frame#card-detail")
  }

  private mark(source: string | null): void {
    const links = Array.from(this.element.querySelectorAll<HTMLAnchorElement>(SLOT_LINKS))
    const selected = selectedLink(links, source, location.href)
    for (const link of links) {
      if (link === selected) link.setAttribute("aria-current", "true")
      else link.removeAttribute("aria-current")
    }
  }

  private reveal(frame: HTMLElement): void {
    const top = frame.getBoundingClientRect().top
    if (top >= 0 && top <= window.innerHeight / 2) return
    frame.scrollIntoView({ block: "start", behavior: motionReduced() ? "auto" : "smooth" })
  }
}
