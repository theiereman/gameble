import { Controller } from "@hotwired/stimulus"
import { albumStorage, lastAlbum, leadsTo } from "../lib/last_album"

export default class extends Controller<HTMLElement> {
  connect(): void {
    this.mark()
  }

  mark(): void {
    const pathname = lastAlbum(albumStorage())
    for (const row of this.element.querySelectorAll<HTMLAnchorElement>("a.set-row")) {
      if (leadsTo(row.href, location.href, pathname)) {
        row.setAttribute("aria-current", "true")
      } else if (row.getAttribute("aria-current") === "true") {
        row.removeAttribute("aria-current")
      }
    }
  }
}
