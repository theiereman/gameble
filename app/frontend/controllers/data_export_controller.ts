import { Controller } from "@hotwired/stimulus"
import { dispatchGameble } from "../lib/events"
import { type ExportPhase, exportButton, exportFilename, exportedAt, failureMessage, formatUtc } from "../lib/data_export"

export default class extends Controller<HTMLFormElement> {
  static targets = ["error", "download", "lastExport", "time"]
  static values = { preparing: String, retry: String, failed: String, readyTitle: String, ready: String, download: String, timeFormat: String }

  declare readonly errorTarget: HTMLElement
  declare readonly downloadTarget: HTMLAnchorElement
  declare readonly lastExportTarget: HTMLElement
  declare readonly timeTarget: HTMLTimeElement
  declare readonly preparingValue: string
  declare readonly retryValue: string
  declare readonly failedValue: string
  declare readonly readyTitleValue: string
  declare readonly readyValue: string
  declare readonly downloadValue: string
  declare readonly timeFormatValue: string

  private idleLabel = ""
  private running = false
  private objectUrl?: string

  connect(): void {
    this.idleLabel = this.button()?.textContent ?? ""
  }

  disconnect(): void {
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
      const download = exportFilename(response.headers.get("Content-Disposition"))
      this.offerDownload(this.objectUrl, download)
      this.showLastExport(exportedAt(await blob.text()))
      dispatchGameble("gameble:toast", {
        title: this.readyTitleValue,
        message: this.readyValue,
        action: { label: this.downloadValue, href: this.objectUrl, download },
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

  private offerDownload(href: string, filename: string): void {
    this.downloadTarget.href = href
    this.downloadTarget.download = filename
    this.downloadTarget.hidden = false
  }

  private showLastExport(at: Date | null): void {
    if (!at) return
    this.timeTarget.dateTime = at.toISOString()
    this.timeTarget.textContent = formatUtc(at, this.timeFormatValue)
    this.lastExportTarget.hidden = false
  }

  private revoke(): void {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = undefined
    this.downloadTarget.hidden = true
    this.downloadTarget.removeAttribute("href")
  }
}
