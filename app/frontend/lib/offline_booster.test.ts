import { describe, expect, it, vi } from "vitest"
import {
  STORE_BOOSTER,
  followPlayer,
  freshlyRendered,
  storeBoosterPage,
  workerUrl,
  type OfflineBoosterHost,
} from "./offline_booster"
import { OPENED_STORAGE_KEY, QUEUE_STORAGE_KEY } from "./opening_queue"

function hostWith(overrides: Partial<OfflineBoosterHost> = {}) {
  const register = vi.fn(async () => ({}) as ServiceWorkerRegistration)
  const postMessage = vi.fn()
  const unregister = vi.fn(async () => true)
  const ready = Promise.resolve({ active: { postMessage } } as unknown as ServiceWorkerRegistration)
  const getRegistration = vi.fn(async () => ({ unregister }) as unknown as ServiceWorkerRegistration)
  const names = ["gameble-booster-pages", "gameble-booster-assets", "someone-else"]
  const deleted: string[] = []
  const caches = {
    keys: vi.fn(async () => names),
    delete: vi.fn(async (name: string) => deleted.push(name) > 0),
  }
  const stored = new Map<string, string>([
    [QUEUE_STORAGE_KEY, "[]"],
    [OPENED_STORAGE_KEY, '["held-1"]'],
  ])
  const storage = {
    getItem: (key: string) => stored.get(key) ?? null,
    setItem: (key: string, value: string) => void stored.set(key, value),
    removeItem: (key: string) => void stored.delete(key),
  }
  const host: OfflineBoosterHost = {
    workerScript: "/service-worker.js",
    address: new URL("https://gameble.test/en/collection"),
    assetBase: "/vite/",
    secure: true,
    serviceWorker: { register, ready, getRegistration },
    caches,
    storage,
    ...overrides,
  }
  return { host, register, postMessage, unregister, getRegistration, caches, deleted, stored }
}

describe("workerUrl", () => {
  it("tells the worker where the fingerprinted assets live", () => {
    expect(workerUrl("/service-worker.js", "/vite/")).toBe("/service-worker.js?assets=%2Fvite%2F")
  })
})

describe("freshlyRendered", () => {
  it("is a page the server just rendered, not a preview or a snapshot restored by Back", () => {
    expect(freshlyRendered(null, false)).toBe(true)
    expect(freshlyRendered("advance", false)).toBe(true)
    expect(freshlyRendered("replace", false)).toBe(true)
    expect(freshlyRendered("restore", false)).toBe(false)
    expect(freshlyRendered("advance", true)).toBe(false)
  })
})

describe("followPlayer", () => {
  it("registers the worker at the site root for a signed-in player", async () => {
    const { host, register, caches, postMessage } = hostWith()

    await followPlayer(host)

    expect(register).toHaveBeenCalledWith("/service-worker.js?assets=%2Fvite%2F", { scope: "/" })
    expect(caches.delete).not.toHaveBeenCalled()
    expect(postMessage).not.toHaveBeenCalled()
  })

  it("asks the worker to store the booster page once it is ready, on the booster page", async () => {
    const { host, postMessage } = hostWith({ address: new URL("https://gameble.test/fr/booster?reserve=special") })

    await followPlayer(host)

    expect(postMessage).toHaveBeenCalledWith({ type: STORE_BOOSTER, url: "https://gameble.test/fr/booster" })
  })

  it("registers nothing on an insecure origin or without service workers", async () => {
    const insecure = hostWith({ secure: false })
    await followPlayer(insecure.host)
    expect(insecure.register).not.toHaveBeenCalled()

    await expect(followPlayer(hostWith({ serviceWorker: undefined }).host)).resolves.toBeUndefined()
  })

  it("ignores a refused registration", async () => {
    const { host, postMessage } = hostWith({ address: new URL("https://gameble.test/en/booster") })
    const register = vi.fn(async () => {
      throw new DOMException("refused", "SecurityError")
    })
    await expect(
      followPlayer({ ...host, serviceWorker: { ...host.serviceWorker!, register } }),
    ).resolves.toBeUndefined()
    expect(postMessage).not.toHaveBeenCalled()
  })

  it("forgets the worker, its caches, the opening queue and the opened capsules on a page without a signed-in player", async () => {
    const { host, register, unregister, getRegistration, deleted, stored } = hostWith({ workerScript: null })

    await followPlayer(host)

    expect(register).not.toHaveBeenCalled()
    expect(getRegistration).toHaveBeenCalledWith("/")
    expect(unregister).toHaveBeenCalledOnce()
    expect(deleted).toEqual(["gameble-booster-pages", "gameble-booster-assets"])
    expect(stored.has(QUEUE_STORAGE_KEY)).toBe(false)
    expect(stored.has(OPENED_STORAGE_KEY)).toBe(false)
  })

  it("ignores failures while forgetting", async () => {
    const { host } = hostWith({ workerScript: null })
    const caches = {
      keys: vi.fn(async () => {
        throw new Error("blocked")
      }),
      delete: vi.fn(),
    }
    const storage = {
      getItem: () => null,
      setItem: () => {},
      removeItem: () => {
        throw new Error("blocked")
      },
    }
    const getRegistration = vi.fn(async () => {
      throw new Error("blocked")
    })

    const failing = { ...host, caches, storage, serviceWorker: { ...host.serviceWorker!, getRegistration } }
    await expect(followPlayer(failing)).resolves.toBeUndefined()
    await expect(followPlayer({ ...host, caches: undefined, serviceWorker: undefined })).resolves.toBeUndefined()
  })
})

describe("storeBoosterPage", () => {
  it("asks the worker to store the booster page again, only on the booster page of a signed-in player", async () => {
    const booster = hostWith({ address: new URL("https://gameble.test/en/booster") })
    await storeBoosterPage(booster.host)
    expect(booster.postMessage).toHaveBeenCalledWith({ type: STORE_BOOSTER, url: "https://gameble.test/en/booster" })

    const elsewhere = hostWith()
    await storeBoosterPage(elsewhere.host)
    expect(elsewhere.postMessage).not.toHaveBeenCalled()

    const visitor = hostWith({ workerScript: null, address: new URL("https://gameble.test/en/booster") })
    await storeBoosterPage(visitor.host)
    expect(visitor.postMessage).not.toHaveBeenCalled()
  })
})
