import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import type { Layout } from "../lib/entrust"
import { drawAmount, type AmountForms, type LineView, type RecapView } from "../lib/entrust_view"
import { litSegments, segmentSteps } from "../lib/gauge"
import { motionReduced } from "../lib/motion"
import { keepStepperFocus, quantityFromButton, quantityFromKey, reflectStepper, STEPPER } from "../lib/stepper"
import { cloneFirstElement } from "../lib/templates"

export const STATUS_DELAY = 500
export const GROW_HOLD = 300
export const GROW_STEP = 45

type Reading = { used: number; all: number }

const LINE = ".entrust-recap__line"
const STEPPER_SLOT = ".entrust-recap__stepper"

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
    "barStatus",
    "aside",
    "slot",
    "sheetBody",
    "barCount",
    "barTotal",
    "stepperTemplate",
  ]
  static values = { locale: String, accessible: String, reasonId: String }

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
  declare readonly barStatusTarget: HTMLElement
  declare readonly asideTarget: HTMLElement
  declare readonly slotTarget: HTMLElement
  declare readonly sheetBodyTarget: HTMLElement
  declare readonly barCountTarget: HTMLElement
  declare readonly barTotalTarget: HTMLElement
  declare readonly stepperTemplateTarget: HTMLTemplateElement
  declare readonly localeValue: string
  declare readonly accessibleValue: string
  declare readonly reasonIdValue: string

  private layout: Layout = "wide"
  private posted?: string
  private waiting?: string
  private timer?: ReturnType<typeof setTimeout>
  private reading: Reading = { used: 0, all: 0 }
  private capTotal = 0
  private growTimer?: ReturnType<typeof setTimeout>
  private growing = false

  disconnect(): void {
    clearTimeout(this.timer)
    this.stopGrowth()
  }

  growFrom(mintedBefore: number): void {
    if (motionReduced()) return
    const from = litSegments(mintedBefore, this.capTotal, this.segmentTargets.length)
    const steps = segmentSteps(from, this.reading.used)
    if (steps.length < 2) return
    this.stopGrowth()
    this.growing = true
    this.gauge()?.setAttribute("data-growing", "")
    const selection = this.reading.all - this.reading.used
    const show = (index: number): void => {
      const used = steps[index] ?? from
      this.lightSegments({ used, all: used + selection }, from)
      if (index < steps.length - 1)
        this.growTimer = setTimeout(() => show(index + 1), index === 0 ? GROW_HOLD : GROW_STEP)
      else this.stopGrowth()
    }
    show(0)
  }

  place(layout: Layout): void {
    this.layout = layout
    ;(layout === "phone" ? this.sheetBodyTarget : this.slotTarget).append(this.asideTarget)
  }

  placedIn(): "sheet" | "slot" {
    return this.asideTarget.parentElement === this.sheetBodyTarget ? "sheet" : "slot"
  }

  sheetIsOpen(): boolean {
    return this.sheetBodyTarget.closest("dialog")?.open === true
  }

  // The status follows the sheet: a dialog that opens or closes announces the current text at once.
  refreshStatus(): void {
    if (this.posted === undefined) return
    this.writeStatus(this.posted)
  }

  step(event: Event): void {
    this.report(event, quantityFromButton(event))
  }

  stepperKey(event: KeyboardEvent): void {
    this.report(event, quantityFromKey(event))
  }

  keepFocus(event: Event): void {
    keepStepperFocus(event)
  }

  render(view: RecapView): void {
    this.promptTarget.hidden = !view.prompt
    this.linesTarget.hidden = view.prompt
    this.reconcile(view.lines)
    drawAmount(this.totalTarget, view.received, this.forms())
    drawAmount(this.barTotalTarget, view.bar.amount, this.forms())
    writeText(this.barCountTarget, view.bar.count)
    this.reflectGauge(view)
    writeText(this.capTextTarget, view.capText)
    this.reflectNote(this.overTarget, view.over)
    this.reflectNote(this.rareTarget, view.rare)
    this.fullTarget.hidden = !view.full
    this.reflectSubmit(view)
    this.postStatus(view.status)
  }

  private reflectGauge({ capBefore, capUsed, capTotal }: RecapView): void {
    const segments = this.segmentTargets.length
    const reading = { used: litSegments(capBefore, capTotal, segments), all: litSegments(capUsed, capTotal, segments) }
    const unchanged = reading.used === this.reading.used && reading.all === this.reading.all
    this.reading = reading
    this.capTotal = capTotal
    if (this.growing && unchanged) return
    this.stopGrowth()
  }

  private lightSegments({ used, all }: Reading, fresh = used): void {
    this.segmentTargets.forEach((segment, index) => {
      segment.classList.toggle("gauge__segment--lit", index < all)
      segment.classList.toggle("gauge__segment--selected", index >= used && index < all)
      segment.classList.toggle("gauge__segment--fresh", index >= fresh && index < used)
    })
  }

  private gauge(): HTMLElement | null {
    return this.segmentTargets[0]?.parentElement ?? null
  }

  private stopGrowth(): void {
    clearTimeout(this.growTimer)
    this.growTimer = undefined
    this.growing = false
    this.gauge()?.removeAttribute("data-growing")
    this.lightSegments(this.reading)
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
    const described = [this.sentenceTarget, ...(this.rareTarget.hidden ? [] : [this.rareTarget])].map((note) => note.id)
    if (this.reasonIdValue && document.getElementById(this.reasonIdValue)) described.push(this.reasonIdValue)
    button.setAttribute("aria-describedby", described.join(" "))
  }

  // Lines are matched by ref and never rebuilt, so a pressed stepper keeps its node and its focus.
  private reconcile(views: readonly LineView[]): void {
    const list = this.linesTarget
    const wanted = new Set(views.map((view) => view.ref))
    const byRef = new Map<string, HTMLElement>()
    for (const line of Array.from(list.querySelectorAll<HTMLElement>(`:scope > ${LINE}`))) {
      if (wanted.has(line.dataset.ref ?? "")) byRef.set(line.dataset.ref ?? "", line)
      else line.remove()
    }
    let expected = list.firstElementChild
    for (const view of views) {
      const line = byRef.get(view.ref) ?? cloneFirstElement<HTMLElement>(this.lineTemplateTarget)!
      if (line === expected) expected = expected.nextElementSibling
      else list.insertBefore(line, expected)
      this.reflectLine(line, view)
    }
  }

  private reflectLine(line: HTMLElement, view: LineView): void {
    line.dataset.ref = view.ref
    line.dataset.state = view.state
    writeText(line.querySelector(".entrust-recap__name"), view.label)
    writeText(line.querySelector(".entrust-recap__count"), view.count)
    this.reflectAmount(line.querySelector<HTMLElement>(".entrust-recap__amount"), view.amount)
    const stays = line.querySelector<HTMLElement>(".entrust-recap__stays")
    if (stays) {
      stays.hidden = view.stays === null
      if (view.stays !== null) writeText(stays, view.stays)
    }
    this.reflectLineStepper(line, view)
  }

  private reflectAmount(slot: HTMLElement | null, amount: number | null): void {
    if (!slot) return
    if (amount === null) {
      if (slot.firstElementChild) slot.replaceChildren()
      return
    }
    const drawn = slot.firstElementChild ?? cloneFirstElement<HTMLElement>(this.amountTemplateTarget)
    if (!drawn) return
    drawAmount(drawn, amount, this.forms())
    if (!drawn.parentElement) slot.append(drawn)
  }

  private reflectLineStepper(line: HTMLElement, { stepper }: LineView): void {
    let holder = line.querySelector<HTMLElement>(STEPPER_SLOT)
    if (stepper === null) {
      holder?.remove()
      return
    }
    if (!holder) {
      holder = cloneFirstElement<HTMLElement>(this.stepperTemplateTarget)
      if (!holder) return
      const stays = line.querySelector(".entrust-recap__stays")
      if (stays) stays.before(holder)
      else line.append(holder)
    }
    const spinner = holder.querySelector<HTMLElement>(STEPPER)
    if (spinner) reflectStepper(spinner, stepper)
  }

  private report(event: Event, copies: number | null): void {
    const ref = (event.currentTarget as Element).closest<HTMLElement>(LINE)?.dataset.ref
    if (ref && copies !== null) this.dispatch("copies", { detail: { ref, copies } })
  }

  private writeStatus(text: string): void {
    const phoneBar = this.layout === "phone" && !this.sheetIsOpen()
    const [active, other] = phoneBar
      ? [this.barStatusTarget, this.statusTarget]
      : [this.statusTarget, this.barStatusTarget]
    writeText(active, text)
    writeText(other, "")
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
      this.writeStatus(this.waiting ?? "")
    }, STATUS_DELAY)
  }
}
