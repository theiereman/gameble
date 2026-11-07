import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { fetchChip } from "../../lib/countdown"
import { dispatchGameble, onGameble } from "../../lib/events"
import {
  anyDialogOpen,
  closePanels,
  oncePerTask,
  readAvatar,
  readCounts,
  sameState,
  togglePanel,
  type TopBarState,
} from "../../lib/native_top_bar"

const WATCHED = { subtree: true, childList: true, characterData: true, attributes: true }
const DIALOGS_WATCHED = { subtree: true, childList: true, attributes: true, attributeFilter: ["open"] }
const CACHED_MARK = "data-top-bar-cached"

export default class extends BridgeComponent {
  static component = "top-bar"
  static values = { url: String }

  declare readonly urlValue: string

  private stopListening: Array<() => void> = []
  private observer?: MutationObserver
  private dialogObserver?: MutationObserver
  private lastReport: TopBarState | null = null
  private lastDialogOpen: boolean | null = null
  private awaitingFreshValues = false
  private readonly reportSoon = oncePerTask(() => void this.report())
  private readonly reportDialogSoon = oncePerTask(() => this.reportDialog())

  connect(): void {
    super.connect()
    this.stopWatching()
    this.stopListening = [
      onGameble("gameble:screen-shown", () => this.screenShown()),
      onGameble("gameble:top-bar-panel", ({ panel }) => togglePanel(this.element, panel)),
    ]
    this.observer = new MutationObserver(this.reportSoon)
    this.observer.observe(this.element, WATCHED)
    this.dialogObserver = new MutationObserver(this.reportDialogSoon)
    this.dialogObserver.observe(document.body, DIALOGS_WATCHED)
    document.addEventListener("visibilitychange", this.cameBack)
    document.addEventListener("turbo:before-cache", this.markAsCached)
    this.lastDialogOpen = null
    this.reportDialog()
    if (this.element.hasAttribute(CACHED_MARK)) this.replaceCachedValues()
    else this.reportSoon()
  }

  disconnect(): void {
    this.stopWatching()
    document.removeEventListener("visibilitychange", this.cameBack)
    document.removeEventListener("turbo:before-cache", this.markAsCached)
    super.disconnect()
  }

  navigate(event: Event): void {
    const link = (event.target as Element).closest<HTMLAnchorElement>("a[href]")
    if (!link || link.origin !== window.location.origin) return
    event.preventDefault()
    if (link.getAttribute("aria-disabled") === "true") return
    closePanels(this.element)
    this.send("navigate", { path: `${link.pathname}${link.search}${link.hash}` })
  }

  private stopWatching(): void {
    for (const stop of this.stopListening) stop()
    this.stopListening = []
    this.observer?.disconnect()
    this.observer = undefined
    this.dialogObserver?.disconnect()
    this.dialogObserver = undefined
  }

  private readonly markAsCached = (): void => {
    this.element.setAttribute(CACHED_MARK, "")
  }

  private readonly cameBack = (): void => {
    if (document.visibilityState === "visible") dispatchGameble("gameble:screen-shown", null)
  }

  private screenShown(): void {
    closePanels(this.element)
    void this.refresh()
  }

  private async refresh(): Promise<void> {
    dispatchGameble("gameble:bank-updated", {})
    const refresh = await fetchChip(this.urlValue)
    this.awaitingFreshValues = false
    if (refresh.kind !== "render") return
    this.reportNextEvenIfUnchangedHere()
    window.Turbo.renderStreamMessage(refresh.html)
  }

  private replaceCachedValues(): void {
    this.awaitingFreshValues = true
    this.element.removeAttribute(CACHED_MARK)
    void this.refresh()
  }

  private reportNextEvenIfUnchangedHere(): void {
    this.lastReport = null
  }

  private reportDialog(): void {
    const open = anyDialogOpen(document.body)
    if (open === this.lastDialogOpen) return
    this.lastDialogOpen = open
    this.send("dialog", { open })
  }

  private async report(): Promise<void> {
    if (this.awaitingFreshValues) return
    const state = { ...readCounts(this.element), avatar: await readAvatar(this.element) }
    if (!this.element.isConnected || sameState(this.lastReport, state)) return
    this.lastReport = state
    this.send("state", { ...state })
  }
}
