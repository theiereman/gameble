import { Controller } from "@hotwired/stimulus"
import type { SlotView } from "../lib/deck_editor"
import { writeAttribute, writeData, writeHidden, writeText } from "../lib/dom_writes"
import { cloneFirstElement } from "../lib/templates"

const DRAG_THRESHOLD = 8
const GHOST_FADE_MS = 160

export default class DeckSlotsController extends Controller<HTMLElement> {
  static targets = ["slot", "filledTemplate", "emptyTemplate"]

  declare readonly slotTargets: HTMLElement[]
  declare readonly filledTemplateTarget: HTMLTemplateElement
  declare readonly emptyTemplateTarget: HTMLTemplateElement

  private dragged = false

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

  // A click on a card offers its "Remove" button, for touch and keyboard; a mouse can also drag the card out of the deck.
  toggle(event: Event): void {
    if (this.dragged) {
      this.dragged = false
      return
    }
    const filled = (event.currentTarget as Element).closest<HTMLElement>(".deck-slot__filled")
    if (!filled) return
    const open = filled.querySelector<HTMLElement>(".deck-slot__actions")?.hidden ?? false
    this.closeActions()
    if (open) this.showActions(filled)
  }

  // Fills the shared details sheet, which the bottom sheet then opens, with the card of the slot.
  fillInfo(event: Event): void {
    const card = (event.currentTarget as Element)
      .closest(".deck-slot__filled")
      ?.querySelector<HTMLElement>(".deck-card")
    const sheet = document.getElementById("deck-card-info")
    const legend = this.element.closest(".deck-editor")?.querySelector(".deck-editor__legend-stats")
    if (!card || !sheet) return
    writeText(sheet.querySelector(".deck-info__name"), card.dataset.title ?? "")
    sheet.querySelector(".deck-info__card")?.replaceChildren(card.cloneNode(true))
    sheet
      .querySelector(".deck-info__stats")
      ?.replaceChildren(...(legend ? Array.from(legend.cloneNode(true).childNodes) : []))
    sheet.querySelector("a.button")?.setAttribute("href", card.dataset.url ?? "#")
  }

  dismiss(event: Event): void {
    if (event.target instanceof Element && event.target.closest(".deck-slot__filled")) return
    this.closeActions()
  }

  remove(event: Event): void {
    const index = this.indexOf(event.currentTarget as Element)
    if (index !== -1) this.dispatch("remove", { detail: { slot: index + 1 } })
  }

  press(event: PointerEvent): void {
    if (event.pointerType === "touch" || event.button !== 0) return
    const button = event.currentTarget as HTMLElement
    const card = button.querySelector<HTMLElement>(".deck-card")
    const index = this.indexOf(button)
    if (!card || index === -1) return
    const start = { x: event.clientX, y: event.clientY }
    const box = card.getBoundingClientRect()
    let ghost: HTMLElement | undefined

    const move = (at: PointerEvent): void => {
      if (!ghost && Math.hypot(at.clientX - start.x, at.clientY - start.y) < DRAG_THRESHOLD) return
      if (!ghost) ghost = this.lift(button, card, box)
      ghost.style.setProperty("--drag-x", `${at.clientX - start.x}px`)
      ghost.style.setProperty("--drag-y", `${at.clientY - start.y}px`)
      this.deckPanel()?.toggleAttribute("data-leaving", !this.insideDeck(at))
    }
    const release = (at: PointerEvent): void => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", release)
      window.removeEventListener("pointercancel", release)
      this.deckPanel()?.removeAttribute("data-leaving")
      if (!ghost) return
      this.dragged = true
      button.closest(".deck-slot__filled")?.removeAttribute("data-dragging")
      const leaving = at.type === "pointerup" && !this.insideDeck(at)
      this.drop(ghost, leaving)
      if (leaving) this.dispatch("remove", { detail: { slot: index + 1 } })
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", release)
    window.addEventListener("pointercancel", release)
  }

  private lift(button: HTMLElement, card: HTMLElement, box: DOMRect): HTMLElement {
    const ghost = card.cloneNode(true) as HTMLElement
    ghost.classList.add("deck-card--ghost")
    ghost.style.setProperty("--ghost-left", `${box.left}px`)
    ghost.style.setProperty("--ghost-top", `${box.top}px`)
    ghost.style.setProperty("--ghost-width", `${box.width}px`)
    document.body.append(ghost)
    button.closest(".deck-slot__filled")?.setAttribute("data-dragging", "")
    this.closeActions()
    return ghost
  }

  private drop(ghost: HTMLElement, leaving: boolean): void {
    ghost.setAttribute("data-state", leaving ? "leaving" : "returning")
    window.setTimeout(() => ghost.remove(), GHOST_FADE_MS)
  }

  private deckPanel(): HTMLElement | null {
    return this.element.closest<HTMLElement>(".deck-editor__deck")
  }

  private insideDeck({ clientX, clientY }: PointerEvent): boolean {
    const box = this.deckPanel()?.getBoundingClientRect()
    return !box || (clientX >= box.left && clientX <= box.right && clientY >= box.top && clientY <= box.bottom)
  }

  private showActions(filled: HTMLElement): void {
    writeHidden(filled.querySelector<HTMLElement>(".deck-slot__actions"), false)
    filled.querySelector(".deck-slot")?.setAttribute("aria-expanded", "true")
    filled.querySelector<HTMLElement>(".deck-slot__remove button")?.focus()
  }

  private closeActions(): void {
    this.element.querySelectorAll<HTMLElement>(".deck-slot__actions").forEach((actions) => writeHidden(actions, true))
    this.element
      .querySelectorAll(".deck-slot[aria-expanded]")
      .forEach((each) => each.setAttribute("aria-expanded", "false"))
  }

  private indexOf(element: Element): number {
    const slot = element.closest<HTMLElement>("[data-deck-slots-target~='slot']")
    return slot ? this.slotTargets.indexOf(slot) : -1
  }

  private filled({ ref, label, moves }: NonNullable<SlotView>): HTMLElement | null {
    const filled = cloneFirstElement<HTMLElement>(this.filledTemplateTarget)
    const button = filled?.querySelector(".deck-slot")
    if (!filled || !button) return null
    writeAttribute(filled.querySelector(".deck-slot__remove button") ?? button, "aria-label", label)
    button.querySelector(".deck-slot__card")?.replaceChildren(...this.cardOf(ref))
    writeText(filled.querySelector(".deck-slot__moves"), moves)
    return filled
  }

  private cardOf(ref: string): Node[] {
    const editor = this.element.closest(".deck-editor")
    const source = editor?.querySelector(
      `[data-deck-collection-target~="list"] [data-ref="${CSS.escape(ref)}"] .deck-card`,
    )
    return source ? [source.cloneNode(true)] : []
  }
}
