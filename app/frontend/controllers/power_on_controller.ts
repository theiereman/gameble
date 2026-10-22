import { Controller } from "@hotwired/stimulus"
import { crossedPowerLine, driftOffsets, staggerDelayMs } from "../lib/landing_scroll"
import { motionReduced, onMotionChange } from "../lib/motion"

const CHILD_STEP_MS = 70
const CELL_STEP_MS = 42

export default class extends Controller<HTMLElement> {
  private armed = new Set<HTMLElement>()
  private frame = 0
  private stopMotionWatch?: () => void

  connect(): void {
    this.stopMotionWatch = onMotionChange(() => this.drift())
    this.armBelowTheLine()
    this.drift()
    window.addEventListener("scroll", this.schedule, { passive: true })
    window.addEventListener("resize", this.schedule)
    this.element.addEventListener("focusin", this.focused)
  }

  disconnect(): void {
    window.removeEventListener("scroll", this.schedule)
    window.removeEventListener("resize", this.schedule)
    this.element.removeEventListener("focusin", this.focused)
    this.stopMotionWatch?.()
    cancelAnimationFrame(this.frame)
    this.frame = 0
    this.armed.clear()
    this.writeDrift(0, 0)
  }

  private armBelowTheLine(): void {
    this.modules().forEach((module) => {
      if (crossedPowerLine(module.getBoundingClientRect().top, window.innerHeight)) {
        delete module.dataset.power
        return
      }
      this.stagger(module)
      module.dataset.power = "armed"
      this.armed.add(module)
    })
  }

  private modules(): HTMLElement[] {
    return Array.from(this.element.querySelectorAll<HTMLElement>(".landing-module"))
  }

  private stagger(module: HTMLElement): void {
    this.delays(Array.from(module.children), CHILD_STEP_MS)
    this.delays(Array.from(module.querySelectorAll(".landing-gauge__segment")), CELL_STEP_MS)
    this.delays(Array.from(module.querySelectorAll(".landing-pips__cell")), CELL_STEP_MS)
  }

  private delays(elements: Element[], stepMs: number): void {
    elements.forEach((element, index) => {
      if (element instanceof HTMLElement) element.style.setProperty("--power-delay", `${staggerDelayMs(index, stepMs)}ms`)
    })
  }

  private readonly schedule = (): void => {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => {
      this.frame = 0
      this.powerOnCrossed()
      this.drift()
    })
  }

  private powerOnCrossed(): void {
    this.armed.forEach((module) => {
      if (crossedPowerLine(module.getBoundingClientRect().top, window.innerHeight)) this.powerOn(module)
    })
  }

  private readonly focused = (event: Event): void => {
    const module = (event.target as HTMLElement).closest<HTMLElement>(".landing-module")
    if (module && this.armed.has(module)) this.powerOn(module)
  }

  private powerOn(module: HTMLElement): void {
    module.dataset.power = "on"
    this.armed.delete(module)
  }

  private drift(): void {
    if (motionReduced()) return this.writeDrift(0, 0)
    const { near, far } = driftOffsets(window.scrollY)
    this.writeDrift(near, far)
  }

  private writeDrift(near: number, far: number): void {
    const atmosphere = document.getElementById("atmosphere")
    if (!atmosphere) return
    atmosphere.style.setProperty("--landing-drift-near", `${near}px`)
    atmosphere.style.setProperty("--landing-drift-far", `${far}px`)
  }
}
