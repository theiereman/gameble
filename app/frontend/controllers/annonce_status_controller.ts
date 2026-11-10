import { Controller } from "@hotwired/stimulus"
import {
  OWN_BID_QUIET_MS,
  flush,
  idle,
  milestones,
  offer,
  type StatusKind,
  type StatusLine,
  type Throttle,
} from "../lib/annonce_status"
import { writeText } from "../lib/dom_writes"
import { motionReduced } from "../lib/motion"

export default class AnnonceStatusController extends Controller<HTMLElement> {
  private throttle: Throttle = idle
  private line: StatusLine | null = null
  private seen = false
  private ended = false
  private quietUntil = 0
  private waiting?: ReturnType<typeof setTimeout>
  private reminders: Array<ReturnType<typeof setTimeout>> = []

  disconnect(): void {
    clearTimeout(this.waiting)
    this.clearReminders()
  }

  say(text: string): void {
    writeText(this.element, text)
  }

  own(): void {
    this.quietUntil = Date.now() + OWN_BID_QUIET_MS
  }

  observe(next: StatusLine | null, outcome: string | null): void {
    const previous = this.line
    this.line = next
    const first = !this.seen
    this.seen = true
    this.clearReminders()
    if (next === null) {
      if (outcome && !this.ended) this.post(outcome, "end")
      this.ended = this.ended || outcome !== null
      return
    }
    if (!first) this.post(next.text, previous && previous.endsAt !== next.endsAt ? "extension" : "update")
    if (next.bidder) this.remind(next.endsAt)
  }

  private post(text: string, kind: StatusKind): void {
    if (kind === "update" && Date.now() < this.quietUntil) {
      this.throttle = { ...this.throttle, lastText: text, waiting: null }
      return
    }
    this.apply(offer(this.throttle, text, kind, Date.now(), motionReduced()))
  }

  private apply({ throttle, say, wait }: ReturnType<typeof offer>): void {
    this.throttle = throttle
    if (say !== null) this.say(say)
    if (throttle.waiting === null) clearTimeout(this.waiting)
    else if (wait !== null) this.waiting = setTimeout(() => this.apply(flush(this.throttle, Date.now())), wait)
  }

  private remind(endsAt: string): void {
    this.reminders = milestones(endsAt, Date.now()).map((delay) =>
      setTimeout(() => this.post(this.line?.text ?? "", "milestone"), delay),
    )
  }

  private clearReminders(): void {
    for (const reminder of this.reminders) clearTimeout(reminder)
    this.reminders = []
  }
}
