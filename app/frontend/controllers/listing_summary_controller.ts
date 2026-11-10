import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import type { SummaryView } from "../lib/listing_form_view"
import { drawAmount } from "../lib/entrust_view"
import { STATUS_DELAY } from "./entrust_recap_controller"

export default class ListingSummaryController extends Controller<HTMLElement> {
  static targets = ["stamp", "commission", "received", "submitStamp", "status"]
  static values = { locale: String, accessible: String }

  declare readonly stampTarget: HTMLElement
  declare readonly commissionTarget: HTMLElement
  declare readonly receivedTarget: HTMLElement
  declare readonly submitStampTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly localeValue: string
  declare readonly accessibleValue: string

  private posted?: string
  private waiting?: string
  private timer?: ReturnType<typeof setTimeout>

  disconnect(): void {
    clearTimeout(this.timer)
  }

  render({ stamp, commission, received, disabled, status }: SummaryView): void {
    this.reflectAmount(this.stampTarget, stamp)
    this.reflectAmount(this.submitStampTarget, stamp)
    this.reflectAmount(this.commissionTarget, commission)
    this.reflectAmount(this.receivedTarget, received)
    const button = this.element.querySelector<HTMLButtonElement>("button[type=submit]")
    if (button) button.disabled = disabled
    this.postStatus(status)
  }

  focusSubmit(): void {
    this.element.querySelector<HTMLButtonElement>("button[type=submit]")?.focus()
  }

  private reflectAmount(node: HTMLElement, amount: number | null): void {
    node.hidden = amount === null
    if (amount !== null) drawAmount(node, amount, { locale: this.localeValue, accessible: this.accessibleValue })
  }

  // One short status after the amounts rest, never the same text twice, never a move of focus.
  private postStatus(text: string): void {
    if (this.posted === undefined) {
      this.posted = text
      this.waiting = text
      return
    }
    if (text === this.waiting) return
    this.waiting = text
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      if (this.waiting === this.posted) return
      this.posted = this.waiting
      writeText(this.statusTarget, this.waiting ?? "")
    }, STATUS_DELAY)
  }
}
