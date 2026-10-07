import type { KeyboardEvent } from "react"
import { stepperKey } from "../lib/trade_board"

export type QuantityStepperProps = {
  value: number
  max: number
  label: string
  valueText: string
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

  // A mousedown on a button would move the focus off the spinbutton.
  const keepFocus =(event: { preventDefault: () => void }) => event.preventDefault()

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
