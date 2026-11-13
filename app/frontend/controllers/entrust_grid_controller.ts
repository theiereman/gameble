import { Controller } from "@hotwired/stimulus"
import { keepStepperFocus, quantityFromButton, quantityFromKey, reflectStepper, STEPPER } from "../lib/stepper"
import { columnsOf } from "../lib/grid_keys"
import { writeAttribute, writeDisabled, writeFlag, writeHidden } from "../lib/dom_writes"
import { sameCell, type CellView, type GridView } from "../lib/entrust_view"

export type MoveIntent = { key: string; columns: number }

const TOGGLE = ".entrust-cell__toggle"
const BUMP_STEP: Record<string, number> = { "+": 1, "=": 1, "-": -1, _: -1 }

export default class EntrustGridController extends Controller<HTMLElement> {
  static targets = ["list", "cell", "selectAll", "failed"]

  declare readonly listTarget: HTMLUListElement
  declare readonly cellTargets: HTMLElement[]
  declare readonly hasSelectAllTarget: boolean
  declare readonly selectAllTarget: HTMLButtonElement
  declare readonly hasFailedTarget: boolean
  declare readonly failedTarget: HTMLElement

  private drawn = new WeakMap<Element, CellView>()

  // Only a cell that just connected or whose view changed is touched: a grid of loaded pages holds thousands.
  render({ cells, selecting }: GridView): void {
    for (const cell of this.cellTargets) {
      const view = cells.get(cell.dataset.ref ?? "")
      if (!view || sameCell(this.drawn.get(cell), view)) continue
      this.reflectCell(cell, view)
      this.drawn.set(cell, view)
    }
    if (this.hasSelectAllTarget) {
      writeDisabled(this.selectAllTarget, selecting === "loading")
      writeFlag(this.selectAllTarget, "aria-busy", selecting === "loading")
    }
    if (this.hasFailedTarget) writeHidden(this.failedTarget, selecting !== "failed")
  }

  focusActive(): void {
    this.listTarget.querySelector<HTMLElement>(`${TOGGLE}[tabindex="0"]`)?.focus()
  }

  toggle(event: Event): void {
    const ref = this.refOf(event)
    if (ref) this.dispatch("toggle", { detail: { ref } })
  }

  selectAll(): void {
    const url = this.hasSelectAllTarget ? this.selectAllTarget.dataset.url : undefined
    if (url) this.dispatch("select", { detail: { url } })
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
    const detail: MoveIntent = { key: event.key, columns: columnsOf(this.firstRowTops()) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  clear(): void {
    this.dispatch("clear")
  }

  // The tops up to the first cell of the second row, enough to count the columns.
  private firstRowTops(): number[] {
    const tops: number[] = []
    for (const cell of this.cellTargets) {
      tops.push(cell.offsetTop)
      if (cell.offsetTop !== tops[0]) break
    }
    return tops
  }

  private reflectCell(cell: HTMLElement, { ticked, tabbable, stepper }: CellView): void {
    cell.classList.toggle("entrust-cell--picked", ticked)
    writeHidden(cell.querySelector<HTMLElement>(".entrust-cell__check"), !ticked)
    const toggle = cell.querySelector<HTMLElement>(TOGGLE)
    if (toggle) {
      writeAttribute(toggle, "tabindex", tabbable ? "0" : "-1")
      writeAttribute(toggle, "aria-pressed", String(ticked))
    }
    const spinner = cell.querySelector<HTMLElement>(STEPPER)
    if (spinner) {
      writeHidden(spinner, stepper === null)
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
