import { Controller } from "@hotwired/stimulus"
import { CENTRE, IRIS_X, IRIS_Y, irisOrigin, turnsFrom, type IrisOrigin } from "../lib/set_tile_iris"

export default class extends Controller<HTMLAnchorElement> {
  enter(event: PointerEvent): void {
    if (!turnsFrom(event.pointerType)) return

    this.open(irisOrigin(this.element.getBoundingClientRect(), event))
  }

  focused(): void {
    if (this.element.matches(":focus-visible")) this.open(CENTRE)
  }

  private open(origin: IrisOrigin): void {
    this.element.style.setProperty(IRIS_X, origin.x)
    this.element.style.setProperty(IRIS_Y, origin.y)
  }
}
