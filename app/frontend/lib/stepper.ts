import { writeText } from "./dom_writes"

export type StepperView = {
  value: number
  max: number
  label: string
  valueText: string
  maxText: string
  maxPhoneText: string
}

export const STEPPER = ".stepper"

export function reflectStepper(
  stepper: HTMLElement,
  { value, max, label, valueText, maxText, maxPhoneText }: StepperView,
): void {
  stepper.setAttribute("aria-label", label)
  stepper.setAttribute("aria-valuenow", String(value))
  stepper.setAttribute("aria-valuemax", String(max))
  stepper.setAttribute("aria-valuetext", valueText)
  writeText(stepper.querySelector(".stepper__value"), `×${value}`)
  writeText(stepper.querySelector(".stepper__max"), maxText)
  writeText(stepper.querySelector(".stepper__max-phone"), maxPhoneText)
  const fewer = stepper.querySelector<HTMLButtonElement>(".stepper__button--fewer")
  const more = stepper.querySelector<HTMLButtonElement>(".stepper__button--more")
  if (fewer) fewer.disabled = value <= 1
  if (more) more.disabled = value >= max
}

export function stepperKey(key: string): 1 | -1 | "min" | "max" | null {
  switch (key) {
    case "ArrowUp":
    case "ArrowRight":
    case "+":
    case "=":
      return 1
    case "ArrowDown":
    case "ArrowLeft":
    case "-":
    case "_":
      return -1
    case "Home":
      return "min"
    case "End":
      return "max"
    default:
      return null
  }
}

export function keyedValue(key: string, value: number, max: number): number | null {
  const step = stepperKey(key)
  if (step === null) return null
  return clampValue(step === "min" ? 1 : step === "max" ? max : value + step, max)
}

export function clampValue(value: number, max: number): number {
  return Math.min(max, Math.max(1, value))
}

function shown(stepper: Element): { value: number; max: number } {
  return { value: Number(stepper.getAttribute("aria-valuenow")), max: Number(stepper.getAttribute("aria-valuemax")) }
}

export function quantityFromKey(event: KeyboardEvent): number | null {
  const stepper = event.currentTarget as HTMLElement
  const { value, max } = shown(stepper)
  const next = keyedValue(event.key, value, max)
  if (next === null) return null
  event.preventDefault()
  event.stopPropagation()
  return next === value ? null : next
}

export function quantityFromButton(event: Event): number | null {
  const button = event.currentTarget as HTMLElement
  const stepper = button.closest(STEPPER)
  if (!stepper) return null
  const { value, max } = shown(stepper)
  const next = clampValue(value + Number(button.dataset.step), max)
  return next === value ? null : next
}

// A mousedown on a button would move the focus off the spinbutton.
export function keepStepperFocus(event: Event): void {
  event.preventDefault()
}
