import { Controller } from "@hotwired/stimulus"
import { afterLoad, type Pending, pressed, SCREEN_FRAME, setsExpanded, viewField } from "../lib/grand_inventory"

type TabParams = { view?: string }

export default class extends Controller<HTMLElement> {
  static targets = ["chip", "status", "viewField", "setsPreview", "setsAll", "setsToggle"]

  declare readonly chipTargets: HTMLButtonElement[]
  declare readonly statusTarget: HTMLElement
  declare readonly viewFieldTarget: HTMLInputElement
  declare readonly hasViewFieldTarget: boolean
  declare readonly setsPreviewTarget: HTMLElement
  declare readonly setsAllTarget: HTMLElement
  declare readonly hasSetsAllTarget: boolean

  private pending: Pending = null

  disconnect(): void {
    this.pending = null
  }

  setsToggleTargetConnected(wrapper: HTMLElement): void {
    const button = wrapper.querySelector("button")
    button?.setAttribute("aria-expanded", "false")
    if (this.hasSetsAllTarget) button?.setAttribute("aria-controls", this.setsAllTarget.id)
  }

  chooseScope(event: SubmitEvent): void {
    const chosen = event.submitter instanceof HTMLButtonElement ? event.submitter : null
    if (!chosen || !this.chipTargets.includes(chosen)) return

    pressed(this.chipTargets, chosen).forEach((on, index) =>
      this.chipTargets[index]?.setAttribute("aria-pressed", String(on)),
    )
    this.statusTarget.textContent = ""
    this.pending = "scope"
  }

  tab(event: Event & { params: TabParams }): void {
    this.pending = "tab"
    if (!this.hasViewFieldTarget || !event.params.view) return

    const field = viewField(event.params.view)
    this.viewFieldTarget.value = field.value
    this.viewFieldTarget.disabled = field.disabled
  }

  loaded(event: Event): void {
    const frame = event.target
    if (!(frame instanceof HTMLElement) || frame.id !== SCREEN_FRAME) return

    const step = afterLoad(this.pending)
    this.pending = null
    if (step === "announce") this.announce(frame)
    if (step === "focus-view") this.focusView(frame)
  }

  toggleSets(event: Event): void {
    const button = (event.target as Element).closest("button")
    if (!button) return

    const expanded = setsExpanded(button.getAttribute("aria-expanded"))
    button.setAttribute("aria-expanded", String(expanded))
    this.setsAllTarget.hidden = !expanded
    this.setsPreviewTarget.hidden = expanded
  }

  private announce(frame: HTMLElement): void {
    this.chipTargets.find((chip) => chip.getAttribute("aria-pressed") === "true")?.focus()
    const status = frame.querySelector<HTMLElement>("[data-grand-inventory-status]")?.textContent?.trim() ?? ""
    this.statusTarget.textContent = status
  }

  private focusView(frame: HTMLElement): void {
    const heading = Array.from(frame.querySelectorAll<HTMLElement>("[data-grand-inventory-view] h2")).find(
      (each) => each.closest("[data-grand-inventory-view]")?.getClientRects().length,
    )
    if (!heading) return

    heading.tabIndex = -1
    heading.focus()
  }
}
