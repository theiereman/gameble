import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { cloneTemplate } from "../lib/templates"
import { drawCardArt } from "../lib/card_art"
import type { Rarity } from "../lib/card_types"

export type TraySlotView = Readonly<{ tier: Rarity; coverUrl: string; name: string; stored: boolean }>

export type TrayView = Readonly<{
  key: string
  shown: boolean
  count: string
  busy: boolean
  slots: readonly TraySlotView[]
}>

const THUMBNAIL = { width: 22, height: 30 }

export default class BoosterTrayController extends Controller<HTMLElement> {
  static targets = ["count", "slots", "empty", "filled"]
  static values = { paletteWidth: Number, paletteHeight: Number }

  declare readonly countTarget: HTMLElement
  declare readonly slotsTarget: HTMLOListElement
  declare readonly emptyTarget: HTMLTemplateElement
  declare readonly filledTarget: HTMLTemplateElement
  declare readonly paletteWidthValue: number
  declare readonly paletteHeightValue: number

  private key: string | null = null
  private items: HTMLLIElement[] = []
  private draws = new Map<number, AbortController>()
  private busy = false

  disconnect(): void {
    this.abortDraws()
  }

  slotElement(index: number): HTMLElement | null {
    return this.items[index]?.querySelector<HTMLElement>(".booster-tray__slot") ?? null
  }

  render({ key, shown, count, busy, slots }: TrayView, icon: (tier: Rarity) => DocumentFragment | null): void {
    this.busy = busy
    this.element.hidden = !shown
    writeText(this.countTarget, count)
    if (key !== this.key) this.rebuild(key, slots.length)
    const next = slots.findIndex((slot) => !slot.stored)
    slots.forEach((slot, index) => {
      const item = this.items[index]
      if (!item) return
      const filled = item.querySelector<HTMLButtonElement>(".booster-tray__slot--filled")
      if (slot.stored) {
        const button = filled ?? this.fill(item, index, slot, icon)
        if (busy) button?.setAttribute("aria-disabled", "true")
        else button?.removeAttribute("aria-disabled")
      } else {
        item.querySelector(".booster-tray__slot")?.toggleAttribute("data-next", index === next)
      }
    })
  }

  open(event: Event): void {
    const button = (event.target as Element | null)?.closest<HTMLElement>(".booster-tray__slot--filled")
    if (!button || this.busy) return
    const index = this.items.findIndex((item) => item.contains(button))
    if (index >= 0) this.dispatch("zoom", { detail: { index } })
  }

  private rebuild(key: string, count: number): void {
    this.abortDraws()
    this.key = key
    this.items = Array.from({ length: count }, () => cloneTemplate<HTMLLIElement>(this.emptyTarget)).filter((item) => item !== null)
    this.slotsTarget.replaceChildren(...this.items)
  }

  private fill(item: HTMLLIElement, index: number, slot: TraySlotView, icon: (tier: Rarity) => DocumentFragment | null): HTMLButtonElement | null {
    const button = cloneTemplate<HTMLButtonElement>(this.filledTarget)
    if (!button) return null
    button.dataset.tier = slot.tier
    button.setAttribute("aria-label", slot.name)
    button.querySelector(".booster-tray__icon")?.replaceChildren(icon(slot.tier) ?? "")
    item.replaceChildren(button)
    const canvas = button.querySelector("canvas")
    if (canvas) {
      const abort = new AbortController()
      this.draws.set(index, abort)
      void drawCardArt(button, canvas, slot.coverUrl, {
        ...THUMBNAIL,
        paletteWidth: this.paletteWidthValue,
        paletteHeight: this.paletteHeightValue,
        signal: abort.signal,
      })
    }
    return button
  }

  private abortDraws(): void {
    this.draws.forEach((abort) => abort.abort())
    this.draws.clear()
  }
}
