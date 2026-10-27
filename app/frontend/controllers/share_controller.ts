import { Controller } from "@hotwired/stimulus"

// The share sheet of a card's detail: "Partager" and "Copier" copy the card-season's link, to the clipboard in a secure context,
// else selected in its read-only field and copied with execCommand. The status says "Link copied" only when that worked.
export default class extends Controller<HTMLElement> {
  static targets = ["url", "status"]
  static values = { copied: String, manual: String }

  declare readonly urlTarget: HTMLInputElement
  declare readonly statusTarget: HTMLElement
  declare readonly copiedValue: string
  declare readonly manualValue: string

  connect(): void {
    this.statusTarget.textContent = ""
  }

  copy(): void {
    this.statusTarget.textContent = ""
    const url = this.urlTarget.value
    if (window.isSecureContext && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(url).then(
        () => this.say(this.copiedValue),
        () => this.copyBySelection()
      )
    } else {
      this.copyBySelection()
    }
  }

  private copyBySelection(): void {
    this.urlTarget.focus()
    this.urlTarget.select()
    let copied = false
    try {
      copied = document.execCommand("copy")
    } catch {
      copied = false
    }
    this.say(copied ? this.copiedValue : this.manualValue)
  }

  // Written a frame after the clear in copy(), so screen readers announce it on every press.
  private say(message: string): void {
    window.requestAnimationFrame(() => {
      this.statusTarget.textContent = message
    })
  }
}
