import { describe, expect, it } from "vitest"
import { STREAM_EVENT_ACTION, registerStreamActions, streamSignal } from "./stream_actions"
import type { StreamAction } from "./turbo"

function streamElement(attributes: Record<string, string>): Element {
  return { getAttribute: (name: string) => attributes[name] ?? null } as unknown as Element
}

function registered(target: EventTarget): StreamAction {
  const turbo = { StreamActions: {} as Record<string, StreamAction> }
  registerStreamActions(turbo, target)
  const action = turbo.StreamActions[STREAM_EVENT_ACTION]
  if (!action) throw new Error("not registered")
  return action
}

describe("streamSignal", () => {
  it("names the listed signals only", () => {
    expect(streamSignal("trades-updated")).toBe("trades-updated")
    expect(streamSignal("friends-updated")).toBe("friends-updated")
    expect(streamSignal("toast")).toBeNull()
    expect(streamSignal("")).toBeNull()
    expect(streamSignal(null)).toBeNull()
    expect(streamSignal(undefined)).toBeNull()
  })
})

describe("the gameble-event stream action", () => {
  it("raises the gameble event its signal names", () => {
    const target = new EventTarget()
    const seen: string[] = []
    target.addEventListener("gameble:trades-updated", (event) => seen.push(event.type))
    target.addEventListener("gameble:friends-updated", (event) => seen.push(event.type))
    const action = registered(target)

    action.call(streamElement({ event: "trades-updated" }))
    action.call(streamElement({ event: "friends-updated" }))

    expect(seen).toEqual(["gameble:trades-updated", "gameble:friends-updated"])
  })

  it("raises nothing for an unknown or missing signal", () => {
    const target = new EventTarget()
    const seen: string[] = []
    target.addEventListener("gameble:toast", (event) => seen.push(event.type))
    const action = registered(target)

    action.call(streamElement({ event: "toast" }))
    action.call(streamElement({}))

    expect(seen).toEqual([])
  })
})
