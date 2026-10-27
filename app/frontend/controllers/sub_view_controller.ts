import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import { beginStep, PHONE_WIDTH, stepping, takeFocusWish, trackStepTransition } from "../lib/sub_view_step"
import { swipeStep } from "../lib/swipe"

type Direction = "previous" | "next"

function shown(element: HTMLElement): boolean {
  return element.checkVisibility?.() ?? element.offsetParent !== null
}

type FrameRender = (currentElement: Element, newElement: Element) => void
type ViewTransitionDocument = Document & { startViewTransition?: (update: () => void) => { finished: Promise<unknown> } }

export default class extends Controller<HTMLElement> {
  static targets = ["stage", "previous", "next", "heading"]
  static values = { title: String, back: String }

  declare readonly stageTarget: HTMLElement
  declare readonly hasStageTarget: boolean
  declare readonly previousTarget: HTMLElement
  declare readonly hasPreviousTarget: boolean
  declare readonly nextTarget: HTMLElement
  declare readonly hasNextTarget: boolean
  declare readonly headingTarget: HTMLElement
  declare readonly hasHeadingTarget: boolean
  declare readonly titleValue: string
  declare readonly backValue: string

  private frame: HTMLElement | null = null
  private gesture: { id: number; x: number; y: number; tilted: boolean } | null = null

  connect(): void {
    if (this.titleValue && document.title !== this.titleValue) document.title = this.titleValue
    if (this.backValue) document.querySelector<HTMLAnchorElement>(".top-bar__phone-back")?.setAttribute("href", this.backValue)
    this.frame = this.element.closest("turbo-frame")
    this.frame?.addEventListener("turbo:before-frame-render", this.beforeFrameRender)
    const wish = takeFocusWish()
    if (wish) {
      this.focusControl(wish)
    } else if (!document.documentElement.hasAttribute("data-turbo-preview") && this.hasHeadingTarget && this.subView()) {
      this.headingTarget.focus({ preventScroll: true })
    }
  }

  disconnect(): void {
    this.frame?.removeEventListener("turbo:before-frame-render", this.beforeFrameRender)
    this.frame = null
    this.gesture = null
  }

  step(event: Event & { params: { direction?: string } }): void {
    const direction: Direction = event.params.direction === "previous" ? "previous" : "next"
    beginStep(direction, document.activeElement === event.currentTarget ? direction : null)
  }

  press(event: PointerEvent): void {
    if (event.pointerType !== "touch" || !event.isPrimary) return
    this.gesture = { id: event.pointerId, x: event.clientX, y: event.clientY, tilted: false }
  }

  drag(event: PointerEvent): void {
    const gesture = this.gesture
    if (!gesture || gesture.id !== event.pointerId) return
    if (this.stageTarget.querySelector("[data-tilting]")) gesture.tilted = true
  }

  release(event: PointerEvent): void {
    const gesture = this.gesture
    this.gesture = null
    if (!gesture || gesture.id !== event.pointerId || gesture.tilted) return
    const step = swipeStep(event.clientX - gesture.x, event.clientY - gesture.y)
    if (step === 0) return
    const control = step > 0 ? (this.hasNextTarget ? this.nextTarget : null) : this.hasPreviousTarget ? this.previousTarget : null
    if (!(control instanceof HTMLAnchorElement)) return
    if (shown(control)) control.click()
  }

  cancel(): void {
    this.gesture = null
  }

  private readonly beforeFrameRender = (event: Event): void => {
    const detail = (event as CustomEvent<{ render?: FrameRender }>).detail
    const render = detail?.render
    const doc = document as ViewTransitionDocument
    if (!stepping() || !render || motionReduced() || typeof doc.startViewTransition !== "function") return
    detail.render = (currentElement, newElement) => {
      trackStepTransition(doc.startViewTransition!(() => render(currentElement, newElement)))
    }
  }

  private subView(): boolean {
    return [this.hasPreviousTarget && this.previousTarget, this.hasNextTarget && this.nextTarget].some((control) => control && shown(control)) && window.matchMedia(PHONE_WIDTH).matches
  }

  private focusControl(direction: Direction): void {
    const control = direction === "previous" ? (this.hasPreviousTarget ? this.previousTarget : null) : this.hasNextTarget ? this.nextTarget : null
    if (control instanceof HTMLAnchorElement) control.focus()
    else if (this.hasHeadingTarget) this.headingTarget.focus()
  }
}
