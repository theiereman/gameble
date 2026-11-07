import { describe, expect, it } from "vitest"
import source from "../../views/pwa/service-worker.js?raw"

const ORIGIN = "https://gameble.test"
const HTML = "text/html; charset=utf-8"

type FakeRequest = Readonly<{ method: string; url: string; mode: string; headers: Headers }>

const keyOf = (request: string | FakeRequest): string => (typeof request === "string" ? request : request.url)

class FakeCache {
  readonly entries = new Map<string, Response>()

  async match(request: string | FakeRequest): Promise<Response | undefined> {
    return this.entries.get(keyOf(request))?.clone()
  }

  async put(request: string | FakeRequest, response: Response): Promise<void> {
    this.entries.set(keyOf(request), response)
  }
}

class FakeCaches {
  readonly stores = new Map<string, FakeCache>()

  async open(name: string): Promise<FakeCache> {
    if (!this.stores.has(name)) this.stores.set(name, new FakeCache())
    return this.stores.get(name)!
  }

  keysOf(name: string): string[] {
    return [...(this.stores.get(name)?.entries.keys() ?? [])]
  }
}

type Served = Readonly<{ body: string; type?: string; redirected?: boolean }>

function served({ body, type = HTML, redirected = false }: Served): Response {
  const response = new Response(body, { headers: { "Content-Type": type } })
  Object.defineProperty(response, "type", { value: "basic" })
  Object.defineProperty(response, "redirected", { value: redirected })
  return response
}

function workerWith({ assets = "/vite/" }: { assets?: string | null } = {}) {
  const listeners = new Map<string, (event: unknown) => void>()
  const caches = new FakeCaches()
  const network = new Map<string, Served>()
  const requested: string[] = []
  const accepted: (string | null)[] = []
  const windows = new Map<string, string>()
  let online = true
  const fetch = async (request: string | FakeRequest, init?: RequestInit) => {
    const url = keyOf(request)
    requested.push(url)
    accepted.push(new Headers(typeof request === "string" ? init?.headers : request.headers).get("Accept"))
    if (!online) throw new TypeError("Failed to fetch")
    const page = network.get(url)
    return page ? served(page) : new Response("missing", { status: 404 })
  }
  const script = new URL("/service-worker.js", ORIGIN)
  if (assets !== null) script.searchParams.set("assets", assets)
  const self = {
    location: script,
    addEventListener: (type: string, listener: (event: unknown) => void) => listeners.set(type, listener),
    clients: { get: async (id: string) => (windows.has(id) ? { url: windows.get(id) } : undefined) },
  }
  new Function("self", "caches", "fetch", source)(self, caches, fetch)

  async function request(
    path: string,
    { method = "GET", mode = "cors", accept = "*/*", clientId = "" } = {},
  ): Promise<Response | null> {
    let responded: Promise<Response> | null = null
    const waits: Promise<unknown>[] = []
    listeners.get("fetch")!({
      request: { method, url: `${ORIGIN}${path}`, mode, headers: new Headers({ Accept: accept }) },
      clientId,
      respondWith: (response: Promise<Response>) => (responded = response),
      waitUntil: (promise: Promise<unknown>) => waits.push(promise),
    })
    if (!responded) return null
    const response = await responded
    await Promise.all(waits)
    return response
  }

  async function message(data: unknown): Promise<void> {
    const waits: Promise<unknown>[] = []
    listeners.get("message")!({ data, waitUntil: (promise: Promise<unknown>) => waits.push(promise) })
    await Promise.all(waits)
  }

  return {
    caches,
    network,
    requested,
    accepted,
    message,
    windows,
    request,
    goOffline: () => (online = false),
    visit: (path: string) => request(path, { mode: "navigate", accept: "text/html" }),
  }
}

const BOOSTER_HTML = [
  '<link rel="stylesheet" href="/vite/assets/application-Ab12Cd34.css">',
  '<script type="module" src="/vite/assets/application-Zx98Yw76.js"></script>',
  '<link rel="icon" href="/vite/assets/favicon-Qq11Ww22.svg">',
  '<img src="/vite/entrypoints/dev.ts"><a href="/en/collection">collection</a>',
  '<template data-held="standard">capsule held-1</template>',
].join("\n")

const CSS = ".canister { background: url(/vite/assets/canister-Pp33Oo44.png) } .x { background: url('data:x') }"

function boosterOnline() {
  const worker = workerWith()
  worker.network.set(`${ORIGIN}/en/booster`, { body: BOOSTER_HTML })
  worker.network.set(`${ORIGIN}/vite/assets/application-Ab12Cd34.css`, { body: CSS, type: "text/css" })
  worker.network.set(`${ORIGIN}/vite/assets/application-Zx98Yw76.js`, { body: "js", type: "text/javascript" })
  worker.network.set(`${ORIGIN}/vite/assets/favicon-Qq11Ww22.svg`, { body: "svg", type: "image/svg+xml" })
  worker.network.set(`${ORIGIN}/vite/assets/canister-Pp33Oo44.png`, { body: "png", type: "image/png" })
  return worker
}

describe("the service worker", () => {
  it("serves an online visit from the network and stores it with the fingerprinted assets it references", async () => {
    const worker = boosterOnline()

    const response = await worker.visit("/en/booster")

    expect(await response?.text()).toBe(BOOSTER_HTML)
    expect(worker.caches.keysOf("gameble-booster-pages")).toEqual([`${ORIGIN}/en/booster`])
    expect(worker.caches.keysOf("gameble-booster-assets").sort()).toEqual([
      `${ORIGIN}/vite/assets/application-Ab12Cd34.css`,
      `${ORIGIN}/vite/assets/application-Zx98Yw76.js`,
      `${ORIGIN}/vite/assets/canister-Pp33Oo44.png`,
      `${ORIGIN}/vite/assets/favicon-Qq11Ww22.svg`,
    ])
  })

  it("replaces the stored copy with a fresh one", async () => {
    const worker = boosterOnline()
    await worker.visit("/en/booster")
    worker.network.set(`${ORIGIN}/en/booster`, { body: "fresh" })

    await worker.request("/en/booster", { accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" })
    worker.goOffline()

    expect(await (await worker.visit("/en/booster"))?.text()).toBe("fresh")
  })

  it("serves the stored page with its held capsule when the network fails, for any booster address", async () => {
    const worker = boosterOnline()
    await worker.visit("/en/booster")
    worker.goOffline()

    expect(await (await worker.visit("/en/booster"))?.text()).toContain("capsule held-1")
    expect(await (await worker.visit("/en/booster?reserve=special"))?.text()).toContain("capsule held-1")
    expect(await (await worker.request("/vite/assets/application-Zx98Yw76.js"))?.text()).toBe("js")
  })

  it("keeps one copy per locale", async () => {
    const worker = boosterOnline()
    worker.network.set(`${ORIGIN}/fr/booster`, { body: "capsule en français" })
    await worker.visit("/en/booster")
    await worker.visit("/fr/booster")
    worker.goOffline()

    expect(await (await worker.visit("/fr/booster"))?.text()).toBe("capsule en français")
    expect(await (await worker.visit("/en/booster"))?.text()).toContain("capsule held-1")
  })

  it("leaves the browser's own failure when nothing is stored", async () => {
    const worker = workerWith()
    worker.goOffline()

    await expect(worker.visit("/en/booster")).rejects.toThrow("Failed to fetch")
  })

  it("stores no booster page opened with a query, a redirect or another type", async () => {
    const worker = workerWith()
    worker.network.set(`${ORIGIN}/en/booster?pack=abc`, { body: "opened pack" })
    await worker.visit("/en/booster?pack=abc")
    for (const page of [
      { body: "redirected", redirected: true },
      { body: "{}", type: "application/json" },
    ]) {
      worker.network.set(`${ORIGIN}/en/booster`, page)
      await worker.visit("/en/booster")
    }

    expect(worker.caches.keysOf("gameble-booster-pages")).toEqual([])
  })

  it("stores the booster page a page asks for, fetched as HTML, so the first visit and later openings are kept", async () => {
    const worker = boosterOnline()

    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/booster` })

    expect(worker.accepted[0]).toBe("text/html")
    expect(worker.caches.keysOf("gameble-booster-pages")).toEqual([`${ORIGIN}/en/booster`])
    expect(worker.caches.keysOf("gameble-booster-assets")).toHaveLength(4)

    worker.network.set(`${ORIGIN}/en/booster`, { body: "after an opening" })
    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/booster` })
    worker.goOffline()
    expect(await (await worker.visit("/en/booster"))?.text()).toBe("after an opening")
  })

  it("ignores a request to store another page, another origin, a redirect, or a failed fetch", async () => {
    const worker = workerWith()
    worker.network.set(`${ORIGIN}/en/collection`, { body: "collection" })
    worker.network.set(`${ORIGIN}/en/booster`, { body: "sign in first", redirected: true })

    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/collection` })
    await worker.message({ type: "store-booster", url: "https://elsewhere.test/en/booster" })
    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/booster?pack=abc` })
    await worker.message({ type: "other", url: `${ORIGIN}/en/booster` })
    await worker.message(null)
    expect(worker.requested).toEqual([])

    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/booster` })
    worker.goOffline()
    await worker.message({ type: "store-booster", url: `${ORIGIN}/en/booster` })
    expect(worker.caches.keysOf("gameble-booster-pages")).toEqual([])
  })

  it("leaves other pages, the bank JSON and every POST to the network", async () => {
    const worker = boosterOnline()

    expect(await worker.visit("/en/collection")).toBeNull()
    expect(await worker.request("/en/booster", { accept: "application/json" })).toBeNull()
    expect(await worker.request("/en/booster", { method: "POST", accept: "text/html" })).toBeNull()
    expect(await worker.request("/en/packs/abc/reveal", { method: "POST" })).toBeNull()
    expect(await worker.request("/vite/entrypoints/application.ts")).toBeNull()
    expect(await worker.request("/assets/other-Ab12Cd34.js")).toBeNull()
    expect(worker.requested).toEqual([])
  })

  it("serves a stored asset without the network", async () => {
    const worker = boosterOnline()
    await worker.visit("/en/booster")
    worker.requested.length = 0

    expect(await (await worker.request("/vite/assets/application-Zx98Yw76.js"))?.text()).toBe("js")
    expect(worker.requested).toEqual([])
  })

  it("stores an asset fetched by the booster page, not one fetched by another page", async () => {
    const worker = workerWith()
    worker.windows.set("booster", `${ORIGIN}/fr/booster`)
    worker.windows.set("collection", `${ORIGIN}/fr/collection`)
    worker.network.set(`${ORIGIN}/vite/assets/chunk-Aa11Bb22.js`, { body: "chunk", type: "text/javascript" })
    worker.network.set(`${ORIGIN}/vite/assets/grid-Cc33Dd44.js`, { body: "grid", type: "text/javascript" })

    expect(await (await worker.request("/vite/assets/chunk-Aa11Bb22.js", { clientId: "booster" }))?.text()).toBe(
      "chunk",
    )
    await worker.request("/vite/assets/grid-Cc33Dd44.js", { clientId: "collection" })

    expect(worker.caches.keysOf("gameble-booster-assets")).toEqual([`${ORIGIN}/vite/assets/chunk-Aa11Bb22.js`])
  })

  it("caches no asset without its asset path", async () => {
    const worker = workerWith({ assets: null })

    expect(await worker.request("/vite/assets/application-Zx98Yw76.js")).toBeNull()
  })
})
