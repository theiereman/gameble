// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import {
  STREAM_EVENT_ACTION,
  STREAM_FOCUS_ACTION,
  STREAM_RELOAD_ACTION,
  STREAM_VISIT_ACTION,
  registerStreamActions,
  streamSignal,
  visitablePath,
} from "./stream_actions"
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
    expect(streamSignal("reactions-updated")).toBe("reactions-updated")
    expect(streamSignal("duels-updated")).toBe("duels-updated")
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
    target.addEventListener("gameble:reactions-updated", (event) => seen.push(event.type))
    target.addEventListener("gameble:bank-updated", (event) => seen.push(event.type))
    target.addEventListener("gameble:duels-updated", (event) => seen.push(event.type))
    const action = registered(target)

    action.call(streamElement({ event: "trades-updated" }))
    action.call(streamElement({ event: "friends-updated" }))
    action.call(streamElement({ event: "reactions-updated" }))
    action.call(streamElement({ event: "bank-updated" }))
    action.call(streamElement({ event: "duels-updated" }))

    expect(seen).toEqual([
      "gameble:trades-updated",
      "gameble:friends-updated",
      "gameble:reactions-updated",
      "gameble:bank-updated",
      "gameble:duels-updated",
    ])
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

describe("the gameble-focus stream action", () => {
  it("focuses its target without scrolling", () => {
    const turbo = { StreamActions: {} as Record<string, StreamAction> }
    registerStreamActions(turbo, new EventTarget())
    const calls: unknown[] = []
    const element = { targetElements: [{ focus: (options: unknown) => calls.push(options) }] } as unknown as Element

    turbo.StreamActions[STREAM_FOCUS_ACTION]?.call(element)

    expect(calls).toEqual([{ preventScroll: true }])
  })

  it("does nothing when the target is gone", () => {
    const turbo = { StreamActions: {} as Record<string, StreamAction> }
    registerStreamActions(turbo, new EventTarget())

    expect(() =>
      turbo.StreamActions[STREAM_FOCUS_ACTION]?.call({ targetElements: [] } as unknown as Element),
    ).not.toThrow()
  })
})

describe("the gameble-reload stream action", () => {
  it("reloads its frames from the page's own address and leaves other targets alone", () => {
    const turbo = { StreamActions: {} as Record<string, StreamAction> }
    registerStreamActions(turbo, new EventTarget())
    const frame = {
      tagName: "TURBO-FRAME",
      attributes: {} as Record<string, string>,
      setAttribute(name: string, value: string) {
        this.attributes[name] = value
      },
    }
    const other = {
      tagName: "DIV",
      attributes: {} as Record<string, string>,
      setAttribute(name: string, value: string) {
        this.attributes[name] = value
      },
    }

    turbo.StreamActions[STREAM_RELOAD_ACTION]?.call({ targetElements: [frame, other] } as unknown as Element)

    expect(frame.attributes).toEqual({ src: window.location.href })
    expect(other.attributes).toEqual({})
  })
})

describe("the gameble-visit stream action", () => {
  it("visits a path of this site and nothing else", () => {
    const visited: string[] = []
    const turbo = {
      StreamActions: {} as Record<string, StreamAction>,
      visit: (location: string) => void visited.push(location),
    }
    registerStreamActions(turbo, new EventTarget())
    const action = turbo.StreamActions[STREAM_VISIT_ACTION]!
    action.call(streamElement({ location: "/en/market" }))
    action.call(streamElement({ location: "//evil.example" }))
    action.call(streamElement({ location: "https://evil.example" }))
    action.call(streamElement({}))
    expect(visited).toEqual(["/en/market"])
    expect(visitablePath("/\\evil")).toBeNull()
  })
})
