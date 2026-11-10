import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["url", "status"]
  static values = { copied: String, manual: String, url: String, text: String }

  declare readonly urlTarget: HTMLInputElement
  declare readonly statusTarget: HTMLElement
  declare readonly copiedValue: string
  declare readonly manualValue: string
  declare readonly urlValue: string
  declare readonly textValue: string

  connect(): void {
    this.statusTarget.textContent = ""
  }

  copy(): void {
    this.statusTarget.textContent = ""
    const url = this.urlTarget.value
    if (window.isSecureContext && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(url).then(
        () => this.say(this.copiedValue),
        () => this.copyBySelection(),
      )
    } else {
      this.copyBySelection()
    }
  }

  async send(): Promise<void> {
    this.statusTarget.textContent = ""
    const url = this.urlValue
    if (navigator.share) {
      try {
        await navigator.share({ text: this.textValue, url })
        return
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") return
      }
    }
    try {
      await navigator.clipboard.writeText(url)
      this.say(this.copiedValue)
    } catch {
      this.say(this.manualValue)
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
