import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"
import { swipeStep } from "../lib/swipe"

// The phone sub-view of a card's detail (DESIGN.md, Card detail; EXPERIENCE.md:
// Collection, Card detail re-entry; epic 10 R2, R6). Its ◀ ▶ are links that
// replace the `card-detail` Turbo Frame and the URL (data-turbo-action
// "replace": browser Back still leads to the grid); this controller, on
// the detail's article:
// - turns a horizontal swipe on the stage into a press of ◀ or ▶ (a
//   vertical drag scrolls; a finger that tilts the card never swipes);
// - marks a step on <html> (`data-sub-view-step=previous|next`) from the
//   press until Turbo's visit has loaded and the card's transition has
//   ended: the star field does not shift (starfield_controller.ts) and the
//   screen does not slide (styles/shell.css), as a step is no screen change;
// - when motion is allowed, renders the frame in a View Transition: the
//   card leaves toward the step and the next one comes in with a slight turn
//   (styles/card-detail.css); under reduced motion it is replaced at once;
// - sets the page's title to the card's as soon as it shows (Turbo merges
//   the response's head, layouts/turbo_rails/frame.html.erb, a moment
//   later);
// - after a step pressed from the keyboard, puts the focus back on the same
//   control in the new detail (on its heading when that control is the
//   disabled end).
//
// Turbo's own visit for the new URL renders no body, but would start a
// View Transition of its own, which would cut the card's short: during a
// step the page's view-transition meta reads "none", so Turbo starts none
// (the merged head brings the meta back). The step's
// state lives at module level, as the article that set it is replaced by
// the step.

type Direction = "previous" | "next"

/** Ends a step even when its visit never loads (an error, a cancel). */
const STEP_TIMEOUT_MS = 5000

let focusAfterStep: Direction | null = null
let stepTransition: { finished: Promise<unknown> } | null = null
let stepTimer: ReturnType<typeof setTimeout> | undefined
let pausedMeta: { element: HTMLMetaElement; content: string } | null = null

function endStep(): void {
  document.removeEventListener("turbo:load", stepLoaded)
  if (stepTimer !== undefined) clearTimeout(stepTimer)
  stepTimer = undefined
  stepTransition = null
  if (pausedMeta) pausedMeta.element.content = pausedMeta.content
  pausedMeta = null
  delete document.documentElement.dataset.subViewStep
}

// The visit has loaded: the step ends once the card's transition has,
// unless another step has begun meanwhile (a quick second press).
function stepLoaded(): void {
  document.removeEventListener("turbo:load", stepLoaded)
  const transition = stepTransition
  const step = currentStep
  if (transition) void transition.finished.catch(() => undefined).then(() => step === currentStep && endStep())
  else endStep()
}

let currentStep = 0

function beginStep(direction: Direction): void {
  endStep()
  currentStep++
  document.documentElement.dataset.subViewStep = direction
  const meta = document.head.querySelector<HTMLMetaElement>("meta[name=view-transition]")
  if (meta) {
    pausedMeta = { element: meta, content: meta.content }
    meta.content = "none"
  }
  document.addEventListener("turbo:load", stepLoaded)
  stepTimer = setTimeout(endStep, STEP_TIMEOUT_MS)
}

type FrameRender = (currentElement: Element, newElement: Element) => void
type ViewTransitionDocument = Document & { startViewTransition?: (update: () => void) => { finished: Promise<unknown> } }

export default class extends Controller<HTMLElement> {
  static targets = ["stage", "previous", "next", "heading"]
  static values = { title: String }

  declare readonly stageTarget: HTMLElement
  declare readonly hasStageTarget: boolean
  declare readonly previousTarget: HTMLElement
  declare readonly hasPreviousTarget: boolean
  declare readonly nextTarget: HTMLElement
  declare readonly hasNextTarget: boolean
  declare readonly headingTarget: HTMLElement
  declare readonly hasHeadingTarget: boolean
  declare readonly titleValue: string

  private frame: HTMLElement | null = null
  private gesture: { id: number; x: number; y: number; tilted: boolean } | null = null

  connect(): void {
    if (this.titleValue && document.title !== this.titleValue) document.title = this.titleValue
    this.frame = this.element.closest("turbo-frame")
    this.frame?.addEventListener("turbo:before-frame-render", this.beforeFrameRender)
    if (focusAfterStep) {
      this.focusControl(focusAfterStep)
      focusAfterStep = null
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
    focusAfterStep = document.activeElement === event.currentTarget ? direction : null
    beginStep(direction)
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
    // At an end the control is a disabled button: nothing happens. From
    // 720px ◀ ▶ are hidden (no position line either): a swipe does nothing.
    if (!(control instanceof HTMLAnchorElement)) return
    if (control.checkVisibility?.() ?? control.offsetParent !== null) control.click()
  }

  cancel(): void {
    this.gesture = null
  }

  // ---- The step's transition ----

  private readonly beforeFrameRender = (event: Event): void => {
    const detail = (event as CustomEvent<{ render?: FrameRender }>).detail
    const render = detail?.render
    const doc = document as ViewTransitionDocument
    if (!document.documentElement.dataset.subViewStep || !render || motionReduced() || typeof doc.startViewTransition !== "function") return
    detail.render = (currentElement, newElement) => {
      stepTransition = doc.startViewTransition!(() => render(currentElement, newElement))
    }
  }

  private focusControl(direction: Direction): void {
    const control = direction === "previous" ? (this.hasPreviousTarget ? this.previousTarget : null) : this.hasNextTarget ? this.nextTarget : null
    if (control instanceof HTMLAnchorElement) control.focus()
    else if (this.hasHeadingTarget) this.headingTarget.focus()
  }
}
