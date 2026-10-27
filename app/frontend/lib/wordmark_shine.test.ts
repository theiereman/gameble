import { afterEach, describe, expect, it, vi } from "vitest"
import sweepSvg from "../images/pixel/wordmark-sweep.svg?raw"
import shellCss from "../styles/shell.css?raw"
import shellTopBarCss from "../styles/shell-top-bar.css?raw"
import shellStatusCss from "../styles/shell-status.css?raw"
import shellControlsCss from "../styles/shell-controls.css?raw"
import shellScreensCss from "../styles/shell-screens.css?raw"
import {
  FRAME_ROWS,
  STEP_MS,
  SWEEPING,
  SWEEP_ANIMATION,
  SWEEP_STEPS,
  clearSweep,
  endSweep,
  startSweep,
} from "./wordmark_shine"

const shellStylesheet = [shellCss, shellTopBarCss, shellStatusCss, shellControlsCss, shellScreensCss].join("\n")

// A link stand-in: its attributes only.
class FakeLink {
  attributes = new Map<string, string>()
  hasAttribute(name: string) {
    return this.attributes.has(name)
  }
  setAttribute(name: string, value: string) {
    this.attributes.set(name, value)
  }
  removeAttribute(name: string) {
    this.attributes.delete(name)
  }
}

const sweeping = (link: FakeLink) => link.hasAttribute(SWEEPING)

function motion(value: "reduced" | "full" | undefined) {
  vi.stubGlobal("document", { documentElement: { dataset: { motion: value } } })
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("startSweep", () => {
  it("starts a sweep on a link at rest", () => {
    const link = new FakeLink()

    expect(startSweep(link)).toBe(true)
    expect(sweeping(link)).toBe(true)
  })

  it("leaves a running sweep alone", () => {
    const link = new FakeLink()
    startSweep(link)

    expect(startSweep(link)).toBe(false)
    expect(sweeping(link)).toBe(true)
  })

  it("starts a new sweep once the last one ended", () => {
    const link = new FakeLink()
    startSweep(link)
    endSweep(link, SWEEP_ANIMATION)

    expect(startSweep(link)).toBe(true)
  })

  it("starts nothing under reduced motion", () => {
    motion("reduced")
    const link = new FakeLink()

    expect(startSweep(link)).toBe(false)
    expect(sweeping(link)).toBe(false)
  })

  it("puts a sweep caught by reduced motion back at rest, and sweeps again once motion is back", () => {
    const link = new FakeLink()
    startSweep(link)

    motion("reduced")
    startSweep(link)
    expect(sweeping(link)).toBe(false)

    motion("full")
    expect(startSweep(link)).toBe(true)
  })

  it("follows the player's full motion over the system's preference", () => {
    motion("full")
    vi.stubGlobal("window", { matchMedia: () => ({ matches: true }) })

    expect(startSweep(new FakeLink())).toBe(true)
  })
})

describe("endSweep", () => {
  it("ends the sweep when its animation ends or is cancelled", () => {
    const link = new FakeLink()
    startSweep(link)

    endSweep(link, SWEEP_ANIMATION)

    expect(sweeping(link)).toBe(false)
  })

  it("ignores another animation's end", () => {
    const link = new FakeLink()
    startSweep(link)

    endSweep(link, "toast-drop")

    expect(sweeping(link)).toBe(true)
  })
})

describe("clearSweep", () => {
  it("puts a link restored mid-sweep back at rest", () => {
    const link = new FakeLink()
    link.setAttribute(SWEEPING, "")

    clearSweep(link)

    expect(sweeping(link)).toBe(false)
  })
})

describe("the stylesheet and the exported frames", () => {
  const rule = (selector: string) => {
    const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    return shellStylesheet.match(new RegExp(`${escaped} \\{([^}]*)\\}`))?.[1] ?? ""
  }
  const lastFrameRow = Math.max(
    ...[...sweepSvg.split('<g class="wordmark-sweep__frames">')[1].matchAll(/M\d+ (\d+)h/g)].map((m) => Number(m[1])),
  )
  const keyframes = shellStylesheet.match(/@keyframes wordmark-sweep \{([\s\S]*?)\n\}/)?.[1] ?? ""

  it("holds a rest frame and one frame per step", () => {
    expect(sweepSvg).toContain(`viewBox="0 0 66 ${FRAME_ROWS}"`)
    expect(Math.floor(lastFrameRow / FRAME_ROWS) + 1).toBe(SWEEP_STEPS + 1)
  })

  it("steps through every frame after the rest frame, one step at a time", () => {
    expect(rule(".top-bar__brand[data-sweeping] .wordmark-sweep__frames")).toContain(
      `animation: ${SWEEP_ANIMATION} ${SWEEP_STEPS * STEP_MS}ms steps(${SWEEP_STEPS}, jump-none);`,
    )
    expect(keyframes).toMatch(new RegExp(`from \\{\\s*transform: translateY\\(-${FRAME_ROWS}px\\);`))
    expect(keyframes).toMatch(new RegExp(`to \\{\\s*transform: translateY\\(-${SWEEP_STEPS * FRAME_ROWS}px\\);`))
  })

  it("stops under either reduced-motion switch", () => {
    expect(rule('  html:not([data-motion="full"]) .wordmark-sweep__frames')).toContain("animation: none;")
    expect(rule('html[data-motion="reduced"] .wordmark-sweep__frames')).toContain("animation: none;")
    const reducedBlock = shellStylesheet.slice(shellStylesheet.indexOf("@media (prefers-reduced-motion: reduce)"))
    expect(reducedBlock.indexOf('html:not([data-motion="full"]) .wordmark-sweep__frames')).toBeLessThan(
      reducedBlock.indexOf("\n}\n"),
    )
  })
})
