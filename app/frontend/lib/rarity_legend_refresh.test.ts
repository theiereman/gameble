import { describe, expect, it, vi } from "vitest"
import type { ChipRefresh } from "./countdown"
import { RarityLegendRefresh } from "./rarity_legend_refresh"

function refreshAnswering(answer: ChipRefresh) {
  const fetchLegend = vi.fn(() => Promise.resolve(answer))
  const render = vi.fn()
  return { refresh: new RarityLegendRefresh({ fetchLegend, render }), fetchLegend, render }
}

const settled = () => new Promise((resolve) => setTimeout(resolve))

describe("RarityLegendRefresh", () => {
  it("renders the legend once when a reveal ends", async () => {
    const { refresh, fetchLegend, render } = refreshAnswering({ kind: "render", html: "<turbo-stream>" })

    refresh.openingChanged(true)
    refresh.openingChanged(false)
    await settled()

    expect(fetchLegend).toHaveBeenCalledTimes(1)
    expect(render).toHaveBeenCalledExactlyOnceWith("<turbo-stream>")
  })

  it("asks for nothing when the page connects with no opening under way", () => {
    const { refresh, fetchLegend } = refreshAnswering({ kind: "render", html: "" })

    refresh.openingChanged(false)
    refresh.openingChanged(false)

    expect(fetchLegend).not.toHaveBeenCalled()
  })

  it.each<ChipRefresh>([{ kind: "retry" }, { kind: "stop" }])(
    "keeps the figures when the answer is %o",
    async (answer) => {
      const { refresh, render } = refreshAnswering(answer)

      refresh.openingChanged(true)
      refresh.openingChanged(false)
      await settled()

      expect(render).not.toHaveBeenCalled()
    },
  )

  it("renders nothing once stopped while the request was under way", async () => {
    const { refresh, render } = refreshAnswering({ kind: "render", html: "<turbo-stream>" })

    refresh.openingChanged(true)
    refresh.openingChanged(false)
    refresh.stop()
    await settled()

    expect(render).not.toHaveBeenCalled()
  })
})
