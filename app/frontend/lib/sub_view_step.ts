// A step of the card detail: its ◀ ▶.
//
// From the press until Turbo's visit has loaded and the card's transition
// has ended, <html> carries `data-sub-view-step=previous|next`: the star
// field does not shift (starfield_controller.ts) and the screen does not
// slide (styles/shell.css), as a step is no screen change. ◀ ▶ slide the
// card toward the step (styles/card-detail.css).
//
// Turbo's own visit for the new URL renders no body, but would start a
// View Transition of its own, which would cut the card's short: during a
// step the page's view-transition meta reads "none", so Turbo starts none
// (the merged head brings the meta back). The step's state lives here, as
// the detail that began it is replaced by the step.

export type StepDirection = "previous" | "next"

export type FocusWish = "previous" | "next" | null

/** The phone's width, where the detail is a sub-view of its own. */
export const PHONE_WIDTH = "(max-width: 719px)"

/** Ends a step even when its visit never loads (an error, a cancel). */
const STEP_TIMEOUT_MS = 5000

let focusWish: FocusWish = null
let stepTransition: { finished: Promise<unknown> } | null = null
let stepTimer: ReturnType<typeof setTimeout> | undefined
let pausedMeta: { element: HTMLMetaElement; content: string } | null = null
let currentStep = 0

// Ends the step, and with it its focus wish: on the normal path the new
// detail's connect has consumed it already (the frame renders before the
// promoted visit loads, and a View Transition's update runs before it
// finishes); after a failed or cancelled visit (the fallback timer) a later
// detail must not act on it.
function endStep(): void {
  focusWish = null
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

export function beginStep(direction: StepDirection, focus: FocusWish): void {
  endStep()
  currentStep++
  focusWish = focus
  document.documentElement.dataset.subViewStep = direction
  const meta = document.head.querySelector<HTMLMetaElement>("meta[name=view-transition]")
  if (meta) {
    pausedMeta = { element: meta, content: meta.content }
    meta.content = "none"
  }
  document.addEventListener("turbo:load", stepLoaded)
  stepTimer = setTimeout(endStep, STEP_TIMEOUT_MS)
}

export function stepping(): boolean {
  return document.documentElement.dataset.subViewStep !== undefined
}

export function takeFocusWish(): FocusWish {
  const wish = focusWish
  focusWish = null
  return wish
}

export function trackStepTransition(transition: { finished: Promise<unknown> }): void {
  stepTransition = transition
}
