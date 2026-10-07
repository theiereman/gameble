import { describe, expect, it } from "vitest"
import { matchesWord } from "./confirm_word"

describe("matchesWord", () => {
  it("accepts the word in any case, with surrounding spaces", () => {
    expect(matchesWord("SUPPRIMER", "SUPPRIMER")).toBe(true)
    expect(matchesWord("supprimer", "SUPPRIMER")).toBe(true)
    expect(matchesWord("  Supprimer\n", "SUPPRIMER")).toBe(true)
    expect(matchesWord("delete", "DELETE")).toBe(true)
  })

  it("refuses anything else", () => {
    expect(matchesWord("", "SUPPRIMER")).toBe(false)
    expect(matchesWord("SUPPRIME", "SUPPRIMER")).toBe(false)
    expect(matchesWord("SUPPRIMERR", "SUPPRIMER")).toBe(false)
    expect(matchesWord("SUP PRIMER", "SUPPRIMER")).toBe(false)
    expect(matchesWord("DELETE", "SUPPRIMER")).toBe(false)
  })

  it("never matches an empty word", () => {
    expect(matchesWord("", "")).toBe(false)
  })
})
