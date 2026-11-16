import { describe, expect, it } from "vitest"
import { BLAST_AT, CAPSULE_T, quakeFrames } from "./booster_capsule_timeline"
import { ROW_REST, cardFlight, flightRank, flightTurn, leavesAfterBlast } from "./booster_deal_flight"
import { pilePose } from "./booster_motion"

const msFromTouch = ({ keyframes, options }: ReturnType<typeof cardFlight>) =>
  keyframes.map((frame) =>
    Math.round(BLAST_AT + Number(options.delay) + Number(frame.offset) * Number(options.duration)),
  )

describe("the cards' flight out of the capsule", () => {
  it("sends the centre card first and the outer ones 48 ms later per rank, each tilted 12° per step out", () => {
    expect([0, 1, 2, 3, 4].map((index) => flightRank(index, 5))).toEqual([2, 1, 0, 1, 2])
    expect([0, 1, 2, 3, 4].map((index) => flightTurn(index, 5))).toEqual([-24, -12, 0, 12, 24])
    expect([0, 1, 2].map(leavesAfterBlast)).toEqual([156, 204, 252])
  })

  it("keeps the reference's beats for the leftmost of five: out, arc, squash, bounce, rest, then two floats", () => {
    const flight = cardFlight({
      dx: 236,
      dy: 0,
      index: 0,
      rank: 2,
      turn: -24,
      height: 146,
      rest: ROW_REST,
      floats: true,
    })

    expect(msFromTouch(flight)).toEqual([1146, 1152, 1362, 1530, 1644, 1752, 2220, 2640, 3060, 3480, 3900])
    expect(flight.keyframes[0]).toMatchObject({
      opacity: 0,
      transform: "translate(236px, 0px) scale(0.2, 0.2) rotate(0deg)",
    })
    expect(flight.keyframes[2].transform).toBe("translate(106.2px, -74px) scale(1.14, 1.14) rotate(-24deg)")
    expect(flight.keyframes.at(-1)).toMatchObject({
      opacity: 1,
      transform: "translate(0px, 0px) scale(1, 1) rotate(0deg)",
    })
  })

  it("scales the reference's pixel distances to the real card's height", () => {
    const flight = cardFlight({
      dx: 0,
      dy: 100,
      index: 2,
      rank: 0,
      turn: 0,
      height: 292,
      rest: ROW_REST,
      floats: false,
    })

    expect(flight.keyframes[2].transform).toBe("translate(0px, -103px) scale(1.14, 1.14) rotate(0deg)")
    expect(flight.keyframes[3].transform).toBe("translate(0px, 10px) scale(1.1, 0.88) rotate(0deg)")
  })

  it("lands a phone's card on its pile pose, with no float", () => {
    const flight = cardFlight({
      dx: 0,
      dy: -200,
      index: 2,
      rank: 0,
      turn: 0,
      height: 146,
      rest: pilePose(2),
      floats: false,
    })

    expect(msFromTouch(flight).at(-1)).toBe(1656)
    expect(flight.keyframes.at(-1)?.transform).toBe("translate(0px, 10px) scale(0.96, 0.96) rotate(-2.8deg)")
  })
})

describe("the blast's quake", () => {
  it("first jolts the stage 1038 ms after the touch and is still by 1260 ms", () => {
    const moves = quakeFrames().map((frame) => Math.round(Number(frame.offset) * CAPSULE_T - CAPSULE_T * 0.13))

    expect(moves.slice(2, -1)).toEqual([1038, 1074, 1110, 1152, 1200, 1260])
  })
})
