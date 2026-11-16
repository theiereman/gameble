import { Controller } from "@hotwired/stimulus"

export type PlateHint = Readonly<{ kind: "tap" | "swipe" }>

export type PlateView = Readonly<{
  shown: boolean
  hint: PlateHint | null
  celebrating: boolean
}>

export default class BoosterPlateController extends Controller<HTMLElement> {
  static targets = ["hint"]

  declare readonly hintTarget: HTMLElement

  render({ shown, hint, celebrating }: PlateView): void {
    this.element.hidden = !shown
    this.hintTarget.hidden = hint === null || celebrating
    if (hint) this.hintTarget.dataset.shows = hint.kind
  }
}
