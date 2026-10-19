import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import { beginStep, PHONE_WIDTH, stepping, takeFocusWish, trackStepTransition } from "../lib/sub_view_step"
import { swipeStep } from "../lib/swipe"

// The phone sub-view of a card's detail (DESIGN.md, Card detail; EXPERIENCE.md:
// Collection, Card detail re-entry; epic 10 R2, R6). Its ◀ ▶ are links that
// replace the `card-detail` Turbo Frame and the URL (data-turbo-action
// "replace": browser Back still leads to the grid); this controller, on
// the detail's article:
// - turns a horizontal swipe on the stage into a press of ◀ or ▶ (a
//   vertical drag scrolls; a finger that tilts the card never swipes);
// - marks the step from the press until its visit has loaded
//   (lib/sub_view_step.ts);
// - when motion is allowed, renders the frame in a View Transition: the
//   card leaves toward the step and the next one comes in with a slight turn
//   (styles/card-detail.css); under reduced motion it is replaced at once;
// - sets the page's title to the card's as soon as it shows (Turbo merges
//   the response's head, layouts/turbo_rails/frame.html.erb, a moment
//   later), and points the top bar's way back, outside the frame, at the
//   page holding the card shown (a grid's page changes along its cards);
// - on a phone (the sub-view, under 720px), focuses the detail's heading as the sub-view
//   opens and after each step (EXPERIENCE.md, Focus after each step:
//   "Sub-view opened (phone) → Its heading"), without scrolling; after a
//   step pressed from the keyboard, it puts the focus back on the same
//   control in the new detail instead (on its heading when that control is
//   the disabled end); a card opened from the grid beside it
//   (collection_detail_controller.ts) focuses its heading, without
//   scrolling. Nothing on a Turbo preview.

type Direction = "previous" | "next"

/** Whether `element` is displayed (not under display: none). */
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
    if (wish === "heading") {
      if (this.hasHeadingTarget) this.headingTarget.focus({ preventScroll: true })
    } else if (wish) {
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

  // A press of ◀ or ▶ (click, Enter, or a swipe): Turbo follows the link.
  step(event: Event & { params: { direction?: string } }): void {
    const direction: Direction = event.params.direction === "previous" ? "previous" : "next"
    beginStep(direction, document.activeElement === event.currentTarget ? direction : null)
  }

  // ---- Swipe on the stage (touch only; touch-action: pan-y in CSS) ----

  press(event: PointerEvent): void {
    if (event.pointerType !== "touch" || !event.isPrimary) return
    this.gesture = { id: event.pointerId, x: event.clientX, y: event.clientY, tilted: false }
  }

  drag(event: PointerEvent): void {
    const gesture = this.gesture
    if (!gesture || gesture.id !== event.pointerId) return
    // A finger held still long enough tilts the card (lib/tilt.ts): that
    // gesture is a tilt, never a swipe.
    if (this.stageTarget.querySelector("[data-tilting]")) gesture.tilted = true
  }

  release(event: PointerEvent): void {
    const gesture = this.gesture
    this.gesture = null
    if (!gesture || gesture.id !== event.pointerId || gesture.tilted) return
    const step = swipeStep(event.clientX - gesture.x, event.clientY - gesture.y)
    if (step === 0) return
    const control = step > 0 ? (this.hasNextTarget ? this.nextTarget : null) : this.hasPreviousTarget ? this.previousTarget : null
    // At an end the control is a disabled button: nothing happens.
    if (!(control instanceof HTMLAnchorElement)) return
    if (shown(control)) control.click()
  }

  cancel(): void {
    this.gesture = null
  }

  // ---- The step's transition ----

  private readonly beforeFrameRender = (event: Event): void => {
    const detail = (event as CustomEvent<{ render?: FrameRender }>).detail
    const render = detail?.render
    const doc = document as ViewTransitionDocument
    if (!stepping() || !render || motionReduced() || typeof doc.startViewTransition !== "function") return
    detail.render = (currentElement, newElement) => {
      trackStepTransition(doc.startViewTransition!(() => render(currentElement, newElement)))
    }
  }

  // The phone's sub-view: a detail browsing something, under 720px (where
  // its position line shows).
  private subView(): boolean {
    return [this.hasPreviousTarget && this.previousTarget, this.hasNextTarget && this.nextTarget].some((control) => control && shown(control)) && window.matchMedia(PHONE_WIDTH).matches
  }

  private focusControl(direction: Direction): void {
    const control = direction === "previous" ? (this.hasPreviousTarget ? this.previousTarget : null) : this.hasNextTarget ? this.nextTarget : null
    if (control instanceof HTMLAnchorElement) control.focus()
    else if (this.hasHeadingTarget) this.headingTarget.focus()
  }
}
