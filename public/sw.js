/* Samartha Tower service worker — hand-written, no plugins.
 * - Navigations: network-first, falling back to the cached app shell (index).
 * - Hashed build assets (assets/*): cache-first (they are immutable).
 * - Other same-origin GETs (icons, manifest): stale-while-revalidate.
 * Bump VERSION to invalidate every cache on the next activation.
 */
const VERSION = 'v2'
const PREFIX = 'samartha-tower-'
const SHELL_CACHE = `${PREFIX}shell-${VERSION}`
const ASSET_CACHE = `${PREFIX}assets-${VERSION}`

// Everything is resolved relative to the worker's scope, so any deploy base works.
const SCOPE = new URL(self.registration.scope)
const INDEX_URL = new URL('./', SCOPE).href
const ASSETS_PATH = new URL('./assets/', SCOPE).pathname
const PRECACHE = ['./', './manifest.webmanifest', './favicon.svg', './icon.svg', './icon-192.png', './icon-512.png'].map(
  (p) => new URL(p, SCOPE).href,
)

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const shell = await caches.open(SHELL_CACHE)
      await Promise.all(
        PRECACHE.map((url) =>
          fetch(url, { cache: 'no-cache' })
            .then((res) => (res.ok ? shell.put(url, res) : undefined))
            .catch(() => undefined),
        ),
      )
      // Warm the asset cache with the entry bundles referenced by index.html.
      const index = await shell.match(INDEX_URL)
      if (index) {
        const html = await index.clone().text()
        const urls = new Set()
        for (const m of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
          const url = new URL(m[1], INDEX_URL)
          if (url.origin === SCOPE.origin && url.pathname.startsWith(ASSETS_PATH)) urls.add(url.href)
        }
        const assets = await caches.open(ASSET_CACHE)
        await Promise.all([...urls].map((u) => assets.add(u).catch(() => undefined)))
      }
      await self.skipWaiting()
    })(),
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keep = new Set([SHELL_CACHE, ASSET_CACHE])
      const keys = await caches.keys()
      await Promise.all(keys.filter((k) => k.startsWith(PREFIX) && !keep.has(k)).map((k) => caches.delete(k)))
      await self.clients.claim()
    })(),
  )
})

async function networkFirstNavigation(request) {
  const shell = await caches.open(SHELL_CACHE)
  try {
    const res = await fetch(request)
    // The app uses a hash router, so every navigation is the same index document.
    if (res.ok) await shell.put(INDEX_URL, res.clone())
    return res
  } catch {
    const cached = (await shell.match(INDEX_URL)) || (await shell.match(request))
    if (cached) return cached
    return new Response('<h1>Offline</h1><p>The Tower has not been cached yet.</p>', {
      status: 503,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    })
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(ASSET_CACHE)
  const cached = await cache.match(request)
  if (cached) return cached
  const res = await fetch(request)
  if (res.ok) await cache.put(request, res.clone())
  return res
}

async function staleWhileRevalidate(event) {
  const cache = await caches.open(SHELL_CACHE)
  const cached = await cache.match(event.request)
  const network = fetch(event.request)
    .then(async (res) => {
      if (res.ok) await cache.put(event.request, res.clone())
      return res
    })
    .catch(() => undefined)
  if (cached) {
    event.waitUntil(network)
    return cached
  }
  return (await network) || Response.error()
}

self.addEventListener('fetch', (event) => {
  const { request } = event
  if (request.method !== 'GET') return
  const url = new URL(request.url)
  if (url.origin !== SCOPE.origin) return // never touch cross-origin requests

  if (request.mode === 'navigate') {
    event.respondWith(networkFirstNavigation(request))
  } else if (url.pathname.startsWith(ASSETS_PATH)) {
    event.respondWith(cacheFirst(request))
  } else if (url.pathname.startsWith(SCOPE.pathname)) {
    event.respondWith(staleWhileRevalidate(event))
  }
})
