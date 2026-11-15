import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"

export type InfoView = Readonly<{
  lit: number
  size: string
  count: string
  reserve: string
  reserveFull: boolean
  next: Readonly<{ clock: string; spoken: string }> | null
  origin: string | null
}>

export default class BoosterInfoController extends Controller<HTMLElement> {
  static targets = ["size", "count", "reserve", "full", "next", "clock", "spoken", "origin"]

  declare readonly hasSizeTarget: boolean
  declare readonly sizeTarget: HTMLElement
  declare readonly hasCountTarget: boolean
  declare readonly countTarget: HTMLElement
  declare readonly hasReserveTarget: boolean
  declare readonly reserveTarget: HTMLElement
  declare readonly fullTarget: HTMLElement
  declare readonly nextTarget: HTMLElement
  declare readonly clockTarget: HTMLElement
  declare readonly spokenTarget: HTMLElement
  declare readonly hasOriginTarget: boolean
  declare readonly originTarget: HTMLElement

  render({ lit, size, count, reserve, reserveFull, next, origin }: InfoView): void {
    this.element
      .querySelectorAll<HTMLElement>(".booster__pip")
      .forEach((pip, index) => pip.toggleAttribute("data-lit", index < lit))
    if (this.hasSizeTarget) writeText(this.sizeTarget, size)
    if (this.hasCountTarget) writeText(this.countTarget, count)
    if (this.hasReserveTarget) writeText(this.reserveTarget, reserve)
    if (this.hasOriginTarget) {
      writeText(this.originTarget, origin ?? "")
      this.originTarget.closest<HTMLElement>(".booster__source")!.hidden = origin === null
    }
    this.fullTarget.hidden = !reserveFull
    this.nextTarget.hidden = reserveFull || next === null
    if (next) {
      writeText(this.clockTarget, next.clock)
      writeText(this.spokenTarget, next.spoken)
    }
  }
}
