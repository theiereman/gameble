import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import {
  pressRevealDemo,
  REVEAL_DEMO_START,
  revealDemoLabel,
  type RevealDemoState,
  turnDuration,
} from "../lib/reveal_demo"

export default class extends Controller<HTMLElement> {
  static targets = ["stage", "face", "button", "status"]
  static values = { revealLabel: String, restartLabel: String }

  declare readonly stageTarget: HTMLElement
  declare readonly faceTargets: HTMLElement[]
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly hasButtonTarget: boolean
  declare readonly statusTarget: HTMLElement
  declare readonly revealLabelValue: string
  declare readonly restartLabelValue: string

  private state: RevealDemoState = REVEAL_DEMO_START
  private turnBack?: ReturnType<typeof setTimeout>

  connect(): void {
    this.state = REVEAL_DEMO_START
    this.show()
    if (this.hasButtonTarget) this.buttonTarget.hidden = false
  }

  disconnect(): void {
    clearTimeout(this.turnBack)
    this.state = REVEAL_DEMO_START
    this.show()
    if (this.hasButtonTarget) this.buttonTarget.hidden = true
  }

  toggle(): void {
    clearTimeout(this.turnBack)
    this.state = pressRevealDemo(this.state, this.faceTargets.length)
    if (this.state.revealed) {
      this.show()
      this.statusTarget.textContent = this.faceTargets[this.state.index]?.dataset.announcement ?? ""
    } else {
      this.stageTarget.removeAttribute("data-revealed")
      this.statusTarget.textContent = ""
      this.turnBack = setTimeout(() => this.show(), turnDuration(motionReduced()))
    }
    this.buttonTarget.textContent = revealDemoLabel(this.state, {
      reveal: this.revealLabelValue,
      restart: this.restartLabelValue,
    })
  }

  private show(): void {
    const { revealed, index: current } = this.state
    this.faceTargets.forEach((face, index) => (face.hidden = !revealed || index !== current))
    this.stageTarget.toggleAttribute("data-revealed", revealed)
  }
}
