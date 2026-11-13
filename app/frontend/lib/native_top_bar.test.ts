import { describe, expect, it, vi } from "vitest"
import {
  anyDialogOpen,
  cachedBySource,
  closePanels,
  oncePerTask,
  readCounts,
  renderStreamsFully,
  sameState,
  togglePanel,
  type TopBarState,
} from "./native_top_bar"

function root(elements: Record<string, { textContent?: string; hidden?: boolean }>) {
  return { querySelector: (selector: string) => elements[selector] ?? null } as unknown as ParentNode
}

function panels(open: string[] = []) {
  const shown = new Set(open)
  const panel = (id: string) => ({
    matches: () => shown.has(id),
    showPopover: () => void shown.add(id),
    hidePopover: () => void shown.delete(id),
  })
  return {
    shown,
    host: {
      querySelector: (selector: string) => panel(selector),
      querySelectorAll: () => [...shown].map(panel),
    } as unknown as ParentNode,
  }
}

const state: TopBarState = {
  standard: "10",
  special: "0",
  bell: "2",
  menuBadge: "",
  capsules: "10",
  friends: "",
  trades: "1",
  avatar: "data:image/png;base64,AA",
}

describe("readCounts", () => {
  it("reads every count as the page displays it", () => {
    const counts = readCounts(
      root({
        ".bank-counter__item:not(.bank-counter__item--special) .bank-counter__count": { textContent: " 1,204 " },
        ".bank-counter__item--special .bank-counter__count": { textContent: "3" },
        "[data-bell-target=count]": { textContent: "12", hidden: false },
        "#player-menu-badge .player-chip__badge": { textContent: "4" },
        "#player-menu-invitations-badge .menu-item__badge": { textContent: "2" },
        "#tab-trades-badge .tab-bar__badge": { textContent: " 5 " },
      }),
    )

    expect(counts).toEqual({
      standard: "1,204",
      special: "3",
      bell: "12",
      menuBadge: "4",
      capsules: "1207",
      friends: "2",
      trades: "5",
    })
  })

  it("leaves the capsule tab without a badge when no capsule waits", () => {
    const counts = readCounts(
      root({
        ".bank-counter__item:not(.bank-counter__item--special) .bank-counter__count": { textContent: "0" },
        ".bank-counter__item--special .bank-counter__count": { textContent: "0" },
      }),
    )

    expect(counts.capsules).toBe("")
  })

  it("leaves the bell empty while its count is hidden", () => {
    expect(readCounts(root({ "[data-bell-target=count]": { textContent: "12", hidden: true } })).bell).toBe("")
  })

  it("reads an absent control as empty", () => {
    expect(readCounts(root({}))).toEqual({
      standard: "",
      special: "",
      bell: "",
      menuBadge: "",
      capsules: "",
      friends: "",
      trades: "",
    })
  })
})

describe("anyDialogOpen", () => {
  it("looks for an open dialog", () => {
    expect(anyDialogOpen(root({ "dialog[open]": {} }))).toBe(true)
    expect(anyDialogOpen(root({}))).toBe(false)
  })
})

describe("sameState", () => {
  it("is false before the first report", () => {
    expect(sameState(null, state)).toBe(false)
  })

  it("compares every field", () => {
    expect(sameState({ ...state }, state)).toBe(true)
    expect(sameState({ ...state, avatar: "" }, state)).toBe(false)
  })
})

describe("togglePanel", () => {
  it("opens the wanted panel", () => {
    const { host, shown } = panels()
    togglePanel(host, "bell")
    expect([...shown]).toEqual(["#bell-panel"])
  })

  it("closes the wanted panel when it is already open", () => {
    const { host, shown } = panels(["#bell-panel"])
    togglePanel(host, "bell")
    expect([...shown]).toEqual([])
  })

  it("trades one panel for the other", () => {
    const { host, shown } = panels(["#bell-panel"])
    togglePanel(host, "menu")
    expect([...shown]).toEqual(["#player-menu"])
  })

  it("closes whatever is open when no panel is wanted", () => {
    const { host, shown } = panels(["#player-menu"])
    togglePanel(host, null)
    expect([...shown]).toEqual([])
  })
})

describe("closePanels", () => {
  it("closes every open panel", () => {
    const { host, shown } = panels(["#bell-panel", "#player-menu"])
    closePanels(host)
    expect(shown.size).toBe(0)
  })
})

describe("oncePerTask", () => {
  it("runs once for any number of calls before the task, and again after it", () => {
    const tasks: Array<() => void> = []
    const run = vi.fn()
    const schedule = oncePerTask(run, (task) => tasks.push(task))

    schedule()
    schedule()
    expect(tasks).toHaveLength(1)
    tasks.shift()?.()
    expect(run).toHaveBeenCalledTimes(1)

    schedule()
    expect(tasks).toHaveLength(1)
  })
})

describe("cachedBySource", () => {
  it("draws a source only once", async () => {
    const rasterize = vi.fn(async (source: string) => `png:${source}`)
    const avatar = cachedBySource(rasterize)

    expect(await avatar("a")).toBe("png:a")
    expect(await avatar("a")).toBe("png:a")
    expect(await avatar("b")).toBe("png:b")
    expect(rasterize).toHaveBeenCalledTimes(2)
  })

  it("gives nothing when the drawing fails, and tries again next time", async () => {
    const rasterize = vi.fn(async (): Promise<string> => {
      throw new Error("not decodable")
    })
    const avatar = cachedBySource(rasterize)

    expect(await avatar("a")).toBe("")
    expect(await avatar("a")).toBe("")
    expect(rasterize).toHaveBeenCalledTimes(2)
  })
})

describe("renderStreamsFully", () => {
  function landingStream(events: EventTarget) {
    let finish = (): void => {}
    const rendered = new Promise<void>((resolve) => (finish = resolve))
    const stream = Object.assign(new EventTarget(), { render: () => rendered })
    const land = (): void => {
      const event = new Event("turbo:before-stream-render")
      Object.defineProperty(event, "target", { value: stream })
      events.dispatchEvent(event)
    }
    return { land, finish }
  }

  it("settles only once every stream the message landed has applied its action", async () => {
    const events = new EventTarget()
    const first = landingStream(events)
    const second = landingStream(events)
    let settled = false

    const rendering = renderStreamsFully(() => {
      first.land()
      second.land()
    }, events).then(() => (settled = true))

    first.finish()
    await Promise.resolve()
    await Promise.resolve()
    expect(settled).toBe(false)

    second.finish()
    await rendering
    expect(settled).toBe(true)
  })
})
