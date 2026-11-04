import { Controller } from "@hotwired/stimulus"
import {
  bellStorage,
  dismissibleKeys,
  hiddenLines,
  linesSeenHere,
  markSeen,
  readSeen,
  type BellLine,
} from "../lib/bell"
import { writeText } from "../lib/dom_writes"
import { onGameble } from "../lib/events"
import { t, type Template } from "../lib/i18n"

type FrameElement = HTMLElement & { reload(): void }

export default class extends Controller<HTMLElement> {
  static targets = ["item", "empty", "count", "label", "frame", "readAll"]
  static values = { labels: Object, owner: String }

  declare readonly itemTargets: HTMLElement[]
  declare readonly hasEmptyTarget: boolean
  declare readonly emptyTarget: HTMLElement
  declare readonly countTarget: HTMLElement
  declare readonly labelTarget: HTMLElement
  declare readonly frameTarget: FrameElement
  declare readonly readAllTarget: HTMLElement
  declare readonly labelsValue: Template
  declare readonly ownerValue: string

  private readonly storage = bellStorage()
  private stopListening: Array<() => void> = []

  connect(): void {
    this.stopListening = [
      onGameble("gameble:trades-updated", () => this.reload()),
      onGameble("gameble:friends-updated", () => this.reload()),
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
    if (line && !line.lasting) markSeen([line.key], this.storage, this.ownerValue)
    this.show()
  }

  readAll(): void {
    markSeen(dismissibleKeys(this.lines()), this.storage, this.ownerValue)
    this.show()
  }

  keep(event: Event): void {
    event.preventDefault()
  }

  // Turbo restores a cached frame marked complete and never reloads its source.
  reloadWhenRestored(): void {
    this.frameTarget.removeAttribute("complete")
  }

  show(): void {
    const lines = this.lines()
    markSeen(linesSeenHere(lines, window.location.pathname), this.storage, this.ownerValue)
    const hidden = hiddenLines(lines, readSeen(this.storage, this.ownerValue))
    for (const item of this.itemTargets) item.hidden = hidden.has(item.dataset.bellKey ?? "")
    const unseen = lines.length - hidden.size
    this.readAllTarget.hidden = dismissibleKeys(lines).every((key) => hidden.has(key))

    if (this.hasEmptyTarget) this.emptyTarget.hidden = unseen > 0
    this.countTarget.hidden = unseen === 0
    writeText(this.countTarget, String(unseen))
    writeText(this.labelTarget, t(this.labelsValue, { count: unseen }))
  }

  private reload(): void {
    this.frameTarget.reload()
  }

  private lines(): BellLine[] {
    return this.itemTargets.map((item) => ({
      key: item.dataset.bellKey ?? "",
      path: item.dataset.bellPath,
      lasting: item.dataset.bellLasting === "true",
    }))
  }
}
