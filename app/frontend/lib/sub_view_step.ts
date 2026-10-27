export type StepDirection = "previous" | "next"

export type FocusWish = StepDirection | null

export const PHONE_WIDTH = "(max-width: 719px)"

const STEP_TIMEOUT_MS = 5000

let focusWish: FocusWish = null
let stepTransition: { finished: Promise<unknown> } | null = null
let stepTimer: ReturnType<typeof setTimeout> | undefined
let pausedMeta: { element: HTMLMetaElement; content: string } | null = null
let currentStep = 0

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

function stepLoaded(): void {
  document.removeEventListener("turbo:load", stepLoaded)
  const transition = stepTransition
  const step = currentStep
  if (transition) void transition.finished.catch(ignoreSkippedTransition).then(() => step === currentStep && endStep())
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

function ignoreSkippedTransition(): void {
  // A skipped transition rejects its finished promise; the step ends either way.
}
