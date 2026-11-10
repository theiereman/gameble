import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"
import { writeText } from "../lib/dom_writes"

export type DialogTexts = { amount?: string; multiple?: string }

export default class AnnonceDialogController extends Controller<HTMLDialogElement> {
  static targets = ["amount", "multiple"]
  static values = { kind: String }

  declare readonly amountTargets: HTMLElement[]
  declare readonly multipleTargets: HTMLElement[]
  declare readonly kindValue: string

  get kind(): string {
    return this.kindValue
  }

  open(opener: HTMLElement, { amount, multiple }: DialogTexts = {}): void {
    if (amount !== undefined) for (const target of this.amountTargets) writeText(target, amount)
    if (multiple !== undefined) for (const target of this.multipleTargets) writeText(target, multiple)
    openDialog(this.element, opener)
  }

  close(): void {
    if (this.element.open) this.element.close()
  }

  confirm(): void {
    this.dispatch("confirmed")
  }
}
