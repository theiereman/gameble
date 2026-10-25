import { Controller } from "@hotwired/stimulus"
import { keepsFrame } from "../lib/screen_change"
import { PHONE_WIDTH } from "../lib/sub_view_step"

// The screen-change mark. The star field stays still at a screen change
// (EXPERIENCE.md, "Screen change"); a few stars twinkle in CSS alone
// (shell.css, .atmosphere__twinkle).
//
// A visit that keeps the frame of the page shown (the same page: a refresh,
// a form sent back to it, the current tab tapped; a step of Trades) is no
// screen change (lib/screen_change.ts): `html[data-screen-change=same]`
// tells the CSS to skip the screen's slide.
// Nor is a visit made while `html[data-sub-view-step]` is set.
//
// The layer is data-turbo-permanent, so Turbo moves it from page to page
// and this controller may disconnect and reconnect during a render.
export default class extends Controller<HTMLElement> {
  private shownPath = location.pathname

  private readonly visited = (event: Event): void => {
    // A sub-view's step (the card detail's ◀ ▶, sub_view_controller.ts)
    // changes the URL but not the screen.
    if (document.documentElement.dataset.subViewStep) return
    const { url, action } = (event as CustomEvent<{ url?: string; action?: string }>).detail ?? {}
    if (url !== undefined && keepsFrame(this.leftPath(action), new URL(url, location.href).pathname, { phone: window.matchMedia(PHONE_WIDTH).matches })) {
      document.documentElement.dataset.screenChange = "same"
    } else {
      delete document.documentElement.dataset.screenChange
    }
  }

  private readonly loaded = (): void => {
    this.shownPath = location.pathname
  }

  connect(): void {
    document.addEventListener("turbo:visit", this.visited)
    document.addEventListener("turbo:load", this.loaded)
  }

  disconnect(): void {
    document.removeEventListener("turbo:visit", this.visited)
    document.removeEventListener("turbo:load", this.loaded)
  }

  // At turbo:visit, location is still the page being left, except on a
  // restoration (Back, Forward): the browser has already moved to the entry.
  private leftPath(action: string | undefined): string {
    return action === "restore" ? this.shownPath : location.pathname
  }
}
