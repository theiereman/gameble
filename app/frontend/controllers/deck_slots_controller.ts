import { Controller } from "@hotwired/stimulus"
import type { SlotView } from "../lib/deck_editor"
import type { Bar } from "../lib/deck_stats"
import { writeAttribute, writeData, writeHidden, writeText } from "../lib/dom_writes"
import { cloneFirstElement } from "../lib/templates"

export default class DeckSlotsController extends Controller<HTMLElement> {
  static targets = ["slot", "filledTemplate", "emptyTemplate"]

  declare readonly slotTargets: HTMLElement[]
  declare readonly filledTemplateTarget: HTMLTemplateElement
  declare readonly emptyTemplateTarget: HTMLTemplateElement

  render(view: readonly SlotView[]): void {
    this.slotTargets.forEach((slot, index) => {
      const wanted = view[index] ?? null
      if ((slot.dataset.ref ?? "") === (wanted?.ref ?? "") && slot.firstElementChild) return
      const filling = wanted ? this.filled(wanted) : cloneFirstElement(this.emptyTemplateTarget)
      if (!filling) return
      slot.replaceChildren(filling)
      writeData(slot, "ref", wanted?.ref ?? "")
    })
  }

  focusSlot(slot: number): void {
    this.slotTargets[slot - 1]?.querySelector<HTMLElement>("button")?.focus()
  }

  remove(event: Event): void {
    const slot = (event.currentTarget as Element).closest<HTMLElement>("[data-deck-slots-target~='slot']")
    const index = slot ? this.slotTargets.indexOf(slot) : -1
    if (index !== -1) this.dispatch("remove", { detail: { slot: index + 1 } })
  }

  private filled({ title, image, label, moves, bars }: NonNullable<SlotView>): HTMLElement | null {
    const filled = cloneFirstElement<HTMLElement>(this.filledTemplateTarget)
    const button = filled?.querySelector(".deck-slot")
    if (!filled || !button) return null
    writeAttribute(button, "aria-label", label)
    const art = button.querySelector<HTMLImageElement>("img")
    if (art) writeAttribute(art, "src", image)
    writeText(button.querySelector(".deck-slot__name"), title)
    writeText(filled.querySelector(".deck-slot__moves"), moves)
    drawBars(filled, bars)
    return filled
  }
}

function drawBars(root: HTMLElement, bars: readonly Bar[]): void {
  for (const row of root.querySelectorAll<HTMLElement>("[data-stat]")) {
    const bar = bars.find((each) => each.stat === row.dataset.stat)
    writeHidden(row, !bar)
    if (!bar) continue
    writeAttribute(row, "data-tier", String(bar.tier))
    row.classList.toggle("stat-bars__row--trump", bar.trump)
    writeText(row.querySelector(".stat-bars__value"), String(bar.value))
    row.querySelector("progress")?.setAttribute("value", String(bar.value))
  }
}
