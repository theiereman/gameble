import orderReachingJson from "../../../test/fixtures/files/order_reaching.json?raw"
import { describe, expect, it } from "vitest"
import { nextRarity, parsePrice, reachedRarities, sentence, type Minimums, type OrderStrings } from "./order_form"

const fixture: { minimums: Minimums; cases: Array<{ price: number; reached: string[] }> } =
  JSON.parse(orderReachingJson)
const minimums = fixture.minimums

const strings: OrderStrings = {
  some: "Your price reaches %{reached}. %{next} from %{amount}.",
  all: "Your price reaches every rarity.",
  none: "%{next} from %{amount}.",
  reached: { common: "commons", uncommon: "uncommons", rare: "rares", epic: "epics", legendary: "legendaries" },
  next: { common: "Commons", uncommon: "Uncommons", rare: "Rares", epic: "Epics", legendary: "Legendaries" },
}

describe("reachedRarities", () => {
  it.each(fixture.cases)("agrees with the server's fixture at $price", ({ price, reached }) => {
    expect(reachedRarities(minimums, price)).toEqual(reached)
  })

  it("reaches nothing without a price", () => {
    expect(reachedRarities(minimums, null)).toEqual([])
  })
})

describe("nextRarity", () => {
  it("is the cheapest rarity not reached, the lowest with no price, and none once all are reached", () => {
    expect(nextRarity(minimums, 50)).toBe("rare")
    expect(nextRarity(minimums, null)).toBe("common")
    expect(nextRarity(minimums, 70_000)).toBeNull()
  })
})

describe("sentence", () => {
  it("names the rarities reached and the next one's price", () => {
    expect(sentence(strings, minimums, 100, "en")).toBe(
      "Your price reaches commons, uncommons, and rares. Epics from 223.",
    )
  })

  it("says every rarity once all are reached", () => {
    expect(sentence(strings, minimums, 80_000, "en")).toBe("Your price reaches every rarity.")
  })

  it("gives the lowest rarity's price under every minimum", () => {
    expect(sentence(strings, minimums, null, "en")).toBe("Commons from 13.")
    expect(sentence(strings, minimums, 5, "en")).toBe("Commons from 13.")
  })

  it("joins the French list with et", () => {
    const french = {
      ...strings,
      reached: { ...strings.reached, common: "communes", uncommon: "peu communes", rare: "rares" },
    }
    expect(sentence(french, minimums, 100, "fr")).toContain("communes, peu communes et rares")
  })
})

describe("parsePrice", () => {
  it("reads grouped digits and refuses blanks, zero and text", () => {
    expect(parsePrice("1,000")).toBe(1000)
    expect(parsePrice("")).toBeNull()
    expect(parsePrice("0")).toBeNull()
    expect(parsePrice("abc")).toBeNull()
  })
})
