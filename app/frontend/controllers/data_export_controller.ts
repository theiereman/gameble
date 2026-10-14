import { Controller } from "@hotwired/stimulus"
import { dispatchGameble } from "../lib/events"
import { type ExportPhase, exportButton, exportFilename, exportedAt, failureMessage, formatUtc, nextExportAt } from "../lib/data_export"

export default class extends Controller<HTMLFormElement> {
  static targets = ["error", "download", "lastExport", "time", "nextExport", "nextTime"]
  static values = {
    preparing: String,
    retry: String,
    failed: String,
    readyTitle: String,
    ready: String,
    download: String,
    timeFormat: String,
    interval: Number,
    nextExportAt: String,
  }

  declare readonly errorTarget: HTMLElement
  declare readonly downloadTarget: HTMLAnchorElement
  declare readonly lastExportTarget: HTMLElement
  declare readonly timeTarget: HTMLTimeElement
  declare readonly nextExportTarget: HTMLElement
  declare readonly nextTimeTarget: HTMLTimeElement
  declare readonly preparingValue: string
  declare readonly retryValue: string
  declare readonly failedValue: string
  declare readonly readyTitleValue: string
  declare readonly readyValue: string
  declare readonly downloadValue: string
  declare readonly timeFormatValue: string
  declare readonly intervalValue: number
  declare readonly nextExportAtValue: string

  private idleLabel = ""
  private running = false
  private unlockTimer?: number

  connect(): void {
    this.idleLabel = this.button()?.textContent ?? ""
    const next = this.nextExportAtValue ? new Date(this.nextExportAtValue) : null
    if (next && !Number.isNaN(next.getTime())) this.waitUntil(next)
  }

  disconnect(): void {
    window.clearTimeout(this.unlockTimer)
  }

  async export(event: Event): Promise<void> {
    event.preventDefault()
    if (this.running || this.button()?.disabled) return
    this.running = true
    this.show("preparing")
    try {
      const response = await fetch(this.element.action, { method: "POST", headers: this.headers(), credentials: "same-origin" })
      if (!response.ok) {
        const body: unknown = await response.json().catch(() => null)
        const next = nextExportAt(body)
        if (next) this.waitUntil(next)
        else this.fail(failureMessage(body, this.failedValue))
        return
      }
      const at = exportedAt(await response.text())
      const download = exportFilename(response.headers.get("Content-Disposition"))
      this.offerDownload(download)
      dispatchGameble("gameble:toast", {
        title: this.readyTitleValue,
        message: this.readyValue,
        action: { label: this.downloadValue, href: this.downloadTarget.getAttribute("href") ?? "", download },
      })
      if (at) {
        this.showTime(this.lastExportTarget, this.timeTarget, at)
        this.waitUntil(new Date(at.getTime() + this.intervalValue * 1000))
      } else {
        this.show("idle")
      }
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
    const alreadyShown = !this.errorTarget.hidden && this.errorTarget.textContent === message
    this.show("failed")
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    if (!alreadyShown) dispatchGameble("gameble:toast", { message, tone: "alert" })
  }

  private waitUntil(next: Date): void {
    window.clearTimeout(this.unlockTimer)
    const remaining = next.getTime() - Date.now()
    if (remaining <= 0) {
      this.nextExportTarget.hidden = true
      this.show("idle")
      return
    }
    this.show("waiting")
    this.showTime(this.nextExportTarget, this.nextTimeTarget, next)
    this.unlockTimer = window.setTimeout(() => this.waitUntil(next), remaining)
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

  private offerDownload(filename: string): void {
    this.downloadTarget.download = filename
    this.downloadTarget.hidden = false
  }

  private showTime(line: HTMLElement, time: HTMLTimeElement, at: Date): void {
    time.dateTime = at.toISOString()
    time.textContent = formatUtc(at, this.timeFormatValue)
    line.hidden = false
  }
}
