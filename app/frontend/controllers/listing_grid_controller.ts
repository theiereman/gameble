import { Controller } from "@hotwired/stimulus"
import { writeAttribute, writeHidden } from "../lib/dom_writes"
import { columnsOf, nextIndex } from "../lib/grid_keys"
import type { CellView, GridView } from "../lib/listing_form_view"

const CELL = ".sale-cell"

export default class ListingGridController extends Controller<HTMLElement> {
  static targets = ["cell"]

  declare readonly cellTargets: HTMLElement[]

  render({ cells }: GridView): void {
    const byRef = new Map(this.cellTargets.map((cell) => [cell.dataset.ref ?? "", cell]))
    for (const view of cells) {
      const cell = byRef.get(view.ref)
      if (cell) this.reflectCell(cell, view)
    }
  }

  focusChosen(): void {
    this.element.querySelector<HTMLElement>(`${CELL}[tabindex="0"]`)?.focus()
  }

  choose(event: Event): void {
    this.pick(event.currentTarget instanceof HTMLElement ? event.currentTarget : null)
  }

  clear(): void {
    this.dispatch("clear")
  }

  keydown(event: KeyboardEvent): void {
    const cell = event.target instanceof Element ? event.target.closest<HTMLElement>(CELL) : null
    if (!cell) return
    if (event.key === " " || event.key === "Enter") {
      event.preventDefault()
      this.pick(cell)
      return
    }
    const cells = this.cellTargets
    const target = nextIndex(event.key, cells.indexOf(cell), cells.length, columnsOf(this.firstRowTops(cells)))
    if (target === null) return
    event.preventDefault()
    this.moveFocus(cell, cells[target])
  }

  // The tops up to the first cell of the second row, enough to count the columns.
  private firstRowTops(cells: readonly HTMLElement[]): number[] {
    const tops: number[] = []
    for (const cell of cells) {
      tops.push(cell.offsetTop)
      if (cell.offsetTop !== tops[0]) break
    }
    return tops
  }

  private moveFocus(from: HTMLElement, to: HTMLElement | undefined): void {
    if (!to || to === from) return
    from.tabIndex = -1
    to.tabIndex = 0
    to.focus()
  }

  private reflectCell(cell: HTMLElement, { chosen, tabbable }: CellView): void {
    writeAttribute(cell, "aria-selected", String(chosen))
    cell.classList.toggle("sale-cell--chosen", chosen)
    writeAttribute(cell, "tabindex", tabbable ? "0" : "-1")
    writeHidden(cell.querySelector<HTMLElement>(".sale-cell__check"), !chosen)
  }

  private pick(cell: HTMLElement | null): void {
    const ref = cell?.dataset.ref
    if (ref) this.dispatch("chosen", { detail: { ref } })
  }
}
