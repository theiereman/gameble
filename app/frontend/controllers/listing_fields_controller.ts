import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import type { Field } from "../lib/listing_form"
import type { FieldsView, FieldView } from "../lib/listing_form_view"

const START_HINT = "sale-start-hint"

export default class ListingFieldsController extends Controller<HTMLElement> {
  static targets = ["start", "duration", "hint", "startError", "durationError", "priceSlot"]

  declare readonly startTarget: HTMLInputElement
  declare readonly durationTargets: HTMLInputElement[]
  declare readonly hintTarget: HTMLElement
  declare readonly startErrorTarget: HTMLElement
  declare readonly durationErrorTarget: HTMLElement
  declare readonly hasPriceSlotTarget: boolean
  declare readonly priceSlotTarget: HTMLElement

  private pristine = true

  render({ hint, start, duration, locked }: FieldsView): void {
    writeText(this.hintTarget, hint)
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
    if (!this.hasPriceSlotTarget || this.priceSlotTarget.dataset.ref === ref) return
    this.priceSlotTarget.dataset.ref = ref
    this.priceSlotTarget.replaceChildren(...(template ? [template.content.cloneNode(true)] : []))
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
