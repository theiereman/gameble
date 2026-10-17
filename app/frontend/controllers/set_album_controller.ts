import { Controller } from "@hotwired/stimulus"
import { albumStorage, rememberAlbum } from "../lib/last_album"

export default class extends Controller<HTMLElement> {
  static targets = ["heading"]

  declare readonly headingTarget: HTMLElement

  connect(): void {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    rememberAlbum(location.pathname, albumStorage())
    this.headingTarget.focus({ preventScroll: true })
  }
}
