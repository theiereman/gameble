// The quantity stepper (DESIGN.md, Quantity stepper; EXPERIENCE.md,
// Quantity stepper; story 5.7): a dark pill "−", "×N", "+", then "/max"
// ("sur N" under it on the phone). The pill is the spinbutton and the one
// tab stop: arrows or + and − change the copies, Home and End go to 1 and
// to the maximum. Its buttons are for the pointer and keep the focus on
// the pill.
import type { KeyboardEvent } from "react"
import { stepperKey } from "../lib/trade_board"

export type QuantityStepperProps = {
  value: number
  max: number
  /** "Exemplaires de Celeste". */
  label: string
  /** "2 sur 3". */
  valueText: string
  /** "/3" and "sur 3". */
  maxText: string
  maxPhoneText: string
  more: string
  fewer: string
  onChange: (value: number) => void
}

export default function QuantityStepper({ value, max, label, valueText, maxText, maxPhoneText, more, fewer, onChange }: QuantityStepperProps) {
  const change = (next: number) => {
    const clamped = Math.min(max, Math.max(1, next))
    if (clamped !== value) onChange(clamped)
  }

  const onKeyDown = (event: KeyboardEvent<HTMLSpanElement>) => {
    const step = stepperKey(event.key)
    if (step === null) return
    event.preventDefault()
    event.stopPropagation()
    change(step === "min" ? 1 : step === "max" ? max : value + step)
  }

  // A press on a button keeps the focus where it is (the pill, or wherever it was).
  const keepFocus = (event: { preventDefault: () => void }) => event.preventDefault()

  return (
    <span
      className="stepper"
      role="spinbutton"
      tabIndex={0}
      aria-label={label}
      aria-valuenow={value}
      aria-valuemin={1}
      aria-valuemax={max}
      aria-valuetext={valueText}
      onKeyDown={onKeyDown}
    >
      <button
        type="button"
        className="stepper__button stepper__button--fewer"
        tabIndex={-1}
        aria-label={fewer}
        disabled={value <= 1}
        onMouseDown={keepFocus}
        onClick={() => change(value - 1)}
      >
        −
      </button>
      <span className="stepper__value" aria-hidden="true">
        ×{value}
      </span>
      <button
        type="button"
        className="stepper__button stepper__button--more"
        tabIndex={-1}
        aria-label={more}
        disabled={value >= max}
        onMouseDown={keepFocus}
        onClick={() => change(value + 1)}
      >
        +
      </button>
      <small className="stepper__max" aria-hidden="true">
        {maxText}
      </small>
      <small className="stepper__max-phone" aria-hidden="true">
        {maxPhoneText}
      </small>
    </span>
  )
}
