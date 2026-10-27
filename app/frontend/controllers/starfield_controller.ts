import { Controller } from "@hotwired/stimulus"
import { keepsFrame } from "../lib/screen_change"
import { PHONE_WIDTH } from "../lib/sub_view_step"

export default class extends Controller<HTMLElement> {
  private shownPath = location.pathname

  private readonly visited = (event: Event): void => {
    if (document.documentElement.dataset.subViewStep) return
    const { url, action } = (event as CustomEvent<{ url?: string; action?: string }>).detail ?? {}
    if (
      url !== undefined &&
      keepsFrame(this.leftPath(action), new URL(url, location.href).pathname, {
        phone: window.matchMedia(PHONE_WIDTH).matches,
      })
    ) {
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

  // At turbo:visit, location is still the page being left, except on a restoration.
  private leftPath(action: string | undefined): string {
    return action === "restore" ? this.shownPath : location.pathname
  }
}
