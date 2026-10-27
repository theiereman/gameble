import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { url: String, upTo: String }

  declare readonly urlValue: string
  declare readonly upToValue: string

  private posted = false

  connect(): void {
    if (this.posted || document.documentElement.hasAttribute("data-turbo-preview")) return
    this.posted = true

    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" }
    if (token) headers["X-CSRF-Token"] = token
    fetch(this.urlValue, {
      method: "POST",
      headers,
      body: JSON.stringify({ up_to: this.upToValue }),
      credentials: "same-origin",
      keepalive: true,
    }).catch(ignoreFailedWatermark)
  }
}

function ignoreFailedWatermark(): void {
  // The cards stay new until the next visit posts again.
}
