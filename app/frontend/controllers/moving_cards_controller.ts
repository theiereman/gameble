import { Controller } from "@hotwired/stimulus"
import { frameScheduler } from "../lib/frame_scheduler"
import { motionReduced, onMotionChange } from "../lib/motion"
import { CARD_DIMENSIONS, hasGutterRoom, laneBounds, placeCard, type CardSize, type Placement } from "../lib/moving_cards"

const FINE_POINTER_QUERY = "(hover: hover) and (pointer: fine)"

type Mover = { element: HTMLElement; key: string; size: CardSize; side: "left" | "right"; spec: Omit<Placement, "width" | "height" | "lane"> }
type Drag = { pointerId: number; startX: number; startY: number; originX: number; originY: number; mover: Mover }

export default class extends Controller<HTMLElement> {
  private movers: Mover[] = []
  private offsets = new Map<string, { x: number; y: number }>()
  private drag?: Drag
  private readonly frames = frameScheduler(() => this.refresh())
  private pointerQuery?: MediaQueryList
  private stopMotionWatch?: () => void
  private pageResize?: ResizeObserver

  connect(): void {
    this.pointerQuery = window.matchMedia(FINE_POINTER_QUERY)
    this.pointerQuery.addEventListener("change", this.refresh)
    this.stopMotionWatch = onMotionChange(this.refresh)
    window.addEventListener("scroll", this.frames.schedule, { passive: true })
    window.addEventListener("resize", this.frames.schedule)
    document.addEventListener("focusin", this.focusMoved)
    document.addEventListener("focusout", this.focusLeft)
    this.element.addEventListener("pointerdown", this.pointerDown)
    this.element.addEventListener("pointermove", this.pointerMove)
    this.element.addEventListener("pointerup", this.pointerEnd)
    this.element.addEventListener("pointercancel", this.pointerEnd)
    this.pageResize = new ResizeObserver(this.frames.schedule)
    this.pageResize.observe(document.body)
    this.refresh()
  }

  disconnect(): void {
    this.pointerQuery?.removeEventListener("change", this.refresh)
    this.stopMotionWatch?.()
    this.pageResize?.disconnect()
    window.removeEventListener("scroll", this.frames.schedule)
    window.removeEventListener("resize", this.frames.schedule)
    document.removeEventListener("focusin", this.focusMoved)
    document.removeEventListener("focusout", this.focusLeft)
    this.element.removeEventListener("pointerdown", this.pointerDown)
    this.element.removeEventListener("pointermove", this.pointerMove)
    this.element.removeEventListener("pointerup", this.pointerEnd)
    this.element.removeEventListener("pointercancel", this.pointerEnd)
    this.frames.cancel()
    this.deactivate()
  }

  private readonly refresh = (): void => {
    const shown = this.mayShow()
    if (shown && this.movers.length === 0) this.activate()
    else if (!shown && this.movers.length > 0) this.deactivate()
    this.place()
  }

  private mayShow(): boolean {
    if (!this.pointerQuery?.matches || motionReduced()) return false
    const content = this.content()
    return content !== null && hasGutterRoom(content.left, document.documentElement.clientWidth - content.right, this.widestCard())
  }

  private content(): { left: number; right: number } | null {
    const rect = document.querySelector(".landing")?.getBoundingClientRect()
    return rect ? { left: rect.left, right: rect.right } : null
  }

  private widestCard(): number {
    const sizes = Array.from(this.template()?.content.querySelectorAll<HTMLElement>("[data-size]") ?? [], (card) => card.dataset.size as CardSize)
    return Math.max(0, ...sizes.map((size) => CARD_DIMENSIONS[size].width))
  }

  private template(): HTMLTemplateElement | null {
    return this.element.querySelector("template")
  }

  private activate(): void {
    const template = this.template()
    if (!template) return
    this.element.append(template.content.cloneNode(true))
    this.movers = Array.from(this.element.querySelectorAll<HTMLElement>(".moving-card"), (element) => this.moverFor(element))
  }

  private deactivate(): void {
    this.drag = undefined
    this.element.querySelectorAll(".moving-card").forEach((element) => element.remove())
    this.movers = []
  }

  private moverFor(element: HTMLElement): Mover {
    const data = element.dataset
    return {
      element,
      key: data.key ?? "",
      size: data.size as CardSize,
      side: data.lane as "left" | "right",
      spec: { anchor: Number(data.anchor), speed: Number(data.speed), sway: Number(data.sway), offset: Number(data.offset), rotation: Number(data.rotation) },
    }
  }

  private place(): void {
    const content = this.content()
    if (this.movers.length === 0 || !content) return
    const frame = {
      scrollY: window.scrollY,
      scrollable: document.documentElement.scrollHeight - window.innerHeight,
      viewportHeight: window.innerHeight,
      dragX: 0,
      dragY: 0,
    }
    const viewportWidth = document.documentElement.clientWidth
    this.movers.forEach((mover) => {
      const offset = this.offsets.get(mover.key)
      const lane = laneBounds(mover.side, content.left, content.right, viewportWidth)
      const at = placeCard({ ...mover.spec, ...CARD_DIMENSIONS[mover.size], lane }, { ...frame, dragX: offset?.x ?? 0, dragY: offset?.y ?? 0 })
      mover.element.hidden = !at.visible
      if (!at.visible) return
      mover.element.style.translate = `${at.x}px ${at.y}px`
      mover.element.style.rotate = `${at.rotation}deg`
    })
  }

  private readonly pointerDown = (event: PointerEvent): void => {
    if (event.button !== 0 || !event.isPrimary || this.drag) return
    const element = (event.target as Element).closest<HTMLElement>(".moving-card")
    const mover = this.movers.find((candidate) => candidate.element === element)
    if (!element || !mover) return
    event.preventDefault()
    element.setPointerCapture(event.pointerId)
    const origin = this.offsets.get(mover.key) ?? { x: 0, y: 0 }
    this.drag = { pointerId: event.pointerId, startX: event.clientX, startY: event.clientY, originX: origin.x, originY: origin.y, mover }
    element.classList.add("is-dragging")
  }

  private readonly pointerMove = (event: PointerEvent): void => {
    const drag = this.drag
    if (!drag || event.pointerId !== drag.pointerId) return
    this.offsets.set(drag.mover.key, { x: drag.originX + event.clientX - drag.startX, y: drag.originY + event.clientY - drag.startY })
    this.frames.schedule()
  }

  private readonly pointerEnd = (event: PointerEvent): void => {
    const drag = this.drag
    if (!drag || event.pointerId !== drag.pointerId) return
    drag.mover.element.classList.remove("is-dragging")
    this.drag = undefined
    this.place()
  }

  private readonly focusMoved = (event: FocusEvent): void => {
    const target = event.target as Element
    this.element.classList.toggle("is-faded", target.matches(":focus-visible") && this.insideMain(target))
  }

  private readonly focusLeft = (event: FocusEvent): void => {
    if (!this.insideMain(event.relatedTarget as Element | null)) this.element.classList.remove("is-faded")
  }

  private insideMain(node: Element | null): boolean {
    return node !== null && document.getElementById("main")?.contains(node) === true
  }
}
