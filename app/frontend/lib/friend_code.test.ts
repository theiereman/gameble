import { describe, expect, it } from "vitest"
import { formatFriendCode } from "./friend_code"

describe("formatFriendCode", () => {
  it("uppercases and adds the dash once four characters are typed", () => {
    expect(formatFriendCode("abc", 3, false)).toEqual({ value: "ABC", caret: 3 })
    expect(formatFriendCode("abcd", 4, false)).toEqual({ value: "ABCD-", caret: 5 })
    expect(formatFriendCode("ABCD-e", 6, false)).toEqual({ value: "ABCD-E", caret: 6 })
  })

  it("lets a backspace remove the dash instead of adding it back", () => {
    expect(formatFriendCode("ABCD", 4, true)).toEqual({ value: "ABCD", caret: 4 })
  })

  it("formats a pasted code and drops anything past eight characters", () => {
    expect(formatFriendCode("8f2dk9xm", 8, false)).toEqual({ value: "8F2D-K9XM", caret: 9 })
    expect(formatFriendCode(" 8f2d k9xm-zz ", 14, false)).toEqual({ value: "8F2D-K9XM", caret: 9 })
  })

  it("keeps the caret after the same character when editing in the middle", () => {
    expect(formatFriendCode("AB2CD-EFG", 3, false)).toEqual({ value: "AB2C-DEFG", caret: 3 })
    expect(formatFriendCode("ABCDEFGH", 0, false)).toEqual({ value: "ABCD-EFGH", caret: 0 })
  })
})
