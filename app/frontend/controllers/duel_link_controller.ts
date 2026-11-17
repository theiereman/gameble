import { Controller } from "@hotwired/stimulus"
import { clockText } from "../lib/duel_clock"
import { linkChecked, linkSecondsLeft, startLink, type Link } from "../lib/duel_link"

const TICK_MS = 250

export default class extends Controller<HTMLElement> {
  static values = { template: String }
  static targets = ["text"]

  declare readonly templateValue: string
  declare readonly textTarget: HTMLElement

  private link: Link = startLink()
  private observer?: MutationObserver
  private timer?: number

  connect(): void {
    window.addEventListener("offline", this.check)
    window.addEventListener("online", this.check)
    this.observer = new MutationObserver(this.check)
    this.observer.observe(document.body, { attributes: true, attributeFilter: ["connected"], subtree: true })
    this.check()
  }

  disconnect(): void {
    window.removeEventListener("offline", this.check)
    window.removeEventListener("online", this.check)
    this.observer?.disconnect()
    window.clearInterval(this.timer)
  }

  private readonly check = (): void => {
    const sources = Array.from(document.querySelectorAll("turbo-cable-stream-source"))
    const connected = sources.length > 0 && sources.every((source) => source.hasAttribute("connected"))
    const was = this.link.lostAt !== null
    this.link = linkChecked(this.link, connected, navigator.onLine, performance.now())
    const lost = this.link.lostAt !== null
    if (lost === was) return

    this.element.hidden = !lost
    window.clearInterval(this.timer)
    if (!lost) return

    this.tick()
    this.timer = window.setInterval(() => this.tick(), TICK_MS)
  }

  private tick(): void {
    const seconds = linkSecondsLeft(this.link, performance.now())
    if (seconds !== null) this.textTarget.textContent = clockText(this.templateValue, seconds)
  }
}
