import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"
import { streamSignal } from "../lib/stream_actions"
import "../lib/turbo"

type SubmitEndDetail = { success: boolean; fetchResponse?: { header(name: string): string | null } }

// Morphs the page again when its signal arrives, but never over a visit or a
// submission in flight, unsent text, an open dialog or an element holding it
// back (`data-live-refresh-hold`): it waits until those are over, since Turbo
// drops a refresh asked for during a visit.
export default class extends Controller<HTMLElement> {
  static values = { signal: String }

  declare readonly signalValue: string

  private stopListening?: () => void
  private due = false
  private submitting = false
  private holds?: MutationObserver

  private readonly submitStarted = (): void => {
    this.submitting = true
  }

  private readonly submitEnded = (event: Event): void => {
    const { success, fetchResponse } = (event as CustomEvent<SubmitEndDetail>).detail ?? {}
    const answeredWithStream = fetchResponse?.header("Content-Type")?.startsWith("text/vnd.turbo-stream.html") ?? false
    const visitFollows = success && !answeredWithStream
    if (visitFollows) return

    this.submitting = false
    this.refreshWhenFree()
  }

  private readonly visitEnded = (): void => {
    this.submitting = false
    // Turbo forgets its current visit just after turbo:load.
    window.setTimeout(this.refreshWhenFree)
  }

  private readonly refreshWhenFree = (): void => {
    if (!this.due || this.submitting || this.visiting() || this.holdingUnsavedState()) return

    this.due = false
    window.Turbo.session.refresh(document.baseURI, { method: "morph", scroll: "preserve" })
  }

  connect(): void {
    const signal = streamSignal(this.signalValue)
    if (signal) {
      this.stopListening = onGameble(`gameble:${signal}`, () => {
        this.due = true
        this.refreshWhenFree()
      })
    }
    document.addEventListener("turbo:submit-start", this.submitStarted)
    document.addEventListener("turbo:submit-end", this.submitEnded)
    document.addEventListener("turbo:load", this.visitEnded)
    this.element.addEventListener("input", this.refreshWhenFree)
    // A dialog's close event does not bubble; it is caught on its way down.
    document.addEventListener("close", this.refreshWhenFree, true)
    this.holds = new MutationObserver(this.refreshWhenFree)
    this.holds.observe(this.element, { subtree: true, attributes: true, attributeFilter: ["data-live-refresh-hold"] })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
    document.removeEventListener("turbo:submit-start", this.submitStarted)
    document.removeEventListener("turbo:submit-end", this.submitEnded)
    document.removeEventListener("turbo:load", this.visitEnded)
    this.element.removeEventListener("input", this.refreshWhenFree)
    document.removeEventListener("close", this.refreshWhenFree, true)
    this.holds?.disconnect()
    this.holds = undefined
  }

  private visiting(): boolean {
    return window.Turbo.navigator.currentVisit !== undefined
  }

  private holdingUnsavedState(): boolean {
    return this.dialogOpen() || this.unsentText() || this.heldBack()
  }

  private heldBack(): boolean {
    return this.element.querySelector("[data-live-refresh-hold]") !== null
  }

  private dialogOpen(): boolean {
    return document.querySelector("dialog[open]") !== null
  }

  private unsentText(): boolean {
    const fields = this.element.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>(
      "input:not([type=hidden]):not([readonly]), textarea:not([readonly])",
    )
    return Array.from(fields).some((field) => field.value !== field.defaultValue)
  }
}
