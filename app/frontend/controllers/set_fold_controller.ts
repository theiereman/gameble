import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["list", "button"]

  declare readonly listTarget: HTMLElement
  declare readonly buttonTarget: HTMLButtonElement

  unfold(): void {
    const firstFolded = Array.from(this.listTarget.querySelectorAll<HTMLElement>(".set-tile")).find(
      (tile) => tile.getClientRects().length === 0,
    )
    this.listTarget.classList.add("is-unfolded")
    this.buttonTarget.hidden = true
    firstFolded?.focus()
  }
}
