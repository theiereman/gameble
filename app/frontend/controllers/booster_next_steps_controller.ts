import { Controller } from "@hotwired/stimulus"
import { showNextSteps, type NextStepsFrame } from "../lib/booster_next_steps_panel"

export type NextStepsView = Readonly<{ shown: boolean }>

export default class BoosterNextStepsController extends Controller<HTMLElement> {
  static targets = ["frame"]
  static values = { url: String }

  declare readonly frameTarget: NextStepsFrame
  declare readonly urlValue: string

  render({ shown }: NextStepsView): void {
    showNextSteps(this.element, this.frameTarget, this.urlValue, shown)
  }

  keep(event: Event): void {
    event.preventDefault()
  }
}
