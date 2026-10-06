// Whether elements are in the viewport, through one IntersectionObserver
// shared by every caller (a page can hold hundreds of cards). Where the
// browser has none, every element counts as in view.

type Callback = (inView: boolean) => void

const callbacks = new Map<Element, Callback>()
let observer: IntersectionObserver | null = null

/** Calls `callback` with each change of `element`'s visibility; returns the function that stops. */
export function observeInView(element: Element, callback: Callback): () => void {
  if (typeof IntersectionObserver === "undefined") {
    callback(true)
    return () => {}
  }
  observer ??= new IntersectionObserver((entries) => {
    for (const entry of entries) callbacks.get(entry.target)?.(entry.isIntersecting)
  })
  callbacks.set(element, callback)
  observer.observe(element)
  return () => {
    if (callbacks.get(element) !== callback) return
    callbacks.delete(element)
    observer?.unobserve(element)
  }
}
