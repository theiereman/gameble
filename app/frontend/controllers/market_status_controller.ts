import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { flushOutbid, noOutbids, offerOutbid, type OutbidStep, type Outbids } from "../lib/outbid_status"

export default class MarketStatusController extends Controller<HTMLElement> {
  static targets = ["region", "line"]

  declare readonly regionTarget: HTMLElement

  private outbids: Outbids = noOutbids
  private readonly waiting = new Map<string, ReturnType<typeof setTimeout>>()

  disconnect(): void {
    for (const timer of this.waiting.values()) clearTimeout(timer)
    this.waiting.clear()
  }

  lineTargetConnected(line: HTMLElement): void {
    const key = line.dataset.marketStatusKey ?? ""
    const text = line.textContent?.trim() ?? ""
    line.remove()
    if (key && text) this.apply(key, offerOutbid(this.outbids, key, text, Date.now()))
  }

  private apply(key: string, { outbids, say, wait }: OutbidStep): void {
    this.outbids = outbids
    if (say !== null) writeText(this.regionTarget, say)
    if (wait === null) return
    clearTimeout(this.waiting.get(key))
    this.waiting.set(
      key,
      setTimeout(() => this.apply(key, flushOutbid(this.outbids, key, Date.now())), wait),
    )
  }
}
