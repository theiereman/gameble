import { describe, expect, it } from "vitest"
import { showLatestRound, showRound } from "./duel_history"

function rounds(): HTMLElement {
  const root = document.createElement("div")
  root.innerHTML = `
    <div data-history-round="1" hidden></div>
    <div data-history-round="2" hidden></div>
    <div data-history-round="3"></div>`
  return root
}

const hiddenOnes = (root: HTMLElement) =>
  Array.from(root.querySelectorAll<HTMLElement>("[data-history-round]")).map((round) => round.hidden)

describe("showRound", () => {
  it("shows one round and hides the others", () => {
    const root = rounds()
    showRound(root, "2")
    expect(hiddenOnes(root)).toEqual([true, false, true])
  })

  it("keeps the shown round when the asked one does not exist", () => {
    const root = rounds()
    showRound(root, "9")
    expect(hiddenOnes(root)).toEqual([true, true, false])
  })

  it("shows the latest round once the reveal is gone", () => {
    const root = rounds()
    showRound(root, "1")
    showLatestRound(root)
    expect(hiddenOnes(root)).toEqual([true, true, false])
  })
})
