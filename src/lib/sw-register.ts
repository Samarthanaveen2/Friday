// Registers the hand-written service worker (public/sw.js) in production builds only.
// The URL is built from BASE_URL so the app works under any deploy base.
export function registerSW() {
  if (!import.meta.env.PROD || !('serviceWorker' in navigator)) return
  window.addEventListener('load', () => {
    const url = `${import.meta.env.BASE_URL}sw.js`
    navigator.serviceWorker.register(url).catch((err) => {
      console.warn('[attic] service worker registration failed', err)
    })
  })
}
