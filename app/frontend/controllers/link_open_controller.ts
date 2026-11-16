import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { url: String }

  declare readonly urlValue: string

  record(): void {
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    const headers: Record<string, string> = { Accept: "application/json" }
    if (token) headers["X-CSRF-Token"] = token
    fetch(this.urlValue, { method: "POST", headers, credentials: "same-origin", keepalive: true }).catch(
      ignoreFailedRecord,
    )
  }
}

function ignoreFailedRecord(): void {
  // The next click on the link posts again.
}
