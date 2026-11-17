import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import {
  EASE,
  FOLLOW,
  HALO_RADIUS,
  HALO_SPAN,
  POINTER_GLOW_RADIUS,
  approach,
  gridLines,
  haloOriginOnGrid,
  settled,
  translucent,
  type Pointer,
} from "../lib/stage_grid"

type Palette = Readonly<{ accent: string; lime: string; line: string }>

type Box = Readonly<{ left: number; top: number; right: number; bottom: number }>

export default class extends Controller<HTMLElement> {
  static targets = ["floor", "halo"]

  declare readonly floorTarget: HTMLCanvasElement
  declare readonly haloTarget: HTMLCanvasElement

  private floor: CanvasRenderingContext2D | null = null
  private halo: CanvasRenderingContext2D | null = null
  private palette: Palette = { accent: "#000000", lime: "#000000", line: "#000000" }
  private observer: ResizeObserver | null = null
  private width = 0
  private height = 0
  private pointer: Pointer = { x: 0, y: 0, pull: 0 }
  private target: Pointer = { x: 0, y: 0, pull: 0 }
  private frame = 0

  connect(): void {
    this.floor = this.floorTarget.getContext("2d")
    this.halo = this.haloTarget.getContext("2d")
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
    const width = this.element.clientWidth
    const height = this.element.clientHeight
    if (width === this.width && height === this.height) return
    this.width = width
    this.height = height
    const ratio = this.ratio()
    this.floorTarget.width = width * ratio
    this.floorTarget.height = height * ratio
    this.floor?.setTransform(ratio, 0, 0, ratio, 0, 0)
    this.drawFloor()
    if (this.haloTarget.width !== HALO_SPAN * ratio) this.drawHalo(ratio)
  }

  private ratio(): number {
    return Math.min(window.devicePixelRatio || 1, 2)
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
    this.placeHalo()
    if (!settled(this.pointer, this.target)) this.animate()
  }

  private drawFloor(): void {
    const pen = this.floor
    if (!pen) return
    const { width, height, palette } = this
    pen.clearRect(0, 0, width, height)
    this.glow(pen, width / 2, height * 0.38, width * 0.5, palette.accent, 0.2)
    this.glow(pen, width / 2, height, width * 0.6, palette.lime, 0.1)
    pen.lineWidth = 1
    pen.strokeStyle = translucent(palette.line, 0.55)
    this.grid(pen, { left: 0, top: 0, right: width, bottom: height })
    this.corners(pen)
  }

  private drawHalo(ratio: number): void {
    const pen = this.halo
    if (!pen) return
    this.haloTarget.width = HALO_SPAN * ratio
    this.haloTarget.height = HALO_SPAN * ratio
    pen.setTransform(ratio, 0, 0, ratio, 0, 0)
    const centre = HALO_SPAN / 2
    this.glow(pen, centre, centre, POINTER_GLOW_RADIUS, this.palette.accent, 0.035, HALO_SPAN, HALO_SPAN)
    const gradient = pen.createRadialGradient(centre, centre, 0, centre, centre, HALO_RADIUS)
    gradient.addColorStop(0, translucent(this.palette.accent, 0.08))
    gradient.addColorStop(0.5, translucent(this.palette.accent, 0.03))
    gradient.addColorStop(1, translucent(this.palette.accent, 0))
    pen.lineWidth = 1
    pen.strokeStyle = gradient
    this.grid(pen, { left: 0, top: 0, right: HALO_SPAN, bottom: HALO_SPAN })
  }

  private placeHalo(): void {
    const { x, y, pull } = this.pointer
    const style = this.haloTarget.style
    style.setProperty("--halo-x", `${haloOriginOnGrid(x)}px`)
    style.setProperty("--halo-y", `${haloOriginOnGrid(y)}px`)
    style.setProperty("--halo-pull", pull <= 0.01 ? "0" : `${Math.min(1, pull)}`)
  }

  private glow(
    pen: CanvasRenderingContext2D,
    x: number,
    y: number,
    radius: number,
    colour: string,
    alpha: number,
    width = this.width,
    height = this.height,
  ): void {
    const gradient = pen.createRadialGradient(x, y, 0, x, y, radius)
    gradient.addColorStop(0, translucent(colour, alpha))
    gradient.addColorStop(1, translucent(colour, 0))
    pen.fillStyle = gradient
    pen.fillRect(0, 0, width, height)
  }

  private grid(pen: CanvasRenderingContext2D, { left, top, right, bottom }: Box): void {
    pen.beginPath()
    for (const y of gridLines(top, bottom)) {
      pen.moveTo(left, y)
      pen.lineTo(right, y)
    }
    for (const x of gridLines(left, right)) {
      pen.moveTo(x, top)
      pen.lineTo(x, bottom)
    }
    pen.stroke()
  }

  private corners(pen: CanvasRenderingContext2D): void {
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
