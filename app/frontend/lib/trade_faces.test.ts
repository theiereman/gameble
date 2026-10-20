import { describe, expect, it } from "vitest"
import { PICKER_PAGE, batches, faceLoader, facesFrom, facesUrl, fetchFaces, missingFaces, nextPage, shownFor, withFaces, type Faces } from "./trade_faces"

describe("shownFor", () => {
  it("holds whole pages up to and including the index", () => {
    expect(shownFor(0)).toBe(PICKER_PAGE)
    expect(shownFor(PICKER_PAGE - 1)).toBe(PICKER_PAGE)
    expect(shownFor(PICKER_PAGE)).toBe(2 * PICKER_PAGE)
    expect(shownFor(2999)).toBe(Math.ceil(3000 / PICKER_PAGE) * PICKER_PAGE)
  })

  it("is one page for an index before the list", () => {
    expect(shownFor(-1)).toBe(PICKER_PAGE)
  })
})

describe("nextPage", () => {
  it("adds one page", () => {
    expect(nextPage(PICKER_PAGE)).toBe(2 * PICKER_PAGE)
  })
})

describe("missingFaces", () => {
  it("keeps the keys neither known nor asked for, once each, in order", () => {
    const known = new Map([["a--s1", "<span></span>"]])
    expect(missingFaces(["a--s1", "b--s1", "c--s1", "b--s1", "d--s1"], known, new Set(["c--s1"]))).toEqual(["b--s1", "d--s1"])
  })

  it("is empty when every face is known or pending", () => {
    expect(missingFaces(["a--s1"], new Map([["a--s1", ""]]), new Set())).toEqual([])
    expect(missingFaces([], new Map(), new Set())).toEqual([])
  })
})

describe("batches", () => {
  it("cuts the keys in runs of at most the size", () => {
    expect(batches(["a", "b", "c", "d", "e"], 2)).toEqual([["a", "b"], ["c", "d"], ["e"]])
    expect(batches(["a", "b"], 60)).toEqual([["a", "b"]])
  })

  it("is empty for no keys, and takes one at a time for a size under one", () => {
    expect(batches([], 60)).toEqual([])
    expect(batches(["a", "b"], 0)).toEqual([["a"], ["b"]])
  })
})

describe("facesUrl", () => {
  it("asks for each key as keys[], encoded", () => {
    expect(facesUrl("/fr/trades/faces", ["portal--s1", "a&b c--s2"])).toBe(
      "/fr/trades/faces?keys%5B%5D=portal--s1&keys%5B%5D=a%26b+c--s2",
    )
  })

  it("adds to a query the base already has", () => {
    expect(facesUrl("/fr/trades/faces?v=1", ["x--s1"])).toBe("/fr/trades/faces?v=1&keys%5B%5D=x--s1")
  })
})

describe("facesFrom", () => {
  it("reads the faces by key, keeping only text", () => {
    expect(facesFrom({ faces: { "a--s1": "<span>A</span>", "b--s1": 3 } })).toEqual({ "a--s1": "<span>A</span>" })
  })

  it("is empty for an answer of another shape", () => {
    expect(facesFrom(null)).toEqual({})
    expect(facesFrom({ error: { code: "forbidden" } })).toEqual({})
    expect(facesFrom({ faces: ["a"] })).toEqual({})
    expect(facesFrom("faces")).toEqual({})
  })
})

describe("withFaces", () => {
  it("adds the arrived faces to the known ones, leaving the known map untouched", () => {
    const known = new Map([["a--s1", "A"]])
    const next = withFaces(known, { "b--s1": "B" })
    expect([...next]).toEqual([
      ["a--s1", "A"],
      ["b--s1", "B"],
    ])
    expect(known.size).toBe(1)
  })

  it("keeps the same map when nothing arrived", () => {
    const known = new Map([["a--s1", "A"]])
    expect(withFaces(known, {})).toBe(known)
  })
})

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

function answering(answer: Response | Error) {
  const calls: { url: string; init: RequestInit }[] = []
  const send = (async (url: string, init: RequestInit) => {
    calls.push({ url, init })
    if (answer instanceof Error) throw answer
    return answer
  }) as typeof fetch
  return { calls, send }
}

const never = ((_url: string, init: RequestInit) =>
  new Promise<Response>((_resolve, reject) => init.signal?.addEventListener("abort", () => reject(init.signal?.reason)))) as typeof fetch

describe("fetchFaces", () => {
  it("asks in JSON with the session's cookies and reads the faces", async () => {
    const { calls, send } = answering(json(200, { faces: { "a--s1": "<div>A</div>" } }))

    expect(await fetchFaces({ url: "/fr/trades/faces?keys%5B%5D=a--s1", fetch: send })).toEqual({ "a--s1": "<div>A</div>" })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/fr/trades/faces?keys%5B%5D=a--s1")
    expect(calls[0].init).toMatchObject({ headers: { Accept: "application/json" }, credentials: "same-origin" })
    expect(calls[0].init.signal).toBeInstanceOf(AbortSignal)
  })

  it("fails without an answer, on a refusal, a server error or an answer that is not JSON", async () => {
    const page = new Response("<html></html>", { status: 200, headers: { "Content-Type": "text/html" } })
    for (const answer of [new TypeError("Failed to fetch"), json(401, { error: { code: "sign_in_required" } }), json(500, { faces: { "a--s1": "A" } }), page]) {
      expect(await fetchFaces({ url: "/fr/trades/faces", fetch: answering(answer).send })).toBeNull()
    }
  })

  it("gives up on an answer that never comes", async () => {
    expect(await fetchFaces({ url: "/fr/trades/faces", fetch: never, timeout: 5 })).toBeNull()
  })
})

function deferred<Value>() {
  let resolve!: (value: Value) => void
  const promise = new Promise<Value>((done) => (resolve = done))
  return { promise, resolve }
}

const settled = () => new Promise((done) => setTimeout(done, 0))

function loading({ known = new Map(), concurrency = 2, attempts = 3 }: { known?: Faces; concurrency?: number; attempts?: number } = {}) {
  const calls: { keys: readonly string[]; answer: ReturnType<typeof deferred<Record<string, string> | null>> }[] = []
  const retries: (() => void)[] = []
  const seen: Faces[] = []
  const loader = faceLoader({
    known,
    batch: 2,
    concurrency,
    attempts,
    load: (keys) => {
      const answer = deferred<Record<string, string> | null>()
      calls.push({ keys, answer })
      return answer.promise
    },
    onFaces: (faces) => seen.push(faces),
    later: (run) => retries.push(run),
  })
  return { loader, calls, retries, seen }
}

describe("faceLoader", () => {
  it("loads at most the concurrency at once, the latest batch first", async () => {
    const { loader, calls } = loading()

    loader.request(["a", "b", "c", "d", "e", "f"])
    expect(calls.map((call) => call.keys)).toEqual([["e", "f"], ["c", "d"]])

    calls[0].answer.resolve({ e: "E", f: "F" })
    await settled()
    expect(calls.map((call) => call.keys)).toEqual([["e", "f"], ["c", "d"], ["a", "b"]])
  })

  it("asks only for faces neither known nor already asked for", () => {
    const { loader, calls } = loading({ known: new Map([["a", "A"]]) })

    loader.request(["a", "b"])
    loader.request(["a", "b"])
    expect(calls.map((call) => call.keys)).toEqual([["b"]])
  })

  it("hands every arrival to the board", async () => {
    const { loader, calls, seen } = loading()

    loader.request(["a"])
    calls[0].answer.resolve({ a: "A" })
    await settled()
    expect([...seen.at(-1)!]).toEqual([["a", "A"]])
  })

  it("tries a failed batch again later, then lets a later request ask for it", async () => {
    const { loader, calls, retries } = loading({ attempts: 2 })

    loader.request(["a"])
    calls[0].answer.resolve(null)
    await settled()
    expect(retries).toHaveLength(1)
    loader.request(["a"])
    expect(calls).toHaveLength(1)

    retries[0]()
    expect(calls.map((call) => call.keys)).toEqual([["a"], ["a"]])
    calls[1].answer.resolve(null)
    await settled()
    expect(retries).toHaveLength(1)

    loader.request(["a"])
    expect(calls).toHaveLength(3)
  })
})
