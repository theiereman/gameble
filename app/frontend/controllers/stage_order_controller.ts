import { Controller } from "@hotwired/stimulus"
import { dispatchGameble } from "../lib/events"
import { t } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import "../lib/turbo"
import { TOUCH_HOLD_MS, moveItem, nearestIndex, pastThreshold, sendPlacement, type Box } from "../lib/showcase_order"

const RANK_CLASS = /^profile-stage__slot--(\d+|top)$/
const SHIFT_MS = 240

type Drag = {
  ranked: HTMLElement[]
  from: number
  to: number
  places: Box[]
  grabX: number
  grabY: number
}

type Gesture = {
  slot: HTMLElement
  pointerId: number
  touch: boolean
  startX: number
  startY: number
  holdTimer?: number
  drag?: Drag
}

const layoutBox = (slot: HTMLElement): Box => ({
  left: slot.offsetLeft,
  top: slot.offsetTop,
  width: slot.offsetWidth,
  height: slot.offsetHeight,
})

const turnOf = (slot: HTMLElement): number => (parseFloat(getComputedStyle(slot).rotate) || 0) * (Math.PI / 180)

const gapBefore = (node: Element | null): ChildNode | null =>
  node?.previousSibling?.nodeType === Node.TEXT_NODE ? node.previousSibling : null

function rankSlot(slot: HTMLElement, rank: number): void {
  slot.classList.remove(...[...slot.classList].filter((name) => RANK_CLASS.test(name)))
  slot.classList.add(`profile-stage__slot--${rank + 1}`)
  slot.classList.toggle("profile-stage__slot--top", rank === 0)
}

export default class extends Controller<HTMLElement> {
  static targets = ["list", "slot", "placing", "status"]
  static values = { announcement: String, failed: String, placing: String }

  declare readonly listTarget: HTMLElement
  declare readonly slotTargets: HTMLElement[]
  declare readonly placingTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly announcementValue: string
  declare readonly failedValue: string
  declare readonly placingValue: string

  private gesture?: Gesture
  private saving = false
  private swallowClick = false
  private shifts = new Map<HTMLElement, Animation>()

  connect(): void {
    this.element.addEventListener("touchmove", this.holdScroll, { passive: false })
    this.element.addEventListener("click", this.clickAfterDrag, { capture: true })
  }

  disconnect(): void {
    this.element.removeEventListener("touchmove", this.holdScroll)
    this.element.removeEventListener("click", this.clickAfterDrag, { capture: true })
    this.cancel()
  }

  press(event: PointerEvent): void {
    if (this.gesture || this.saving || !event.isPrimary || event.button !== 0) return
    this.gesture = {
      slot: event.currentTarget as HTMLElement,
      pointerId: event.pointerId,
      touch: event.pointerType === "touch",
      startX: event.clientX,
      startY: event.clientY,
    }
    if (this.gesture.touch) this.gesture.holdTimer = window.setTimeout(() => this.lift(), TOUCH_HOLD_MS)
    window.addEventListener("pointermove", this.follow)
    window.addEventListener("pointerup", this.drop)
    window.addEventListener("pointercancel", this.pointerCancelled)
    window.addEventListener("keydown", this.escape)
  }

  stopNativeDrag(event: DragEvent): void {
    event.preventDefault()
  }

  stopMenu(event: Event): void {
    if (this.gesture?.touch) event.preventDefault()
  }

  private follow = (event: PointerEvent): void => {
    const gesture = this.gesture
    if (!gesture || event.pointerId !== gesture.pointerId) return
    if (!gesture.drag) {
      if (!pastThreshold(event.clientX - gesture.startX, event.clientY - gesture.startY)) return
      if (gesture.touch) return this.cancel()
      this.lift()
    }
    event.preventDefault()
    this.carry(event.clientX, event.clientY)
  }

  private lift(): void {
    const gesture = this.gesture
    if (!gesture || gesture.drag) return
    window.clearTimeout(gesture.holdTimer)
    const ranked = this.slotTargets
    const from = ranked.indexOf(gesture.slot)
    const places = ranked.map(layoutBox)
    const home = places[from]!
    const list = this.listTarget.getBoundingClientRect()
    gesture.drag = {
      ranked,
      from,
      to: from,
      places,
      grabX: (gesture.startX - list.left - home.left) / home.width,
      grabY: (gesture.startY - list.top - home.top) / home.height,
    }
    gesture.slot.dataset.dragging = ""
    this.listTarget.dataset.sorting = ""
    this.showPlace(from, ranked.length)
    if (gesture.touch) {
      navigator.vibrate?.(12)
      dispatchGameble("gameble:touch-held", { held: true })
    }
  }

  private carry(x: number, y: number): void {
    const gesture = this.gesture
    const drag = gesture?.drag
    if (!gesture || !drag) return
    const list = this.listTarget.getBoundingClientRect()
    const to = nearestIndex({ x: x - list.left, y: y - list.top }, drag.places)
    if (to !== drag.to) {
      drag.to = to
      this.arrange(moveItem(drag.ranked, drag.from, to), gesture.slot)
      this.showPlace(to, drag.ranked.length)
    }
    const place = drag.places[to]!
    const left = x - list.left - place.left - drag.grabX * place.width
    const top = y - list.top - place.top - drag.grabY * place.height
    gesture.slot.style.translate = `${left}px ${top}px`
  }

  private arrange(order: HTMLElement[], carried?: HTMLElement): void {
    const before = order.map((slot) => ({
      box: layoutBox(slot),
      shift: new DOMMatrixReadOnly(getComputedStyle(slot).transform),
      turn: turnOf(slot),
    }))
    order.forEach(rankSlot)
    if (motionReduced()) return

    order.forEach((slot, index) => {
      const { box, shift, turn } = before[index]!
      const after = layoutBox(slot)
      const scale = (box.width * shift.a) / after.width
      const dx = slot === carried ? 0 : box.left + box.width / 2 + shift.e - (after.left + after.width / 2)
      const dy = slot === carried ? 0 : box.top + box.height + shift.f - (after.top + after.height)
      if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5 && Math.abs(scale - 1) < 0.01) return
      const x = dx * Math.cos(turn) + dy * Math.sin(turn)
      const y = dy * Math.cos(turn) - dx * Math.sin(turn)
      this.shifts.get(slot)?.cancel()
      this.shifts.set(
        slot,
        slot.animate([{ transform: `translate(${x}px, ${y}px) scale(${scale})` }, { transform: "none" }], {
          duration: SHIFT_MS,
          easing: "cubic-bezier(0.2, 0.8, 0.3, 1)",
        }),
      )
    })
  }

  private showPlace(rank: number, count: number): void {
    this.placingTarget.textContent = t(this.placingValue, { position: rank + 1, count })
    this.placingTarget.hidden = false
  }

  private drop = (event: PointerEvent): void => {
    const gesture = this.gesture
    if (!gesture || event.pointerId !== gesture.pointerId) return
    const drag = this.release()
    if (!drag) return

    this.swallowClick = true
    window.setTimeout(() => (this.swallowClick = false), 0)
    if (drag.to !== drag.from) void this.save(gesture.slot, drag)
  }

  private pointerCancelled = (event: PointerEvent): void => {
    if (event.pointerId === this.gesture?.pointerId) this.cancel()
  }

  private escape = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || !this.gesture?.drag) return
    event.preventDefault()
    this.cancel()
  }

  private cancel(): void {
    const drag = this.release()
    if (drag) this.arrange(drag.ranked)
  }

  private release(): Drag | undefined {
    const gesture = this.gesture
    if (!gesture) return
    this.gesture = undefined
    window.clearTimeout(gesture.holdTimer)
    window.removeEventListener("pointermove", this.follow)
    window.removeEventListener("pointerup", this.drop)
    window.removeEventListener("pointercancel", this.pointerCancelled)
    window.removeEventListener("keydown", this.escape)
    if (!gesture.drag) return

    gesture.slot.style.removeProperty("translate")
    if (gesture.slot.getAttribute("style") === "") gesture.slot.removeAttribute("style")
    delete gesture.slot.dataset.dragging
    delete this.listTarget.dataset.sorting
    this.placingTarget.hidden = true
    if (gesture.touch) dispatchGameble("gameble:touch-held", { held: false })
    return gesture.drag
  }

  private async save(slot: HTMLElement, drag: Drag): Promise<void> {
    this.saving = true
    this.listTarget.setAttribute("aria-busy", "true")
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? null
    const result = await sendPlacement({ url: slot.dataset.url ?? "", position: drag.to, csrfToken })
    this.listTarget.removeAttribute("aria-busy")

    if (result.kind !== "placed") {
      this.saving = false
      this.arrange(drag.ranked)
      dispatchGameble("gameble:toast", {
        message: result.kind === "refused" ? result.message : this.failedValue,
        tone: "alert",
      })
      return
    }

    this.statusTarget.textContent = t(this.announcementValue, {
      title: slot.dataset.title ?? "",
      position: drag.to + 1,
      count: drag.ranked.length,
    })
    const order = moveItem(drag.ranked, drag.from, drag.to)
    await Promise.allSettled(order.flatMap((each) => each.getAnimations()).map((animation) => animation.finished))
    this.reorder(order)
    this.saving = false
    window.Turbo.session.refresh(document.baseURI, { method: "morph", scroll: "preserve" })
  }

  // A morph matches the cards by position, so the list takes the new order before the refresh.
  private reorder(order: HTMLElement[]): void {
    const list = this.listTarget
    let previous: Element | null = null
    order.forEach((slot) => {
      const next: Element | null = previous ? previous.nextElementSibling : list.firstElementChild
      if (next !== slot) this.move(slot, next)
      previous = slot
    })
  }

  // The morph pairs nodes by position, white space included, so a card moves with the gap before it.
  private move(slot: HTMLElement, before: Element | null): void {
    const list = this.listTarget
    const anchor = gapBefore(before) ?? before
    const nodes = [gapBefore(slot), slot].filter((node): node is ChildNode => node !== null)
    const preserving = "moveBefore" in Element.prototype
    nodes.forEach((node) => (preserving ? list.moveBefore(node, anchor) : list.insertBefore(node, anchor)))
    if (preserving) return
    // Without moveBefore, a card put back in the page would be dealt again.
    slot.getAnimations().forEach((animation) => {
      if (animation instanceof CSSAnimation && animation.animationName === "profile-stage-deal") animation.finish()
    })
  }

  private holdScroll = (event: TouchEvent): void => {
    if (this.gesture?.drag && event.cancelable) event.preventDefault()
  }

  private clickAfterDrag = (event: Event): void => {
    if (!this.swallowClick && !this.gesture?.drag) return
    this.swallowClick = false
    event.preventDefault()
    event.stopPropagation()
  }
}
