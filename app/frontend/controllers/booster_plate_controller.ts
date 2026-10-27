import { Controller } from "@hotwired/stimulus"
import { animate } from "../lib/booster_effects"
import { platePopKeyframes } from "../lib/booster_keyframes"
import { PLATE_POP_LEGENDARY_MS, PLATE_POP_MS } from "../lib/booster_motion"
import { writeFlag, writeText } from "../lib/dom_writes"
import { BANNER_TIERS } from "../lib/screen"
import { cloneTemplate } from "../lib/templates"
import type { Rarity } from "../lib/card_types"
import { motionReduced } from "../lib/motion"

export type PlateHint = Readonly<{ kind: "tap" | "swipe" | "done"; done: string }>

export type PlateCard = Readonly<{ key: string; tier: Rarity; tierText: string; line: string }>

export type PlateView = Readonly<{
  shown: boolean
  hint: PlateHint | null
  plate: PlateCard | null
  celebrating: boolean
  busy: boolean
}>

export default class BoosterPlateController extends Controller<HTMLElement> {
  static targets = ["hint", "done", "plate"]

  declare readonly hintTarget: HTMLElement
  declare readonly doneTarget: HTMLElement
  declare readonly plateTarget: HTMLTemplateElement

  private plateKey: string | null = null
  private plateElement: HTMLElement | null = null
  private busy = false

  render({ shown, hint, plate, celebrating, busy }: PlateView, icon: (tier: Rarity) => DocumentFragment | null): void {
    this.busy = busy
    this.element.hidden = !shown
    this.hintTarget.hidden = hint === null || celebrating
    if (hint) {
      this.hintTarget.dataset.shows = hint.kind
      writeText(this.doneTarget, hint.done)
    }
    writeFlag(this.hintTarget, "aria-hidden", Boolean(plate))

    if ((plate?.key ?? null) !== this.plateKey) this.showPlate(plate, icon)
    const store = this.plateElement?.querySelector(".booster-plate__store")
    if (store) writeFlag(store, "aria-disabled", busy)
  }

  store(): void {
    if (!this.busy) this.dispatch("store")
  }

  private showPlate(plate: PlateCard | null, icon: (tier: Rarity) => DocumentFragment | null): void {
    this.plateElement?.remove()
    this.plateElement = null
    this.plateKey = plate?.key ?? null
    if (!plate) return
    const element = cloneTemplate(this.plateTarget)
    if (!element) return
    element.dataset.tier = plate.tier
    const banner = BANNER_TIERS.includes(plate.tier)
    const tier = element.querySelector<HTMLElement>(".booster-plate__tier")
    tier?.toggleAttribute("data-banner", banner)
    if (!banner) element.querySelectorAll(".booster-plate__tick").forEach((tick) => tick.remove())
    element.querySelector(".booster-plate__icon")?.replaceChildren(icon(plate.tier) ?? "")
    element.querySelector(".booster-plate__tier-name")!.textContent = plate.tierText
    element.querySelector(".booster-plate__line")!.textContent = plate.line
    this.element.append(element)
    this.plateElement = element
    if (!motionReduced()) {
      animate(element, platePopKeyframes(), {
        duration: plate.tier === "legendary" ? PLATE_POP_LEGENDARY_MS : PLATE_POP_MS,
        easing: "cubic-bezier(.2,1.35,.35,1)",
      })
    }
  }
}
