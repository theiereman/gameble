import { describe, expect, it } from "vitest"
import { isTurboStream, NEAR_END_MARGIN, NextPage, TURBO_STREAM } from "./next_page"

const URL = "/en/library/cards?q=seed&page=2"
const ANSWER = "<turbo-stream></turbo-stream>"

describe("NextPage", () => {
  it("fetches the next page once, when the links are first approached", () => {
    const next = new NextPage(URL)

    expect(next.phase).toBe("waiting")
    expect(next.approached()).toEqual({ kind: "fetch", url: URL })
    expect(next.phase).toBe("loading")
  })

  it("fetches nothing without a next page", () => {
    const next = new NextPage(null)

    expect(next.approached()).toEqual({ kind: "none" })
    expect(next.phase).toBe("waiting")
    expect(new NextPage("").approached()).toEqual({ kind: "none" })
  })

  it("fetches nothing more when approached again while loading", () => {
    const next = new NextPage(URL)
    next.approached()

    expect(next.approached()).toEqual({ kind: "none" })
    expect(next.phase).toBe("loading")
  })

  it("renders the answer at once when the focus is outside the links, then is spent", () => {
    const next = new NextPage(URL)
    next.approached()

    expect(next.answered(ANSWER, false)).toEqual({ kind: "render", answer: ANSWER })
    expect(next.phase).toBe("spent")
    expect(next.approached()).toEqual({ kind: "none" })
    expect(next.focusLeft()).toEqual({ kind: "none" })
  })

  it("holds the answer while the focus is in the links, and renders it once the focus leaves", () => {
    const next = new NextPage(URL)
    next.approached()

    expect(next.answered(ANSWER, true)).toEqual({ kind: "none" })
    expect(next.phase).toBe("holding")
    expect(next.approached()).toEqual({ kind: "none" })
    expect(next.focusLeft()).toEqual({ kind: "render", answer: ANSWER })
    expect(next.phase).toBe("spent")
    expect(next.focusLeft()).toEqual({ kind: "none" })
  })

  it("ignores the focus leaving while nothing is held", () => {
    const next = new NextPage(URL)

    expect(next.focusLeft()).toEqual({ kind: "none" })
    next.approached()
    expect(next.focusLeft()).toEqual({ kind: "none" })
    expect(next.phase).toBe("loading")
  })

  it("ignores an answer it did not ask for", () => {
    const next = new NextPage(URL)

    expect(next.answered(ANSWER, false)).toEqual({ kind: "none" })
    expect(next.phase).toBe("waiting")
  })

  it("stops on a failure: nothing rendered, nothing fetched again", () => {
    const next = new NextPage(URL)
    next.approached()

    next.failed()

    expect(next.phase).toBe("spent")
    expect(next.answered(ANSWER, false)).toEqual({ kind: "none" })
    expect(next.approached()).toEqual({ kind: "none" })
  })

  it("drops a held answer on a failure", () => {
    const next = new NextPage(URL)
    next.approached()
    next.answered(ANSWER, true)

    next.failed()

    expect(next.focusLeft()).toEqual({ kind: "none" })
  })
})

describe("isTurboStream", () => {
  it("accepts the Turbo Stream media type, with parameters or in any case", () => {
    expect(isTurboStream(TURBO_STREAM)).toBe(true)
    expect(isTurboStream("text/vnd.turbo-stream.html; charset=utf-8")).toBe(true)
    expect(isTurboStream("Text/VND.Turbo-Stream.HTML")).toBe(true)
  })

  it("refuses any other answer", () => {
    expect(isTurboStream("text/html; charset=utf-8")).toBe(false)
    expect(isTurboStream("application/json")).toBe(false)
    expect(isTurboStream("")).toBe(false)
    expect(isTurboStream(null)).toBe(false)
    expect(isTurboStream(undefined)).toBe(false)
  })
})

describe("NEAR_END_MARGIN", () => {
  it("reaches half a viewport below its bottom edge", () => {
    expect(NEAR_END_MARGIN).toBe("0px 0px 50% 0px")
  })
})
