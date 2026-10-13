import { describe, expect, it } from "vitest"
import { type MenuKeyEvent, menuDigit } from "./menu_key"

function press(overrides: Partial<MenuKeyEvent>): MenuKeyEvent {
  return { key: "", code: "", ctrlKey: false, altKey: false, metaKey: false, repeat: false, ...overrides }
}

describe("menuDigit", () => {
  it("reads the digit from the key", () => {
    expect(menuDigit(press({ key: "7", code: "Digit7" }))).toBe("7")
    expect(menuDigit(press({ key: "1", code: "Digit1" }))).toBe("1")
    expect(menuDigit(press({ key: "9", code: "Digit9" }))).toBe("9")
  })

  it("reads the digit row's code when the layout types another character (AZERTY without Shift)", () => {
    expect(menuDigit(press({ key: "è", code: "Digit7" }))).toBe("7")
  })

  it("reads the digit row's code with Shift", () => {
    expect(menuDigit(press({ key: "7", code: "Digit7" }))).toBe("7")
    expect(menuDigit(press({ key: "&", code: "Digit7" }))).toBe("7")
  })

  it("reads a numpad digit from its key, never from its code", () => {
    expect(menuDigit(press({ key: "7", code: "Numpad7" }))).toBe("7")
    expect(menuDigit(press({ key: "Home", code: "Numpad7" }))).toBeUndefined()
  })

  it("names nothing with Ctrl, Alt or Meta, or on a repeat", () => {
    expect(menuDigit(press({ key: "7", code: "Digit7", ctrlKey: true }))).toBeUndefined()
    expect(menuDigit(press({ key: "7", code: "Digit7", altKey: true }))).toBeUndefined()
    expect(menuDigit(press({ key: "7", code: "Digit7", metaKey: true }))).toBeUndefined()
    expect(menuDigit(press({ key: "7", code: "Digit7", repeat: true }))).toBeUndefined()
  })

  it("names nothing for 0 or a letter", () => {
    expect(menuDigit(press({ key: "0", code: "Digit0" }))).toBeUndefined()
    expect(menuDigit(press({ key: "à", code: "Digit0" }))).toBeUndefined()
    expect(menuDigit(press({ key: "a", code: "KeyA" }))).toBeUndefined()
    expect(menuDigit(press({ key: "q", code: "KeyQ" }))).toBeUndefined()
  })
})
