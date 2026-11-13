import { Controller } from "@hotwired/stimulus"
import { editOf, regroup } from "../lib/amount"

export default class AmountFieldController extends Controller<HTMLInputElement> {
  private before = ""

  connect(): void {
    this.before = this.element.value
  }

  remember(): void {
    this.before = this.element.value
  }

  group(event: Event): void {
    if ((event as InputEvent).isComposing) return
    const input = this.element
    const typed = { text: input.value, caret: input.selectionStart ?? input.value.length }
    const grouped = regroup(typed, this.before, editOf((event as InputEvent).inputType), this.locale)
    if (grouped) {
      if (grouped.text !== input.value) input.value = grouped.text
      if (document.activeElement === input && grouped.caret !== typed.caret)
        input.setSelectionRange(grouped.caret, grouped.caret)
    }
    this.before = input.value
  }

  private get locale(): string {
    return document.documentElement.lang
  }
}
