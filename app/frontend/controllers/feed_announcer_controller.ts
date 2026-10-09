import { Controller } from "@hotwired/stimulus"
import { ANNOUNCE_INTERVAL_MS, AnnounceBatch, beyondLimit, shouldAnnounce } from "../lib/announce_batch"
import { t, type Template } from "../lib/i18n"
import { motionReduced } from "../lib/motion"

// Screen readers skip a status line rewritten with the same text unless it is emptied first.
const REWRITE_MS = 100

type StreamRenderDetail = { render: (stream: Element) => void | Promise<void> }

export default class extends Controller<HTMLElement> {
  static targets = ["list", "status"]
  static values = { templates: Object, interval: { type: Number, default: ANNOUNCE_INTERVAL_MS }, limit: Number }

  declare readonly listTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly templatesValue: Template
  declare readonly intervalValue: number
  declare readonly limitValue: number

  private batch = new AnnounceBatch()
  private timers: number[] = []

  private readonly streamed = (event: Event): void => {
    const stream = event.target
    if (!(stream instanceof Element) || stream.getAttribute("action") !== "prepend") return
    if (stream.getAttribute("target") !== this.listTarget.id) return
    if (this.limitValue > 0) this.trimAfterRender(event as CustomEvent<StreamRenderDetail>)
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

  private trimAfterRender(event: CustomEvent<StreamRenderDetail>): void {
    const render = event.detail.render
    event.detail.render = async (stream) => {
      await render(stream)
      beyondLimit(Array.from(this.listTarget.children), this.limitValue).forEach((entry) => entry.remove())
    }
  }

  private later(callback: () => void, delay: number): void {
    const timer = window.setTimeout(() => {
      this.timers = this.timers.filter((pending) => pending !== timer)
      callback()
    }, delay)
    this.timers.push(timer)
  }
}
