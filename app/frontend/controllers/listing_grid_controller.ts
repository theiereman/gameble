import { Controller } from "@hotwired/stimulus"
import { columnsOf, nextIndex } from "../lib/grid_keys"
import type { CellView, GridView } from "../lib/listing_form_view"

const CELL = ".sale-cell"

export default class ListingGridController extends Controller<HTMLElement> {
  static targets = ["cell", "ref"]

  declare readonly cellTargets: HTMLElement[]
  declare readonly refTarget: HTMLInputElement

  render({ cells, chosen }: GridView): void {
    const byRef = new Map(this.cellTargets.map((cell) => [cell.dataset.ref ?? "", cell]))
    for (const view of cells) {
      const cell = byRef.get(view.ref)
      if (cell) this.reflectCell(cell, view)
    }
    if (this.refTarget.value !== chosen) this.refTarget.value = chosen
  }

  focusChosen(): void {
    this.element.querySelector<HTMLElement>(`${CELL}[tabindex="0"]`)?.focus()
  }

  choose(event: Event): void {
    this.pick(event.currentTarget instanceof HTMLElement ? event.currentTarget : null)
  }

  // Arrow keys only move focus; Space or Enter chooses.
  keydown(event: KeyboardEvent): void {
    const cell = event.target instanceof Element ? event.target.closest<HTMLElement>(CELL) : null
    if (!cell) return
    if (event.key === " " || event.key === "Enter") {
      event.preventDefault()
      this.pick(cell)
      return
    }
    const index = this.cellTargets.indexOf(cell)
    const columns = columnsOf(this.cellTargets.map((each) => each.offsetTop))
    const target = nextIndex(event.key, index, this.cellTargets.length, columns)
    if (target === null) return
    event.preventDefault()
    this.moveFocus(this.cellTargets[target])
  }

  private moveFocus(cell: HTMLElement | undefined): void {
    if (!cell) return
    for (const each of this.cellTargets) each.tabIndex = each === cell ? 0 : -1
    cell.focus()
  }

  private reflectCell(cell: HTMLElement, { chosen, tabbable }: CellView): void {
    cell.setAttribute("aria-selected", String(chosen))
    cell.classList.toggle("sale-cell--chosen", chosen)
    cell.tabIndex = tabbable ? 0 : -1
    const check = cell.querySelector<HTMLElement>(".sale-cell__check")
    if (check) check.hidden = !chosen
  }

  private pick(cell: HTMLElement | null): void {
    const ref = cell?.dataset.ref
    if (ref) this.dispatch("chosen", { detail: { ref } })
  }
}
