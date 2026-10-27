type Callback = (inView: boolean) => void

const callbacks = new Map<Element, Callback>()
let observer: IntersectionObserver | null = null

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
