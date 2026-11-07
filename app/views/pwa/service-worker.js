const PAGE_CACHE = "gameble-booster-pages"
const ASSET_CACHE = "gameble-booster-assets"
const BOOSTER_PATH = /^\/(en|fr)\/booster$/
const FINGERPRINTED = /-[\w-]{8}\.[a-z0-9]+$/i
const ASSET_REFERENCE = /(?:src|href)="([^"]+)"|url\(\s*["']?([^"')\s]+)["']?\s*\)/g

const assetBase = new URL(self.location.href).searchParams.get("assets")

function sameOrigin(url) {
  return url.origin === self.location.origin
}

function boosterPageRequest(request) {
  if (request.method !== "GET") return false
  const url = new URL(request.url)
  if (!sameOrigin(url) || !BOOSTER_PATH.test(url.pathname)) return false
  return request.mode === "navigate" || (request.headers.get("Accept") ?? "").includes("text/html")
}

function fingerprintedAsset(url) {
  if (!assetBase || !assetBase.startsWith("/") || assetBase === "/") return false
  return sameOrigin(url) && url.pathname.startsWith(`${assetBase}assets/`) && FINGERPRINTED.test(url.pathname)
}

function fingerprintedAssetRequest(request) {
  return request.method === "GET" && fingerprintedAsset(new URL(request.url))
}

function pageKey(request) {
  const url = new URL(request.url)
  return url.origin + url.pathname
}

function plainBoosterPage(request) {
  return new URL(request.url).search === ""
}

function storablePage(response) {
  return (
    response.ok &&
    response.type === "basic" &&
    !response.redirected &&
    (response.headers.get("Content-Type") ?? "").startsWith("text/html")
  )
}

function storableAsset(response) {
  return response.ok && response.type === "basic"
}

function referencedAssets(text, base) {
  const assets = new Set()
  for (const [, attribute, cssUrl] of text.matchAll(ASSET_REFERENCE)) {
    try {
      const url = new URL(attribute ?? cssUrl, base)
      if (fingerprintedAsset(url)) assets.add(url.href)
    } catch {
      continue
    }
  }
  return [...assets]
}

async function storeAsset(cache, href) {
  const stored = await cache.match(href)
  if (stored) return stored
  const response = await fetch(href, { credentials: "same-origin" })
  if (!storableAsset(response)) return null
  await cache.put(href, response.clone())
  return response
}

async function storeAssetsOf(text, base) {
  const cache = await caches.open(ASSET_CACHE)
  await Promise.all(
    referencedAssets(text, base).map(async (href) => {
      try {
        const response = await storeAsset(cache, href)
        if (response && href.endsWith(".css")) await storeAssetsOf(await response.clone().text(), href)
      } catch {
        return
      }
    }),
  )
}

async function storePage(key, response) {
  const cache = await caches.open(PAGE_CACHE)
  await cache.put(key, response.clone())
  await storeAssetsOf(await response.text(), key)
}

async function boosterPageResponse(request, waitUntil) {
  const key = pageKey(request)
  let response
  try {
    response = await fetch(request)
  } catch (failure) {
    const stored = await (await caches.open(PAGE_CACHE)).match(key)
    if (stored) return stored
    throw failure
  }
  if (plainBoosterPage(request) && storablePage(response)) waitUntil(storePage(key, response.clone()))
  return response
}

function boosterPageToStore(message) {
  if (message?.type !== "store-booster" || typeof message.url !== "string") return null
  let url
  try {
    url = new URL(message.url, self.location.origin)
  } catch {
    return null
  }
  return sameOrigin(url) && BOOSTER_PATH.test(url.pathname) && url.search === "" ? url.origin + url.pathname : null
}

async function refreshPage(key) {
  const response = await fetch(key, { headers: { Accept: "text/html" }, credentials: "same-origin" })
  if (storablePage(response)) await storePage(key, response)
}

async function fromBoosterPage(clientId) {
  if (!clientId) return false
  const client = await self.clients.get(clientId)
  return Boolean(client && BOOSTER_PATH.test(new URL(client.url).pathname))
}

async function assetResponse(request, clientId, waitUntil) {
  const cache = await caches.open(ASSET_CACHE)
  const stored = await cache.match(request)
  if (stored) return stored
  const response = await fetch(request)
  if (storableAsset(response) && (await fromBoosterPage(clientId))) waitUntil(cache.put(request, response.clone()))
  return response
}

self.addEventListener("install", () => self.skipWaiting())

self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))

self.addEventListener("message", (event) => {
  const key = boosterPageToStore(event.data)
  if (key) event.waitUntil(refreshPage(key).catch(() => undefined))
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  const waitUntil = (promise) => event.waitUntil(promise.catch(() => undefined))
  if (boosterPageRequest(request)) event.respondWith(boosterPageResponse(request, waitUntil))
  else if (fingerprintedAssetRequest(request)) event.respondWith(assetResponse(request, event.clientId, waitUntil))
})
