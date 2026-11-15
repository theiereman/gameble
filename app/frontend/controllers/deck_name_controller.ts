import { Controller } from "@hotwired/stimulus"
import { writeText, writeValue } from "../lib/dom_writes"

export type NameView = { name: string; refusal: string | null }

export default class DeckNameController extends Controller<HTMLElement> {
  static targets = ["input", "refusal"]

  declare readonly inputTarget: HTMLInputElement
  declare readonly refusalTarget: HTMLElement

  render({ name, refusal }: NameView): void {
    if (refusal !== null || document.activeElement !== this.inputTarget) writeValue(this.inputTarget, name)
    writeText(this.refusalTarget, refusal ?? "")
  }

  commit(event: Event): void {
    if (event instanceof KeyboardEvent) event.preventDefault()
    this.dispatch("rename", { detail: { name: this.inputTarget.value } })
  }
}
