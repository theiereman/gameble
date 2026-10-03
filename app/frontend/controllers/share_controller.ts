import { Controller } from "@hotwired/stimulus"

// The share button of a card's detail (CAP-9): copies the link of the card on
// the holder's public profile. In a secure context (HTTPS, localhost) the link
// is written to the clipboard right in the click; elsewhere (the plain-HTTP
// test server) or when the browser refuses, the link is selected in its
// read-only field and copied with the older execCommand, and the status says
// "Link copied" only when that worked, else how to copy it by hand. No Web
// Share API, no tracking: the link only.
export default class extends Controller<HTMLElement> {
  static targets = ["url", "status"]
  static values = { copied: String, manual: String }

  declare readonly urlTarget: HTMLInputElement
  declare readonly statusTarget: HTMLElement
  declare readonly copiedValue: string
  declare readonly manualValue: string

  // A page restored from Turbo's cache shows no earlier feedback.
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

  // The link selected in its field, then copied by execCommand when the
  // browser still allows it; the selection stays for Ctrl+C otherwise.
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

  // Written in a later frame than the clear in copy(), so the status region
  // changes on every press and screen readers announce it each time.
  private say(message: string): void {
    window.requestAnimationFrame(() => {
      this.statusTarget.textContent = message
    })
  }
}
