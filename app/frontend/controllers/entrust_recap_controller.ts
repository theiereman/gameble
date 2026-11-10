import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { drawAmount, type AmountForms, type LineView, type RecapView } from "../lib/entrust_view"
import { litSegments } from "../lib/gauge"
import { cloneFirstElement } from "../lib/templates"

export const STATUS_DELAY = 500

export default class EntrustRecapController extends Controller<HTMLElement> {
  static targets = [
    "prompt",
    "lines",
    "lineTemplate",
    "amountTemplate",
    "total",
    "segment",
    "capText",
    "over",
    "full",
    "rare",
    "sentence",
    "submitSlot",
    "status",
  ]
  static values = { locale: String, accessible: String }

  declare readonly promptTarget: HTMLElement
  declare readonly linesTarget: HTMLElement
  declare readonly lineTemplateTarget: HTMLTemplateElement
  declare readonly amountTemplateTarget: HTMLTemplateElement
  declare readonly totalTarget: HTMLElement
  declare readonly segmentTargets: HTMLElement[]
  declare readonly capTextTarget: HTMLElement
  declare readonly overTarget: HTMLElement
  declare readonly fullTarget: HTMLElement
  declare readonly rareTarget: HTMLElement
  declare readonly sentenceTarget: HTMLElement
  declare readonly submitSlotTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly localeValue: string
  declare readonly accessibleValue: string

  private posted?: string
  private waiting?: string
  private timer?: ReturnType<typeof setTimeout>

  disconnect(): void {
    clearTimeout(this.timer)
  }

  render(view: RecapView): void {
    this.promptTarget.hidden = !view.prompt
    this.linesTarget.hidden = view.prompt
    this.linesTarget.replaceChildren(...view.lines.map((line) => this.lineFrom(line)))
    drawAmount(this.totalTarget, view.received, this.forms())
    const lit = litSegments(view.capUsed, view.capTotal, this.segmentTargets.length)
    this.segmentTargets.forEach((segment, index) => segment.classList.toggle("gauge__segment--lit", index < lit))
    writeText(this.capTextTarget, view.capText)
    this.reflectNote(this.overTarget, view.over)
    this.reflectNote(this.rareTarget, view.rare)
    this.fullTarget.hidden = !view.full
    this.reflectSubmit(view)
    this.postStatus(view.status)
  }

  private forms(): AmountForms {
    return { locale: this.localeValue, accessible: this.accessibleValue }
  }

  private reflectNote(note: HTMLElement, text: string | null): void {
    note.hidden = text === null
    if (text !== null) writeText(note, text)
  }

  private reflectSubmit({ label, disabled }: RecapView): void {
    const button = this.submitSlotTarget.querySelector<HTMLButtonElement>("button")
    if (!button) return
    writeText(button, label)
    button.disabled = disabled
    const described = [this.sentenceTarget, ...(this.rareTarget.hidden ? [] : [this.rareTarget])]
    button.setAttribute("aria-describedby", described.map((note) => note.id).join(" "))
  }

  private lineFrom(line: LineView): HTMLElement {
    const item = cloneFirstElement<HTMLElement>(this.lineTemplateTarget)!
    item.dataset.ref = line.ref
    item.dataset.state = line.state
    writeText(item.querySelector(".entrust-recap__name"), line.label)
    writeText(item.querySelector(".entrust-recap__count"), line.count)
    const slot = item.querySelector<HTMLElement>(".entrust-recap__amount")
    const amount = line.amount === null ? null : cloneFirstElement<HTMLElement>(this.amountTemplateTarget)
    if (slot && amount && line.amount !== null) {
      drawAmount(amount, line.amount, this.forms())
      slot.append(amount)
    } else slot?.remove()
    const stays = item.querySelector<HTMLElement>(".entrust-recap__stays")
    if (stays) {
      stays.hidden = line.stays === null
      if (line.stays !== null) writeText(stays, line.stays)
    }
    return item
  }

  // One short status after the selection rests, never the same text twice, never a move of focus.
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
