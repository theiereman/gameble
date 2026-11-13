import typedAmountsJson from "../../../test/fixtures/files/typed_amounts.json?raw"
import { describe, expect, it } from "vitest"
import { amountDigits, editOf, groupDigits, regroup, type Edit } from "./amount"

const NBSP = "\u00A0"
const rows: Array<{ text: string; digits: string | null }> = JSON.parse(typedAmountsJson)

function typing(text: string, before: string, edit: Edit = "insert", locale = "en") {
  const caret = text.indexOf("|")
  return regroup({ text: text.replace("|", ""), caret }, before, edit, locale)
}

function shown(result: { text: string; caret: number } | null): string | null {
  return result && `${result.text.slice(0, result.caret)}|${result.text.slice(result.caret)}`
}

describe("amountDigits", () => {
  it.each(rows)("reads $text as the digits $digits, like the server", ({ text, digits }) => {
    expect(amountDigits(text)).toBe(digits)
  })
})

describe("groupDigits", () => {
  it("groups thousands with the locale's delimiter", () => {
    expect(groupDigits("8000000", "en")).toBe("8,000,000")
    expect(groupDigits("8000000", "fr")).toBe(`8${NBSP}000${NBSP}000`)
    expect(groupDigits("800", "fr")).toBe("800")
    expect(groupDigits("", "en")).toBe("")
  })
})

describe("regroup", () => {
  it("groups the digits as they are typed and keeps the caret after the typed digit", () => {
    expect(shown(typing("8000|", "800"))).toBe("8,000|")
    expect(shown(typing("80,0000|", "80,000"))).toBe("800,000|")
    expect(shown(typing("8000000|", "800000", "insert", "fr"))).toBe(`8${NBSP}000${NBSP}000|`)
  })

  it("keeps the caret in place when a digit is typed in the middle", () => {
    expect(shown(typing("1,29|34", "1,234"))).toBe("12,9|34")
    expect(shown(typing("9|1,234", "1,234"))).toBe("9|1,234")
  })

  it("keeps the caret in place when a digit is deleted", () => {
    expect(shown(typing("1,2|4", "1,234", "deleteBackward"))).toBe("12|4")
    expect(shown(typing("12|,456", "123,456", "deleteBackward"))).toBe("12|,456")
  })

  it("deletes the digit before a separator erased backwards", () => {
    expect(shown(typing("1|234", "1,234", "deleteBackward"))).toBe("|234")
    expect(shown(typing("12|345,678", "12,345,678", "deleteBackward"))).toBe("1|,345,678")
  })

  it("deletes the digit after a separator erased forwards", () => {
    expect(shown(typing("1|234", "1,234", "deleteForward"))).toBe("1|34")
  })

  it("drops a typed delimiter and regroups a pasted amount", () => {
    expect(shown(typing("1,234,|", "1,234"))).toBe("1,234|")
    expect(shown(typing("8 000 000|", ""))).toBe("8,000,000|")
    expect(shown(typing("8,000,000|", "", "insert", "fr"))).toBeNull()
  })

  it("leaves anything that is not an amount as typed, for the refusal to name it", () => {
    expect(typing("12x|", "12")).toBeNull()
    expect(typing("1.5|", "1.")).toBeNull()
    expect(typing("12,5|", "12,", "insert", "fr")).toBeNull()
  })

  it("empties the field when the last digit goes", () => {
    expect(shown(typing("|", "1", "deleteBackward"))).toBe("|")
  })
})

describe("editOf", () => {
  it("tells a backward or forward deletion from any other edit", () => {
    expect(editOf("deleteContentBackward")).toBe("deleteBackward")
    expect(editOf("deleteContentForward")).toBe("deleteForward")
    expect(editOf("insertFromPaste")).toBe("insert")
    expect(editOf(undefined)).toBe("insert")
  })
})
