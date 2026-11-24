import { Controller } from "@hotwired/stimulus"
import { LIVE_DELAY } from "../lib/annonce"
import { writeText } from "../lib/dom_writes"
import type { Field } from "../lib/listing_form"
import type { FieldsView, FieldView } from "../lib/listing_form_view"

const START_HINT = "sale-start-hint"

export default class ListingFieldsController extends Controller<HTMLElement> {
  static targets = [
    "start",
    "duration",
    "hint",
    "startError",
    "durationError",
    "priceSlot",
    "orderSlot",
    "ordersSlot",
    "openingLine",
    "leftLine",
    "status",
    "orderRefusal",
  ]

  declare readonly startTarget: HTMLInputElement
  declare readonly durationTargets: HTMLInputElement[]
  declare readonly hintTarget: HTMLElement
  declare readonly startErrorTarget: HTMLElement
  declare readonly durationErrorTarget: HTMLElement
  declare readonly hasPriceSlotTarget: boolean
  declare readonly priceSlotTarget: HTMLElement
  declare readonly hasOrderSlotTarget: boolean
  declare readonly orderSlotTarget: HTMLElement
  declare readonly hasOrdersSlotTarget: boolean
  declare readonly ordersSlotTarget: HTMLElement
  declare readonly openingLineTarget: HTMLElement
  declare readonly leftLineTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly hasOrderRefusalTarget: boolean
  declare readonly orderRefusalTarget: HTMLElement

  private pristine = true
  private timer?: ReturnType<typeof setTimeout>

  connect(): void {
    if (this.hasOrderRefusalTarget) this.orderRefusalTarget.focus()
  }

  disconnect(): void {
    clearTimeout(this.timer)
  }

  render({ hint, startText, opening, left, start, duration, locked }: FieldsView): void {
    writeText(this.hintTarget, hint)
    if (this.startTarget.value !== startText) this.startTarget.value = startText
    this.reflectLine(this.openingLineTarget, opening)
    this.reflectLine(this.leftLineTarget, left)
    this.announce([opening, left].filter(Boolean).join(" "))
    this.reflectField(this.startTarget, this.startErrorTarget, start, START_HINT)
    this.reflectDuration(duration)
    this.element.toggleAttribute("inert", locked)
  }

  focusField(field: Field): void {
    if (field === "start") this.startTarget.focus()
  }

  focusDuration(): void {
    const radios = this.durationTargets
    ;(radios.find((radio) => radio.checked) ?? radios[0])?.focus()
  }

  type(event: Event): void {
    this.pristine = false
    const input = event.currentTarget as HTMLInputElement
    this.dispatch("typed", { detail: { field: "start", value: input.value } })
  }

  pick(event: Event): void {
    this.pristine = false
    this.dispatch("duration", { detail: { hours: (event.currentTarget as HTMLInputElement).value } })
  }

  keydown(event: KeyboardEvent): void {
    if (event.key !== "Enter") return
    event.preventDefault()
    const field = event.currentTarget === this.startTarget ? "start" : "duration"
    this.dispatch("entered", { detail: { field } })
  }

  back(): void {
    this.dispatch("back")
  }

  // The chosen edition's price, drawn from its cell's template; one already drawn stays when its cell is gone.
  showPrice(ref: string, template: HTMLTemplateElement | null): void {
    if (this.hasPriceSlotTarget) this.showIn(this.priceSlotTarget, ref, template)
  }

  // The best order waiting for the chosen edition, or the line saying there is none, as the price.
  showOrder(ref: string, template: HTMLTemplateElement | null): void {
    if (this.hasOrderSlotTarget) this.showIn(this.orderSlotTarget, ref, template)
  }

  // Every eligible buy order of the chosen edition, said above the start field.
  showOrders(ref: string, template: HTMLTemplateElement | null): void {
    if (this.hasOrdersSlotTarget) this.showIn(this.ordersSlotTarget, ref, template)
  }

  private announce(text: string): void {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => writeText(this.statusTarget, text), LIVE_DELAY)
  }

  private reflectLine(line: HTMLElement, text: string): void {
    line.hidden = text === ""
    writeText(line, text)
  }

  private showIn(slot: HTMLElement, ref: string, template: HTMLTemplateElement | null): void {
    if (slot.dataset.ref === ref) return
    slot.dataset.ref = ref
    slot.replaceChildren(...(template ? [template.content.cloneNode(true)] : []))
  }

  private reflectField(input: HTMLInputElement, error: HTMLElement, { error: text }: FieldView, hintId?: string): void {
    if (text === null && this.pristine) return
    error.hidden = text === null
    writeText(error, text ?? "")
    if (text === null) input.removeAttribute("aria-invalid")
    else input.setAttribute("aria-invalid", "true")
    const ids = [hintId, text === null ? undefined : error.id].filter(Boolean)
    if (ids.length > 0) input.setAttribute("aria-describedby", ids.join(" "))
    else input.removeAttribute("aria-describedby")
  }

  private reflectDuration(duration: string): void {
    for (const radio of this.durationTargets) radio.checked = radio.value === duration
    if (!this.pristine) {
      this.durationErrorTarget.hidden = true
      writeText(this.durationErrorTarget, "")
    }
  }
}
