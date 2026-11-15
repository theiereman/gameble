import { Controller } from "@hotwired/stimulus"

let switchedTab = false

export default class extends Controller<HTMLElement> {
  static values = { url: String, current: String, kept: String }

  declare readonly urlValue: string
  declare readonly currentValue: string
  declare readonly keptValue: string

  connect(): void {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    if (switchedTab) {
      switchedTab = false
      document.querySelector<HTMLElement>("#main h1")?.focus()
    }
    if (this.currentValue !== this.keptValue) this.keep()
  }

  follow(event: Event): void {
    const link = event.currentTarget as HTMLElement
    if (link.getAttribute("aria-current") !== "page") switchedTab = true
  }

  private keep(): void {
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" }
    if (token) headers["X-CSRF-Token"] = token
    fetch(this.urlValue, {
      method: "POST",
      headers,
      body: JSON.stringify({ tab: this.currentValue }),
      credentials: "same-origin",
      keepalive: true,
    }).catch(ignoreFailedKeep)
  }
}

function ignoreFailedKeep(): void {
  // The trades tab keeps leading to the previous sub-tab until the next visit posts again.
}
