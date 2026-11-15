import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import {
  EASE,
  FOLLOW,
  GRID_STEP,
  HALO_RADIUS,
  SAMPLE_STEP,
  approach,
  settled,
  translucent,
  warp,
  type Point,
  type Pointer,
} from "../lib/stage_grid"

type Palette = Readonly<{ accent: string; lime: string; line: string }>

export default class extends Controller<HTMLElement> {
  static targets = ["canvas"]

  declare readonly canvasTarget: HTMLCanvasElement

  private pen: CanvasRenderingContext2D | null = null
  private palette: Palette = { accent: "#000000", lime: "#000000", line: "#000000" }
  private observer: ResizeObserver | null = null
  private width = 0
  private height = 0
  private pointer: Pointer = { x: 0, y: 0, pull: 0 }
  private target: Pointer = { x: 0, y: 0, pull: 0 }
  private frame = 0

  connect(): void {
    this.pen = this.canvasTarget.getContext("2d")
    const style = getComputedStyle(this.element)
    const token = (name: string) => style.getPropertyValue(name).trim() || "#000000"
    this.palette = { accent: token("--color-accent"), lime: token("--color-lime"), line: token("--color-line") }
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(this.element)
  }

  disconnect(): void {
    this.observer?.disconnect()
    cancelAnimationFrame(this.frame)
    this.frame = 0
  }

  move(event: PointerEvent): void {
    if (event.pointerType !== "mouse") return
    const box = this.element.getBoundingClientRect()
    const x = event.clientX - box.left
    const y = event.clientY - box.top
    if (this.target.pull === 0) this.pointer = { ...this.pointer, x, y }
    this.target = { x, y, pull: 1 }
    this.animate()
  }

  leave(): void {
    this.target = { ...this.target, pull: 0 }
    this.animate()
  }

  private resize(): void {
    const ratio = Math.min(window.devicePixelRatio || 1, 2)
    this.width = this.element.clientWidth
    this.height = this.element.clientHeight
    this.canvasTarget.width = this.width * ratio
    this.canvasTarget.height = this.height * ratio
    this.pen?.setTransform(ratio, 0, 0, ratio, 0, 0)
    this.draw()
  }

  private animate(): void {
    if (!this.frame) this.frame = requestAnimationFrame(() => this.tick())
  }

  private tick(): void {
    this.frame = 0
    const still = motionReduced()
    this.pointer = {
      x: approach(this.pointer.x, this.target.x, still ? 1 : FOLLOW),
      y: approach(this.pointer.y, this.target.y, still ? 1 : FOLLOW),
      pull: approach(this.pointer.pull, this.target.pull, still ? 1 : EASE),
    }
    this.draw()
    if (!settled(this.pointer, this.target)) this.animate()
  }

  private draw(): void {
    const pen = this.pen
    if (!pen) return
    const { width, height, pointer, palette } = this
    pen.clearRect(0, 0, width, height)
    this.glow(width / 2, height * 0.38, width * 0.5, palette.accent, 0.2)
    this.glow(width / 2, height, width * 0.6, palette.lime, 0.1)
    if (pointer.pull > 0.01) this.glow(pointer.x, pointer.y, 360, palette.accent, 0.035 * pointer.pull)
    pen.lineWidth = 1
    pen.strokeStyle = translucent(palette.line, 0.55)
    this.grid(0, width, 0, height)
    if (pointer.pull > 0.01) this.halo()
    this.corners()
  }

  private glow(x: number, y: number, radius: number, colour: string, alpha: number): void {
    const pen = this.pen!
    const gradient = pen.createRadialGradient(x, y, 0, x, y, radius)
    gradient.addColorStop(0, translucent(colour, alpha))
    gradient.addColorStop(1, translucent(colour, 0))
    pen.fillStyle = gradient
    pen.fillRect(0, 0, this.width, this.height)
  }

  private grid(left: number, right: number, top: number, bottom: number): void {
    for (let y = 0; y <= this.height + GRID_STEP; y += GRID_STEP) {
      if (y < top || y > bottom) continue
      this.stroke(this.samples(left, right).map((x): Point => [x, y]))
    }
    for (let x = 0; x <= this.width + GRID_STEP; x += GRID_STEP) {
      if (x < left || x > right) continue
      this.stroke(this.samples(top, bottom).map((y): Point => [x, y]))
    }
  }

  private halo(): void {
    const pen = this.pen!
    const { x, y, pull } = this.pointer
    const reach = HALO_RADIUS + 50
    const gradient = pen.createRadialGradient(x, y, 0, x, y, HALO_RADIUS)
    gradient.addColorStop(0, translucent(this.palette.accent, 0.08))
    gradient.addColorStop(0.5, translucent(this.palette.accent, 0.03))
    gradient.addColorStop(1, translucent(this.palette.accent, 0))
    pen.save()
    pen.globalCompositeOperation = "lighter"
    pen.globalAlpha = Math.min(1, pull)
    pen.strokeStyle = gradient
    this.grid(
      Math.max(0, x - reach),
      Math.min(this.width, x + reach),
      Math.max(0, y - reach),
      Math.min(this.height, y + reach),
    )
    pen.restore()
  }

  private samples(from: number, to: number): number[] {
    const points: number[] = []
    for (let at = from; at <= to + SAMPLE_STEP; at += SAMPLE_STEP) points.push(at)
    return points
  }

  private stroke(points: Point[]): void {
    const pen = this.pen!
    pen.beginPath()
    points.forEach((point, index) => {
      const [x, y] = warp(point, this.pointer)
      if (index === 0) pen.moveTo(x, y)
      else pen.lineTo(x, y)
    })
    pen.stroke()
  }

  private corners(): void {
    const pen = this.pen!
    const { width, height } = this
    pen.strokeStyle = this.palette.accent
    pen.lineWidth = 2
    pen.beginPath()
    pen.moveTo(8, 24)
    pen.lineTo(8, 8)
    pen.lineTo(24, 8)
    pen.moveTo(width - 8, height - 24)
    pen.lineTo(width - 8, height - 8)
    pen.lineTo(width - 24, height - 8)
    pen.stroke()
  }
}
