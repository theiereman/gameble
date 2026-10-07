import { Controller } from "@hotwired/stimulus"

// The screen-change mark. The star field stays still at a screen change
// (EXPERIENCE.md, "Screen change"); a few stars twinkle in CSS alone
// (shell.css, .atmosphere__twinkle).
//
// A visit to the page already shown (a refresh, a form sent back to the same
// page, the current tab tapped) is no screen change:
// `html[data-screen-change=same]` tells the CSS to skip the screen's slide.
// Nor is a visit made while `html[data-sub-view-step]` is set.
//
// The layer is data-turbo-permanent, so Turbo moves it from page to page
// and this controller may disconnect and reconnect during a render.
export default class extends Controller<HTMLElement> {
  private readonly visited = (event: Event): void => {
    // A sub-view's step (the card detail's ◀ ▶, sub_view_controller.ts)
    // changes the URL but not the screen.
    if (document.documentElement.dataset.subViewStep) return
    const { url, action } = (event as CustomEvent<{ url?: string; action?: string }>).detail ?? {}
    // At turbo:visit, location is still the page being left, except on a
    // restoration (Back, Forward): the browser has already moved to the
    // entry, so a restoration always counts as a screen change.
    const same = action !== "restore" && url !== undefined && new URL(url, location.href).pathname === location.pathname
    if (same) {
      document.documentElement.dataset.screenChange = "same"
    } else {
      delete document.documentElement.dataset.screenChange
    }
  }

  connect(): void {
    document.addEventListener("turbo:visit", this.visited)
  }

  disconnect(): void {
    document.removeEventListener("turbo:visit", this.visited)
  }
}
