import { Controller } from "@hotwired/stimulus"
import { Lamp, type LampCard, type LampFrame, type Point, pointerHeld, RADII_DESKTOP, RADII_PHONE, type Size } from "../lib/lamp"
import { motionReduced, onMotionChange } from "../lib/motion"

const PHONE_QUERY = "(max-width: 719px)"
const CARD_RADIUS_SHARE = 0.42
const LONGEST_FRAME_SECONDS = 0.1

export default class extends Controller<HTMLElement> {
  static targets = ["stage", "card", "veil", "reticle", "count"]

  declare readonly stageTarget: HTMLElement
  declare readonly cardTargets: HTMLElement[]
  declare readonly veilTarget: HTMLElement
  declare readonly reticleTarget: HTMLElement
  declare readonly countTarget: HTMLElement

  private lamp?: Lamp
  private slots: HTMLElement[] = []
  private frameId = 0
  private lastTime = 0
  private inView = false
  private reduced = false
  private phone = false
  private pointerInside: Point | null = null
  private pointerLastInside: Point | null = null
  private pointerMovedAt = -Infinity
  private shown = { power: -1, mode: "", found: [] as boolean[], lit: [] as boolean[], count: "" }
  private stopMotionWatch?: () => void
  private resizeObserver?: ResizeObserver
  private intersectionObserver?: IntersectionObserver

  connect(): void {
    this.stopMotionWatch = onMotionChange(() => this.restart())
    this.resizeObserver = new ResizeObserver(() => this.remeasure())
    this.resizeObserver.observe(this.stageTarget)
    this.intersectionObserver = new IntersectionObserver((entries) => {
      this.inView = entries.some((entry) => entry.isIntersecting)
      this.sync()
    })
    this.intersectionObserver.observe(this.stageTarget)
    document.addEventListener("visibilitychange", this.sync)
    document.addEventListener("pointermove", this.pointerMoved)
    document.documentElement.addEventListener("pointerleave", this.pointerLeft)
  }

  disconnect(): void {
    this.stop()
    this.stopMotionWatch?.()
    this.resizeObserver?.disconnect()
    this.intersectionObserver?.disconnect()
    document.removeEventListener("visibilitychange", this.sync)
    document.removeEventListener("pointermove", this.pointerMoved)
    document.documentElement.removeEventListener("pointerleave", this.pointerLeft)
  }

  private readonly sync = (): void => {
    if (this.inView && !document.hidden && !this.reduced) this.start()
    else this.stop()
  }

  private readonly pointerMoved = (event: PointerEvent): void => {
    if (event.pointerType === "touch" || this.reduced || !this.lamp) return
    const stage = this.stageTarget.getBoundingClientRect()
    const x = event.clientX - stage.left
    const y = event.clientY - stage.top
    const inside = x >= 0 && y >= 0 && x <= stage.width && y <= stage.height
    if (!inside && !this.pointerInside) return
    this.pointerInside = inside ? { x, y } : null
    if (inside) {
      this.pointerLastInside = { x, y }
      this.pointerMovedAt = performance.now()
    }
    this.wake()
  }

  private readonly pointerLeft = (): void => {
    if (!this.pointerInside) return
    this.pointerInside = null
    this.wake()
  }

  private wake(): void {
    if (!this.inView || document.hidden) return
    if (!this.reduced) this.start()
  }

  private restart(): void {
    this.stop()
    this.reduced = motionReduced()
    this.shown = { power: -1, mode: "", found: [], lit: [], count: "" }
    if (this.reduced) {
      this.lamp = undefined
      this.revealAll()
      return
    }
    this.lamp = this.buildLamp(performance.now())
    this.sync()
  }

  private remeasure(): void {
    if (!this.lamp || this.reduced || this.phone !== window.matchMedia(PHONE_QUERY).matches) {
      this.restart()
      return
    }
    const { cards, area } = this.measure()
    this.lamp.remeasure(cards, area)
  }

  private revealAll(): void {
    this.element.removeAttribute("data-lamp-lit")
    this.element.dataset.lampMode = "still"
    this.cardTargets.forEach((slot) => this.markCard(slot, true, false))
    const visible = this.cardTargets.filter((slot) => slot.getBoundingClientRect().width > 0).length
    this.countTarget.textContent = `${visible} / ${visible}`
  }

  private measure(): { cards: LampCard[]; area: Size } {
    const stage = this.stageTarget.getBoundingClientRect()
    this.slots = this.cardTargets.filter((slot) => slot.getBoundingClientRect().width > 0)
    const cards = this.slots.map((slot) => {
      const rect = slot.getBoundingClientRect()
      return {
        x: rect.left - stage.left + rect.width / 2,
        y: rect.top - stage.top + rect.height / 2,
        radius: Math.min(rect.width, rect.height) * CARD_RADIUS_SHARE
      }
    })
    return { cards, area: { width: stage.width, height: stage.height } }
  }

  private buildLamp(startedAt: number): Lamp {
    this.cardTargets.forEach((slot) => this.markCard(slot, false, false))
    const { cards, area } = this.measure()
    this.phone = window.matchMedia(PHONE_QUERY).matches
    const radii = this.phone ? RADII_PHONE : RADII_DESKTOP
    return new Lamp(cards, area, radii, startedAt)
  }

  private start(): void {
    if (this.frameId || !this.lamp) return
    this.lastTime = performance.now()
    this.frameId = requestAnimationFrame(this.frame)
  }

  private stop(): void {
    if (this.frameId) cancelAnimationFrame(this.frameId)
    this.frameId = 0
  }

  private readonly frame = (time: number): void => {
    const dt = Math.min((time - this.lastTime) / 1000, LONGEST_FRAME_SECONDS)
    this.lastTime = time
    this.frameId = 0
    const frame = this.draw(time, dt)
    if (!frame?.settled) this.frameId = requestAnimationFrame(this.frame)
  }

  private draw(now: number, dt: number): LampFrame | undefined {
    if (!this.lamp) return undefined
    const stage = this.stageTarget.getBoundingClientRect()
    const held = pointerHeld({ inside: this.pointerLastInside !== null, movedAt: this.pointerMovedAt, now })
    const pointer = this.pointerLastInside
    const frame = this.lamp.advance({ now, dt, pointer, pointerHeld: held })
    this.render(frame, stage)
    return frame
  }

  private render(frame: LampFrame, stage: DOMRect): void {
    this.veilTarget.style.transform = `translate3d(${frame.x - stage.width / 2}px, ${frame.y - stage.height / 2}px, 0)`
    this.reticleTarget.style.transform = `translate3d(${frame.x}px, ${frame.y}px, 0)`
    this.renderChanges(frame)
  }

  private renderChanges(frame: LampFrame): void {
    if (frame.power !== this.shown.power) {
      frame.radii.forEach((radius, index) => this.element.style.setProperty(`--lamp-radius-${index + 1}`, `${radius}px`))
      this.element.toggleAttribute("data-lamp-lit", frame.power > 0)
      this.shown.power = frame.power
    }
    if (frame.mode !== this.shown.mode) {
      this.element.dataset.lampMode = frame.mode
      this.shown.mode = frame.mode
    }
    this.slots.forEach((slot, index) => {
      if (frame.found[index] === this.shown.found[index] && frame.lit[index] === this.shown.lit[index]) return
      this.markCard(slot, frame.found[index], frame.lit[index])
    })
    this.shown.found = frame.found
    this.shown.lit = frame.lit
    const count = `${frame.foundCount} / ${frame.found.length}`
    if (count !== this.shown.count) {
      this.countTarget.textContent = count
      this.shown.count = count
    }
  }

  private markCard(slot: HTMLElement, found: boolean, lit: boolean): void {
    slot.classList.toggle("is-found", found)
    slot.classList.toggle("is-lit", lit)
  }
}
