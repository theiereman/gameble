import { Controller } from "@hotwired/stimulus"
import {
  bellStorage,
  dismissibleKeys,
  hiddenLines,
  keysToSend,
  linesSeenHere,
  sendRead,
  takeLegacySeen,
  type BellLine,
} from "../lib/bell"
import { csrfToken } from "../lib/booster_page"
import { writeText } from "../lib/dom_writes"
import { onGameble } from "../lib/events"
import { t, type Template } from "../lib/i18n"

type FrameElement = HTMLElement & { reload(): void }

const readBeforeTheFrameReloads = new Map<string, Set<string>>()

export default class extends Controller<HTMLElement> {
  static targets = ["item", "empty", "count", "label", "frame", "readAll"]
  static values = { labels: Object, owner: String, readUrl: String }

  declare readonly itemTargets: HTMLElement[]
  declare readonly hasEmptyTarget: boolean
  declare readonly emptyTarget: HTMLElement
  declare readonly countTarget: HTMLElement
  declare readonly labelTarget: HTMLElement
  declare readonly frameTarget: FrameElement
  declare readonly readAllTarget: HTMLElement
  declare readonly labelsValue: Template
  declare readonly ownerValue: string
  declare readonly readUrlValue: string

  private stopListening: Array<() => void> = []

  connect(): void {
    this.markRead(takeLegacySeen(bellStorage(), this.ownerValue))
    this.stopListening = [
      onGameble("gameble:trades-updated", () => this.reload()),
      onGameble("gameble:friends-updated", () => this.reload()),
      onGameble("gameble:reactions-updated", () => this.reload()),
      onGameble("gameble:market-updated", () => this.reload()),
      onGameble("gameble:duels-updated", () => this.reload()),
      onGameble("gameble:screen-shown", () => this.reload()),
    ]
  }

  disconnect(): void {
    for (const stop of this.stopListening) stop()
    this.stopListening = []
  }

  itemTargetConnected(): void {
    this.show()
  }

  itemTargetDisconnected(): void {
    if (this.element.isConnected) this.show()
  }

  emptyTargetConnected(): void {
    this.show()
  }

  follow(event: Event & { params: { key?: string } }): void {
    const line = this.lines().find((candidate) => candidate.key === String(event.params.key ?? ""))
    if (line && !line.lasting) this.markRead([line.key])
    this.show()
  }

  readAll(): void {
    this.markRead(dismissibleKeys(this.lines()))
    this.show()
  }

  keep(event: Event): void {
    event.preventDefault()
  }

  show(): void {
    const lines = this.lines()
    this.markRead(linesSeenHere(lines, window.location.pathname))
    const hidden = hiddenLines(lines, this.readHere())
    for (const item of this.itemTargets) item.hidden = hidden.has(item.dataset.bellKey ?? "")
    const unseen = lines.length - hidden.size
    this.readAllTarget.hidden = dismissibleKeys(lines).every((key) => hidden.has(key))

    if (this.hasEmptyTarget) this.emptyTarget.hidden = unseen > 0
    this.countTarget.hidden = unseen === 0
    writeText(this.countTarget, String(unseen))
    writeText(this.labelTarget, t(this.labelsValue, { count: unseen }))
  }

  private markRead(keys: string[]): void {
    const fresh = keysToSend(keys, this.lines(), this.readHere())
    if (fresh.length === 0) return

    for (const key of fresh) this.readHere().add(key)
    void sendRead({ url: this.readUrlValue, keys: fresh, csrfToken: csrfToken() })
  }

  private readHere(): Set<string> {
    let keys = readBeforeTheFrameReloads.get(this.ownerValue)
    if (!keys) readBeforeTheFrameReloads.set(this.ownerValue, (keys = new Set()))
    return keys
  }

  private reload(): void {
    this.frameTarget.reload()
  }

  private lines(): BellLine[] {
    return this.itemTargets.map((item) => ({
      key: item.dataset.bellKey ?? "",
      path: item.dataset.bellPath,
      lasting: item.dataset.bellLasting === "true",
      read: item.dataset.bellRead === "true",
    }))
  }
}
