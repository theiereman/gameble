import { Controller } from "@hotwired/stimulus"
import { dispatchGameble } from "../lib/events"
import { t } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import { TOUCH_HOLD_MS, edgeButtons, nearestIndex, pastThreshold, sendPlacement } from "../lib/showcase_order"

type Gesture = {
  slot: HTMLElement
  pointerId: number
  touch: boolean
  startX: number
  startY: number
  holdTimer?: number
  dragging: boolean
  grabX: number
  grabY: number
  shiftX: number
  shiftY: number
  before: HTMLElement[]
}

const SHIFT_MS = 160

// The owner's showcase on their profile, reordered by dragging a card (lib/showcase_order.ts): a mouse or pen after a few pixels,
// a finger after holding still. The new place is sent on release; a refusal puts the previous order back and toasts the server's message.
export default class extends Controller<HTMLElement> {
  static targets = ["list", "slot", "status"]
  static values = { announcement: String, failed: String }

  declare readonly listTarget: HTMLElement
  declare readonly slotTargets: HTMLElement[]
  declare readonly statusTarget: HTMLElement
  declare readonly announcementValue: string
  declare readonly failedValue: string

  private gesture?: Gesture
  private saving = false
  private swallowClick = false
  private settledAt = 0

  connect(): void {
    this.element.addEventListener("touchmove", this.holdScroll, { passive: false })
    this.element.addEventListener("click", this.clickAfterDrag, { capture: true })
  }

  disconnect(): void {
    this.element.removeEventListener("touchmove", this.holdScroll)
    this.element.removeEventListener("click", this.clickAfterDrag, { capture: true })
    if (this.gesture) this.cancel()
  }

  press(event: PointerEvent): void {
    if (this.gesture || this.saving || !event.isPrimary || event.button !== 0) return
    const slot = event.currentTarget as HTMLElement
    if ((event.target as Element).closest("form")) return

    this.gesture = {
      slot,
      pointerId: event.pointerId,
      touch: event.pointerType === "touch",
      startX: event.clientX,
      startY: event.clientY,
      dragging: false,
      grabX: 0,
      grabY: 0,
      shiftX: 0,
      shiftY: 0,
      before: [...this.slotTargets],
    }
    if (this.gesture.touch) {
      this.gesture.holdTimer = window.setTimeout(() => this.lift(), TOUCH_HOLD_MS)
    }
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
    const moved = pastThreshold(event.clientX - gesture.startX, event.clientY - gesture.startY)

    if (!gesture.dragging) {
      if (!moved) return
      if (gesture.touch) {
        this.end()
        return
      }
      this.lift()
    }
    event.preventDefault()
    this.carry(event.clientX, event.clientY)
  }

  private lift(): void {
    const gesture = this.gesture
    if (!gesture || gesture.dragging) return
    window.clearTimeout(gesture.holdTimer)
    gesture.dragging = true
    const box = gesture.slot.getBoundingClientRect()
    gesture.grabX = gesture.startX - (box.left + box.width / 2)
    gesture.grabY = gesture.startY - (box.top + box.height / 2)
    gesture.slot.dataset.dragging = ""
    this.listTarget.dataset.sorting = ""
  }

  private carry(x: number, y: number): void {
    const gesture = this.gesture
    if (!gesture) return
    const slots = this.slotTargets
    const from = slots.indexOf(gesture.slot)
    const boxes = slots.map((slot) => (slot === gesture.slot ? this.restingBox(gesture) : slot.getBoundingClientRect()))
    const to = nearestIndex({ x, y }, boxes)
    if (to !== -1 && to !== from && performance.now() >= this.settledAt) {
      const target = slots[to]
      this.reorder((dragged) => (to < from ? target.before(dragged) : target.after(dragged)), gesture.slot)
    }

    const resting = this.restingBox(gesture)
    gesture.shiftX = x - gesture.grabX - (resting.left + resting.width / 2)
    gesture.shiftY = y - gesture.grabY - (resting.top + resting.height / 2)
    gesture.slot.style.translate = `${gesture.shiftX}px ${gesture.shiftY}px`
  }

  private restingBox(gesture: Gesture): DOMRect {
    const box = gesture.slot.getBoundingClientRect()
    return new DOMRect(box.left - gesture.shiftX, box.top - gesture.shiftY, box.width, box.height)
  }

  private reorder(insert: (node: HTMLElement) => void, dragged: HTMLElement): void {
    const others = this.slotTargets.filter((slot) => slot !== dragged)
    const was = new Map(others.map((slot) => [slot, slot.getBoundingClientRect()]))
    insert(dragged)
    if (motionReduced()) return
    this.settledAt = performance.now() + SHIFT_MS
    others.forEach((slot) => {
      const before = was.get(slot)
      const after = slot.getBoundingClientRect()
      if (!before || (before.left === after.left && before.top === after.top)) return
      slot.animate([{ translate: `${before.left - after.left}px ${before.top - after.top}px` }, { translate: "0 0" }], {
        duration: SHIFT_MS,
        easing: "ease-out",
      })
    })
  }

  private drop = (event: PointerEvent): void => {
    const gesture = this.gesture
    if (!gesture || event.pointerId !== gesture.pointerId) return
    const dragged = gesture.dragging
    this.end()
    if (!dragged) return

    this.swallowClick = true
    window.setTimeout(() => (this.swallowClick = false), 0)
    const position = this.slotTargets.indexOf(gesture.slot)
    if (position !== gesture.before.indexOf(gesture.slot)) void this.save(gesture.slot, position, gesture.before)
  }

  private pointerCancelled = (event: PointerEvent): void => {
    if (event.pointerId === this.gesture?.pointerId) this.cancel()
  }

  private escape = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || !this.gesture?.dragging) return
    event.preventDefault()
    this.cancel()
  }

  private cancel(): void {
    const before = this.gesture?.before
    this.end()
    if (before) this.restore(before)
  }

  private end(): void {
    const gesture = this.gesture
    if (!gesture) return
    window.clearTimeout(gesture.holdTimer)
    window.removeEventListener("pointermove", this.follow)
    window.removeEventListener("pointerup", this.drop)
    window.removeEventListener("pointercancel", this.pointerCancelled)
    window.removeEventListener("keydown", this.escape)
    gesture.slot.style.removeProperty("translate")
    if (gesture.slot.getAttribute("style") === "") gesture.slot.removeAttribute("style")
    delete gesture.slot.dataset.dragging
    delete this.listTarget.dataset.sorting
    this.gesture = undefined
  }

  private async save(slot: HTMLElement, position: number, before: HTMLElement[]): Promise<void> {
    this.saving = true
    this.listTarget.setAttribute("aria-busy", "true")
    this.showEdges()
    const result = await sendPlacement({ url: slot.dataset.url ?? "", position, csrfToken: this.csrfToken() })
    this.saving = false
    this.listTarget.removeAttribute("aria-busy")

    if (result.kind === "placed") {
      this.announce(t(this.announcementValue, { title: slot.dataset.title ?? "", position: position + 1, count: this.slotTargets.length }))
    } else {
      this.restore(before)
      dispatchGameble("gameble:toast", { message: result.kind === "refused" ? result.message : this.failedValue, tone: "alert" })
    }
  }

  private restore(order: HTMLElement[]): void {
    order.forEach((slot) => this.listTarget.append(slot))
    this.showEdges()
  }

  private showEdges(): void {
    const slots = this.slotTargets
    slots.forEach((slot, index) => {
      const shown = edgeButtons(index, slots.length)
      slot.querySelectorAll<HTMLFormElement>("form[data-direction]").forEach((form) => {
        form.hidden = !shown[form.dataset.direction as keyof typeof shown]
      })
    })
  }

  private announce(message: string): void {
    this.statusTarget.textContent = ""
    window.requestAnimationFrame(() => (this.statusTarget.textContent = message))
  }

  private csrfToken(): string | null {
    return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? null
  }

  private holdScroll = (event: TouchEvent): void => {
    if (this.gesture?.dragging && event.cancelable) event.preventDefault()
  }

  private clickAfterDrag = (event: Event): void => {
    if (!this.swallowClick && !this.gesture?.dragging) return
    this.swallowClick = false
    event.preventDefault()
    event.stopPropagation()
  }
}
