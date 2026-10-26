import { Controller } from "@hotwired/stimulus"
import type { StatusTone } from "../lib/booster"

export type InfoView = Readonly<{
  lit: number
  size: string
  reserve: string
  tone: StatusTone
  reserveFull: boolean
  next: Readonly<{ clock: string; spoken: string }> | null
}>

const text = (element: Element, value: string): void => {
  if (element.textContent !== value) element.textContent = value
}

export default class BoosterInfoController extends Controller<HTMLElement> {
  static targets = ["size", "reserve", "state", "full", "next", "clock", "spoken"]

  declare readonly hasSizeTarget: boolean
  declare readonly sizeTarget: HTMLElement
  declare readonly hasReserveTarget: boolean
  declare readonly reserveTarget: HTMLElement
  declare readonly stateTarget: HTMLElement
  declare readonly fullTarget: HTMLElement
  declare readonly nextTarget: HTMLElement
  declare readonly clockTarget: HTMLElement
  declare readonly spokenTarget: HTMLElement

  render({ lit, size, reserve, tone, reserveFull, next }: InfoView): void {
    this.element.querySelectorAll<HTMLElement>(".booster__pip").forEach((pip, index) => pip.toggleAttribute("data-lit", index < lit))
    if (this.hasSizeTarget) text(this.sizeTarget, size)
    if (this.hasReserveTarget) text(this.reserveTarget, reserve)
    this.stateTarget.dataset.tone = tone
    this.fullTarget.hidden = !reserveFull
    this.nextTarget.hidden = reserveFull || next === null
    if (next) {
      text(this.clockTarget, next.clock)
      text(this.spokenTarget, next.spoken)
    }
  }
}
