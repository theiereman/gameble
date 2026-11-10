import { Controller } from "@hotwired/stimulus"
import { keepStepperFocus, quantityFromButton, quantityFromKey, reflectStepper, STEPPER } from "../lib/stepper"
import { columnsOf } from "../lib/grid_keys"
import type { CellView, GridView } from "../lib/entrust_view"

export type MoveIntent = { key: string; columns: number }

const TOGGLE = ".entrust-cell__toggle"
const BUMP_STEP: Record<string, number> = { "+": 1, "=": 1, "-": -1, _: -1 }

export default class EntrustGridController extends Controller<HTMLElement> {
  static targets = ["list", "cell", "empty"]

  declare readonly listTarget: HTMLUListElement
  declare readonly cellTargets: HTMLElement[]
  declare readonly emptyTarget: HTMLElement

  render({ cells, matchless }: GridView): void {
    const byRef = new Map(this.cellTargets.map((cell) => [cell.dataset.ref ?? "", cell]))
    for (const view of cells) {
      const cell = byRef.get(view.ref)
      if (cell) this.reflectCell(cell, view)
    }
    this.emptyTarget.hidden = !matchless
    this.listTarget.hidden = matchless
  }

  focusActive(): void {
    this.listTarget.querySelector<HTMLElement>(`${TOGGLE}[tabindex="0"]`)?.focus()
  }

  toggle(event: Event): void {
    const ref = this.refOf(event)
    if (ref) this.dispatch("toggle", { detail: { ref } })
  }

  stepperKey(event: KeyboardEvent): void {
    this.report(event, quantityFromKey(event))
  }

  step(event: Event): void {
    this.report(event, quantityFromButton(event))
  }

  keepFocus(event: Event): void {
    keepStepperFocus(event)
  }

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof Element) || !event.target.matches(TOGGLE)) return
    const ref = event.target.closest<HTMLElement>(".entrust-cell")?.dataset.ref
    const step = BUMP_STEP[event.key]
    if (step !== undefined) {
      if (ref) this.dispatch("bump", { detail: { ref, step } })
      return
    }
    const tops = this.cellTargets.filter((cell) => !cell.hidden).map((cell) => cell.offsetTop)
    const detail: MoveIntent = { key: event.key, columns: columnsOf(tops) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  clear(): void {
    this.dispatch("clear")
  }

  private reflectCell(cell: HTMLElement, { shown, ticked, tabbable, copies, stepper }: CellView): void {
    cell.hidden = !shown
    cell.classList.toggle("entrust-cell--picked", ticked)
    const check = cell.querySelector<HTMLElement>(".entrust-cell__check")
    if (check) check.hidden = !ticked
    const toggle = cell.querySelector<HTMLElement>(TOGGLE)
    if (toggle) {
      toggle.tabIndex = tabbable ? 0 : -1
      toggle.setAttribute("aria-pressed", String(ticked))
    }
    const input = cell.querySelector<HTMLInputElement>("input[name]")
    if (input) {
      input.disabled = !ticked
      input.value = String(copies)
    }
    const spinner = cell.querySelector<HTMLElement>(STEPPER)
    if (spinner) {
      spinner.hidden = stepper === null
      if (stepper) reflectStepper(spinner, stepper)
    }
  }

  private report(event: Event, copies: number | null): void {
    const ref = this.refOf(event)
    if (ref && copies !== null) this.dispatch("copies", { detail: { ref, copies } })
  }

  private refOf(event: Event): string | undefined {
    return (event.currentTarget as Element).closest<HTMLElement>(".entrust-cell")?.dataset.ref
  }
}
