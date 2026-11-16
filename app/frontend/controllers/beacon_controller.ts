import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { url: String }

  declare readonly urlValue: string

  private posted = false

  connect(): void {
    if (this.posted || document.documentElement.hasAttribute("data-turbo-preview")) return
    this.posted = true

    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    const headers: Record<string, string> = { Accept: "application/json" }
    if (token) headers["X-CSRF-Token"] = token
    fetch(this.urlValue, { method: "POST", headers, credentials: "same-origin", keepalive: true }).catch(
      ignoreFailedMark,
    )
  }
}

function ignoreFailedMark(): void {
  // A missed beacon is posted again by the next visit.
}
