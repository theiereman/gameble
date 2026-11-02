import { Controller } from "@hotwired/stimulus"
import { ANNOUNCE_INTERVAL_MS, AnnounceBatch, shouldAnnounce } from "../lib/announce_batch"
import { t, type Template } from "../lib/i18n"
import { motionReduced } from "../lib/motion"

const REWRITE_MS = 100

export default class extends Controller<HTMLElement> {
  static targets = ["list", "status"]
  static values = { templates: Object, interval: { type: Number, default: ANNOUNCE_INTERVAL_MS } }

  declare readonly listTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly templatesValue: Template
  declare readonly intervalValue: number

  private batch = new AnnounceBatch()
  private timers: number[] = []

  private readonly streamed = (event: Event): void => {
    const stream = event.target
    if (!(stream instanceof Element) || stream.getAttribute("action") !== "prepend") return
    if (stream.getAttribute("target") !== this.listTarget.id) return
    if (motionReduced()) return

    const entries = stream.querySelector("template")?.content.children.length ?? 0
    const delay = this.batch.add(entries)
    if (delay !== null) this.later(this.announce, delay)
  }

  private readonly announce = (): void => {
    const count = this.batch.take()
    const focusInside = this.listTarget.contains(document.activeElement)
    if (!shouldAnnounce(count, { reduced: motionReduced(), focusInside })) return

    this.statusTarget.textContent = ""
    this.later(() => {
      this.statusTarget.textContent = t(this.templatesValue, { count })
    }, REWRITE_MS)
  }

  connect(): void {
    this.batch = new AnnounceBatch(this.intervalValue)
    document.addEventListener("turbo:before-stream-render", this.streamed)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
    this.timers.forEach((timer) => window.clearTimeout(timer))
    this.timers = []
  }

  private later(callback: () => void, delay: number): void {
    const timer = window.setTimeout(() => {
      this.timers = this.timers.filter((pending) => pending !== timer)
      callback()
    }, delay)
    this.timers.push(timer)
  }
}
