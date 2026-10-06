import { Controller } from "@hotwired/stimulus"

// The collection's watermark (AD-26): the server renders this element only
// when the grid shows cards new to the signed-in player, with the latest
// gain shown (ISO 8601, to the microsecond). Once the page is really
// rendered (never Turbo's preview of a cached copy), it posts that time,
// once, so those cards are no longer new on the next visit. The GET wrote
// nothing (AD-11). A failure is ignored: the cards stay new until a later
// visit posts again.
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
