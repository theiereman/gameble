import { Controller } from "@hotwired/stimulus"
import { onGameble, type ToastDetail } from "../lib/events"
import { firstShowing, toastDuration } from "../lib/toast"

type Timer = { remaining: number; startedAt?: number; handle?: number; hovered: boolean; focused: boolean; cleanup: () => void }

// The shell's toast region (EXPERIENCE.md, Toast): a polite live region
// holding the server's flash messages and any toast asked for with a
// `gameble:toast` event, built from the region's server-rendered template.
// Each toast stays toastDuration(its text), pauses while hovered or focused,
// and closes with its "✕" or Esc. A morph refresh of the page (the hub)
// keeps the toasts on screen and brings its own, which are timed as well.
// A toast with a once key (`data-toast-once`) shows once per browser.
// Every listener and timer goes on disconnect.
export default class extends Controller<HTMLElement> {
  static targets = ["template", "toast"]

  declare readonly templateTarget: HTMLTemplateElement

  private timers = new Map<HTMLElement, Timer>()
  private stopListening?: () => void
  private frame?: number
  private connected = false

  // A morph would remove a toast still on screen, or rewrite it into a toast
  // the new page brings: the toast is kept, and the new one is added once
  // the morph is over.
  private readonly keepToast = (event: Event): void => {
    if (!this.timers.has(event.target as HTMLElement)) return
    event.preventDefault()
    const incoming = (event as CustomEvent<{ newElement?: Node }>).detail?.newElement
    if (incoming instanceof HTMLElement && incoming.matches(".toast")) {
      const toast = incoming.cloneNode(true) as HTMLElement
      queueMicrotask(() => {
        if (this.connected) this.add(toast)
      })
    }
  }

  connect(): void {
    this.stopListening = onGameble("gameble:toast", (detail) => this.show(detail))
    this.element.addEventListener("turbo:before-morph-element", this.keepToast)
    this.connected = true
    // The server's toasts are taken out and put back on the next frame,
    // once the region is in the page, so the live region announces them.
    const rendered = this.toasts().filter((toast) => !this.timers.has(toast))
    if (rendered.length === 0) return
    rendered.forEach((toast) => toast.remove())
    this.frame = window.requestAnimationFrame(() => {
      this.frame = undefined
      rendered.forEach((toast) => this.add(toast))
    })
  }

  // A toast arriving any other way (a morph refresh) is timed too. The
  // server's toasts present at connect are handled by connect().
  toastTargetConnected(toast: HTMLElement): void {
    if (this.connected) this.track(toast)
  }

  disconnect(): void {
    this.connected = false
    this.stopListening?.()
    this.stopListening = undefined
    this.element.removeEventListener("turbo:before-morph-element", this.keepToast)
    if (this.frame !== undefined) window.cancelAnimationFrame(this.frame)
    this.frame = undefined
    for (const [toast, timer] of this.timers) {
      window.clearTimeout(timer.handle)
      timer.cleanup()
      this.timers.delete(toast)
    }
  }

  // The "✕" of a toast.
  close(event: Event): void {
    const toast = (event.currentTarget as HTMLElement).closest<HTMLElement>(".toast")
    if (toast) this.dismiss(toast)
  }

  private show(detail: ToastDetail | undefined): void {
    if (!detail || typeof detail.message !== "string" || detail.message === "") return
    const fragment = this.templateTarget.content.cloneNode(true) as DocumentFragment
    const toast = fragment.querySelector<HTMLElement>(".toast")
    if (!toast) return
    const title = toast.querySelector<HTMLElement>("[data-toast-part=title]")
    if (typeof detail.title === "string" && detail.title !== "") {
      if (title) title.textContent = detail.title
    } else {
      title?.remove()
    }
    const message = toast.querySelector<HTMLElement>("[data-toast-part=message]")
    if (message) message.textContent = detail.message
    const tone = detail.tone === "alert" ? "alert" : "notice"
    toast.classList.remove("toast--notice", "toast--alert")
    toast.classList.add(`toast--${tone}`)
    this.add(toast)
  }

  private add(toast: HTMLElement): void {
    this.element.insertBefore(toast, this.templateTarget)
    this.track(toast)
  }

  private track(toast: HTMLElement): void {
    if (this.timers.has(toast)) return
    // A toast with a once key that this browser already showed goes at once.
    const once = toast.dataset.toastOnce
    if (once && !firstShowing(once)) {
      toast.remove()
      return
    }
    const pause = (key: "hovered" | "focused") => () => {
      const timer = this.timers.get(toast)
      if (!timer) return
      timer[key] = true
      this.pause(timer)
    }
    const resume = (key: "hovered" | "focused") => (event: Event) => {
      const timer = this.timers.get(toast)
      if (!timer) return
      if (key === "focused" && toast.contains((event as FocusEvent).relatedTarget as Node | null)) return
      timer[key] = false
      if (!timer.hovered && !timer.focused) this.run(toast, timer)
    }
    // Esc closes the toast that holds the focus (EXPERIENCE.md, Esc).
    const escape = (event: Event): void => {
      if ((event as KeyboardEvent).key !== "Escape") return
      event.preventDefault()
      this.dismiss(toast)
    }
    const listeners: [string, EventListener][] = [
      ["keydown", escape],
      ["pointerenter", pause("hovered")],
      ["pointerleave", resume("hovered")],
      ["focusin", pause("focused")],
      ["focusout", resume("focused")],
    ]
    listeners.forEach(([type, listener]) => toast.addEventListener(type, listener))
    const timer: Timer = {
      remaining: toastDuration(toast.textContent ?? ""),
      hovered: false,
      focused: false,
      cleanup: () => listeners.forEach(([type, listener]) => toast.removeEventListener(type, listener)),
    }
    this.timers.set(toast, timer)
    this.run(toast, timer)
  }

  private run(toast: HTMLElement, timer: Timer): void {
    window.clearTimeout(timer.handle)
    timer.startedAt = performance.now()
    timer.handle = window.setTimeout(() => this.dismiss(toast), timer.remaining)
  }

  private pause(timer: Timer): void {
    if (timer.startedAt === undefined) return
    window.clearTimeout(timer.handle)
    timer.handle = undefined
    timer.remaining = Math.max(0, timer.remaining - (performance.now() - timer.startedAt))
    timer.startedAt = undefined
  }

  private dismiss(toast: HTMLElement): void {
    const timer = this.timers.get(toast)
    if (timer) {
      window.clearTimeout(timer.handle)
      timer.cleanup()
      this.timers.delete(toast)
    }
    toast.remove()
  }

  private toasts(): HTMLElement[] {
    return Array.from(this.element.querySelectorAll<HTMLElement>(":scope > .toast"))
  }
}
