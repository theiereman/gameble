import { onGameble } from "./events"
import { OPENED_STORAGE_KEY, QUEUE_STORAGE_KEY, type QueueStorage } from "./opening_queue"

export const WORKER_META = "service-worker"

export const WORKER_CACHE_PREFIX = "gameble-booster-"

export const STORE_BOOSTER = "store-booster"

const BOOSTER_PATH = /^\/(en|fr)\/booster$/

export type OfflineBoosterHost = Readonly<{
  workerScript: string | null
  address: URL
  assetBase: string
  secure: boolean
  serviceWorker: Pick<ServiceWorkerContainer, "register" | "ready" | "getRegistration"> | undefined
  caches: Pick<CacheStorage, "keys" | "delete"> | undefined
  storage: QueueStorage | null
}>

export function workerUrl(script: string, assetBase: string): string {
  const url = new URL(script, "https://worker.invalid")
  url.searchParams.set("assets", assetBase)
  return url.pathname + url.search
}

export function freshlyRendered(lastVisitAction: string | null, preview: boolean): boolean {
  return !preview && lastVisitAction !== "restore"
}

export async function storeBoosterPage(host: OfflineBoosterHost): Promise<void> {
  const { workerScript, secure, address, serviceWorker } = host
  if (!workerScript || !secure || !serviceWorker || !BOOSTER_PATH.test(address.pathname)) return
  try {
    const { active } = await serviceWorker.ready
    active?.postMessage({ type: STORE_BOOSTER, url: address.origin + address.pathname })
  } catch {
    return
  }
}

export async function keepBoosterOffline(host: OfflineBoosterHost): Promise<void> {
  const { workerScript, assetBase, secure, serviceWorker } = host
  if (!workerScript || !secure || !serviceWorker) return
  try {
    await serviceWorker.register(workerUrl(workerScript, assetBase), { scope: "/" })
  } catch {
    return
  }
  await storeBoosterPage(host)
}

function forgetQueue(storage: QueueStorage | null): void {
  try {
    storage?.removeItem(QUEUE_STORAGE_KEY)
    storage?.removeItem(OPENED_STORAGE_KEY)
  } catch {
    return
  }
}

async function forgetCaches(caches: OfflineBoosterHost["caches"]): Promise<void> {
  if (!caches) return
  try {
    const names = (await caches.keys()).filter((name) => name.startsWith(WORKER_CACHE_PREFIX))
    await Promise.all(names.map((name) => caches.delete(name)))
  } catch {
    return
  }
}

async function unregisterWorker(serviceWorker: OfflineBoosterHost["serviceWorker"]): Promise<void> {
  try {
    await (await serviceWorker?.getRegistration("/"))?.unregister()
  } catch {
    return
  }
}

export async function forgetBoosterOffline({ caches, storage, serviceWorker }: OfflineBoosterHost): Promise<void> {
  forgetQueue(storage)
  await Promise.all([forgetCaches(caches), unregisterWorker(serviceWorker)])
}

export function followPlayer(host: OfflineBoosterHost): Promise<void> {
  return host.workerScript ? keepBoosterOffline(host) : forgetBoosterOffline(host)
}

function browserStorage(): QueueStorage | null {
  try {
    return globalThis.localStorage ?? null
  } catch {
    return null
  }
}

function pageHost(): OfflineBoosterHost {
  return {
    workerScript: document.querySelector<HTMLMetaElement>(`meta[name="${WORKER_META}"]`)?.content || null,
    address: new URL(location.href),
    assetBase: import.meta.env.BASE_URL,
    secure: window.isSecureContext,
    serviceWorker: navigator.serviceWorker,
    caches: globalThis.caches,
    storage: browserStorage(),
  }
}

export function keepBoosterOfflineForPlayer(): void {
  let lastVisitAction: string | null = null
  document.addEventListener("turbo:visit", (event) => {
    lastVisitAction = (event as CustomEvent<{ action: string }>).detail.action
  })
  document.addEventListener("turbo:load", () => {
    const preview = document.documentElement.hasAttribute("data-turbo-preview")
    const fresh = freshlyRendered(lastVisitAction, preview)
    lastVisitAction = null
    if (fresh) void followPlayer(pageHost())
  })
  onGameble("gameble:booster-changed", () => void storeBoosterPage(pageHost()))
}
