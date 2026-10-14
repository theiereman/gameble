import { Controller } from "@hotwired/stimulus"
import { dispatchGameble, onGameble } from "../lib/events"
import { type ExportPhase, exportButton, exportFilename, failureMessage } from "../lib/data_export"

export default class extends Controller<HTMLFormElement> {
  static targets = ["error"]
  static values = { preparing: String, retry: String, failed: String, readyTitle: String, ready: String, download: String }

  declare readonly errorTarget: HTMLElement
  declare readonly preparingValue: string
  declare readonly retryValue: string
  declare readonly failedValue: string
  declare readonly readyTitleValue: string
  declare readonly readyValue: string
  declare readonly downloadValue: string

  private idleLabel = ""
  private running = false
  private objectUrl?: string
  private stopListening?: () => void

  connect(): void {
    this.idleLabel = this.button()?.textContent ?? ""
    this.stopListening = onGameble("gameble:toast-dismissed", ({ actionHref }) => {
      if (actionHref === this.objectUrl) this.revoke()
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
    this.revoke()
  }

  async export(event: Event): Promise<void> {
    event.preventDefault()
    if (this.running) return
    this.running = true
    this.show("preparing")
    try {
      const response = await fetch(this.element.action, { method: "POST", headers: this.headers(), credentials: "same-origin" })
      if (!response.ok) {
        this.fail(failureMessage(await response.json().catch(() => null), this.failedValue))
        return
      }
      const blob = await response.blob()
      this.revoke()
      this.objectUrl = URL.createObjectURL(blob)
      dispatchGameble("gameble:toast", {
        title: this.readyTitleValue,
        message: this.readyValue,
        action: { label: this.downloadValue, href: this.objectUrl, download: exportFilename(response.headers.get("Content-Disposition")) },
      })
      this.show("idle")
    } catch {
      this.fail(this.failedValue)
    } finally {
      this.running = false
    }
  }

  private headers(): Record<string, string> {
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    return token ? { Accept: "application/json", "X-CSRF-Token": token } : { Accept: "application/json" }
  }

  private fail(message: string): void {
    this.show("failed")
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    dispatchGameble("gameble:toast", { message, tone: "alert" })
  }

  private show(phase: ExportPhase): void {
    const button = this.button()
    if (button) {
      const state = exportButton(phase, { idle: this.idleLabel, preparing: this.preparingValue, retry: this.retryValue })
      button.textContent = state.label
      button.disabled = state.disabled
    }
    if (phase !== "failed") {
      this.errorTarget.hidden = true
      this.errorTarget.textContent = ""
    }
  }

  private button(): HTMLButtonElement | null {
    return this.element.querySelector<HTMLButtonElement>("button[type=submit]")
  }

  private revoke(): void {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = undefined
  }
}
