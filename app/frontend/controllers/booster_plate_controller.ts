import { Controller } from "@hotwired/stimulus"

export type PlateView = Readonly<{ shown: boolean }>

export default class BoosterPlateController extends Controller<HTMLElement> {
  render({ shown }: PlateView): void {
    this.element.hidden = !shown
  }
}
