import { Controller } from "@hotwired/stimulus"
import type { StatusTone } from "../lib/booster"
import { writeText } from "../lib/dom_writes"

export type InfoView = Readonly<{
  lit: number
  size: string
  reserve: string
  tone: StatusTone
  reserveFull: boolean
  next: Readonly<{ clock: string; spoken: string }> | null
  origin: string | null
}>

export default class BoosterInfoController extends Controller<HTMLElement> {
  static targets = ["size", "reserve", "state", "full", "next", "clock", "spoken", "origin"]

  declare readonly hasSizeTarget: boolean
  declare readonly sizeTarget: HTMLElement
  declare readonly hasReserveTarget: boolean
  declare readonly reserveTarget: HTMLElement
  declare readonly stateTarget: HTMLElement
  declare readonly fullTarget: HTMLElement
  declare readonly nextTarget: HTMLElement
  declare readonly clockTarget: HTMLElement
  declare readonly spokenTarget: HTMLElement
  declare readonly hasOriginTarget: boolean
  declare readonly originTarget: HTMLElement

  render({ lit, size, reserve, tone, reserveFull, next, origin }: InfoView): void {
    this.element
      .querySelectorAll<HTMLElement>(".booster__pip")
      .forEach((pip, index) => pip.toggleAttribute("data-lit", index < lit))
    if (this.hasSizeTarget) writeText(this.sizeTarget, size)
    if (this.hasReserveTarget) writeText(this.reserveTarget, reserve)
    this.stateTarget.dataset.tone = tone
    if (this.hasOriginTarget) {
      writeText(this.originTarget, origin ?? "")
      this.originTarget.closest<HTMLElement>(".booster__row")!.hidden = origin === null
    }
    this.fullTarget.hidden = !reserveFull
    this.nextTarget.hidden = reserveFull || next === null
    if (next) {
      writeText(this.clockTarget, next.clock)
      writeText(this.spokenTarget, next.spoken)
    }
  }
}
