import { Controller } from "@hotwired/stimulus"
import { writeHidden, writeText } from "../lib/dom_writes"
import { drawAmount, type AmountForms } from "../lib/entrust_view"
import { t } from "../lib/i18n"
import { picoins } from "../lib/picoins"
import type { Totals } from "../lib/wanted_table"
import type { WantedStrings } from "./wanted_table_controller"

export const STATUS_DELAY = 500

export default class WantedDockController extends Controller<HTMLElement> {
  static targets = [
    "now",
    "salesPart",
    "salesCount",
    "salesAmount",
    "entrustedPart",
    "entrustedCount",
    "entrustedAmount",
    "listedCount",
    "listedAmount",
    "stamps",
    "over",
    "refusal",
    "status",
  ]
  static values = { locale: String, accessible: String }

  declare readonly nowTarget: HTMLElement
  declare readonly salesPartTarget: HTMLElement
  declare readonly salesCountTarget: HTMLElement
  declare readonly salesAmountTarget: HTMLElement
  declare readonly entrustedPartTarget: HTMLElement
  declare readonly entrustedCountTarget: HTMLElement
  declare readonly entrustedAmountTarget: HTMLElement
  declare readonly listedCountTarget: HTMLElement
  declare readonly listedAmountTarget: HTMLElement
  declare readonly stampsTarget: HTMLElement
  declare readonly overTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly hasRefusalTarget: boolean
  declare readonly refusalTarget: HTMLElement
  declare readonly localeValue: string
  declare readonly accessibleValue: string

  private posted?: string
  private waiting?: string
  private timer?: ReturnType<typeof setTimeout>

  // A refused validation's line is read out once the redrawn table settles.
  connect(): void {
    const refusal =
      this.hasRefusalTarget && !this.refusalTarget.hidden ? (this.refusalTarget.textContent ?? "").trim() : ""
    if (refusal) this.timer = setTimeout(() => writeText(this.statusTarget, refusal), STATUS_DELAY)
  }

  disconnect(): void {
    clearTimeout(this.timer)
  }

  render(sums: Totals, strings: WantedStrings): void {
    const forms = this.forms()
    drawAmount(this.nowTarget, sums.now, forms)
    writeHidden(this.salesPartTarget, sums.sales === 0)
    writeText(this.salesCountTarget, t(strings.sales, { count: sums.sales }))
    drawAmount(this.salesAmountTarget, sums.salesAmount, forms)
    writeHidden(this.entrustedPartTarget, sums.entrusted === 0)
    writeText(this.entrustedCountTarget, t(strings.entrusted, { count: sums.entrusted }))
    drawAmount(this.entrustedAmountTarget, sums.entrustedAmount, forms)
    writeText(this.listedCountTarget, t(strings.listed, { count: sums.listed }))
    drawAmount(this.listedAmountTarget, sums.listedAmount, forms)
    drawAmount(this.stampsTarget, sums.stamps, forms)
    writeHidden(this.overTarget, sums.over === 0)
    if (sums.over > 0)
      writeText(this.overTarget, t(strings.overCap, { count: sums.over, cards: sums.overTitles.join(", ") }))
    const all = this.element.querySelector(".wanted-dock__all button")
    writeText(all, t(strings.allEntrust, { amount: picoins(sums.allEntrust, { locale: this.localeValue }) }))
    this.postStatus(
      t(strings.status, {
        amount: t(this.accessibleValue, { amount: picoins(sums.now, { locale: this.localeValue }) }),
      }),
    )
  }

  private forms(): AmountForms {
    return { locale: this.localeValue, accessible: this.accessibleValue }
  }

  // One short status after the choices rest, never the same text twice, never a move of focus.
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
