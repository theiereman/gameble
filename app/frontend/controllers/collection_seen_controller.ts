import { Controller } from "@hotwired/stimulus"

// The collection's watermark: when the grid shows cards new to the player, posts the latest gain's time once the page is really rendered
// (never Turbo's preview), so they are no longer new on the next visit. A failure is ignored.
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
    }).catch(() => {})
  }
}
