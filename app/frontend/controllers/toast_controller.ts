import { Controller } from "@hotwired/stimulus"
import { onGameble, type ToastAction, type ToastDetail } from "../lib/events"
import { RevealHold, firstShowing, toastActionHref, toastDuration } from "../lib/toast"

type Timer = { remaining: number; startedAt?: number; handle?: number; hovered: boolean; focused: boolean; cleanup: () => void }

// The shell's toast region: a polite live region holding the server's flash messages and any toast asked for with a `gameble:toast` event.
// Each toast pauses while hovered or focused and closes with its "✕" or Esc; a toast with a once key shows once per browser.
export default class extends Controller<HTMLElement> {
  static targets = ["template", "toast"]

  declare readonly templateTarget: HTMLTemplateElement

  private timers = new Map<HTMLElement, Timer>()
  private stopListening?: () => void
  private stopRevealing?: () => void
  private readonly revealHold = new RevealHold<HTMLElement>()
  private frame?: number
  private connected = false

  // A morph would remove or rewrite a toast still on screen: it is kept, and the new one added once the morph is over.
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
    this.stopRevealing = onGameble("gameble:opening-revealing", (detail) => this.revealingChanged(detail?.revealing === true))
    this.element.addEventListener("turbo:before-morph-element", this.keepToast)
    this.connected = true
    this.bringToTop()
    // Taken out and put back on the next frame so the live region announces them.
    const rendered = this.toasts().filter((toast) => !this.timers.has(toast))
    if (rendered.length === 0) return
    rendered.forEach((toast) => toast.remove())
    this.frame = window.requestAnimationFrame(() => {
      this.frame = undefined
      rendered.forEach((toast) => this.add(toast))
    })
  }

  toastTargetConnected(toast: HTMLElement): void {
    if (this.connected && !this.heldForReveal(toast)) this.track(toast)
  }

  disconnect(): void {
    this.connected = false
    this.stopListening?.()
    this.stopListening = undefined
    this.stopRevealing?.()
    this.stopRevealing = undefined
    this.revealHold.clear()
    this.element.removeEventListener("turbo:before-morph-element", this.keepToast)
    if (this.frame !== undefined) window.cancelAnimationFrame(this.frame)
    this.frame = undefined
    for (const [toast, timer] of this.timers) {
      window.clearTimeout(timer.handle)
      timer.cleanup()
      this.timers.delete(toast)
    }
  }

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
    this.fillAction(toast, detail.action)
    const tone = detail.tone === "alert" ? "alert" : "notice"
    toast.classList.remove("toast--notice", "toast--alert")
    toast.classList.add(`toast--${tone}`)
    this.add(toast)
  }

  private fillAction(toast: HTMLElement, action: ToastAction | undefined): void {
    const link = toast.querySelector<HTMLAnchorElement>("[data-toast-part=action]")
    if (!link) return
    const href = action && typeof action.label === "string" && action.label !== "" ? toastActionHref(action.href) : null
    if (!action || href === null) {
      link.remove()
      return
    }
    link.textContent = action.label
    link.setAttribute("href", href)
    if (typeof action.download === "string" && action.download !== "") link.setAttribute("download", action.download)
    else link.removeAttribute("download")
  }

  private add(toast: HTMLElement): void {
    if (this.heldForReveal(toast)) return
    this.element.insertBefore(toast, this.templateTarget)
    this.track(toast)
  }

  private heldForReveal(toast: HTMLElement): boolean {
    if (this.timers.has(toast) || !this.revealHold.hold(toast, toast.hasAttribute("data-toast-after-reveal"))) return false
    toast.remove()
    return true
  }

  private revealingChanged(revealing: boolean): void {
    this.revealHold.revealingChanged(revealing).forEach((toast) => this.add(toast))
  }

  private track(toast: HTMLElement): void {
    if (this.timers.has(toast)) return
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
    this.bringToTop()
  }

  // An open modal dialog's top layer covers the region unless it is shown again after it.
  private bringToTop(): void {
    const region = this.element
    if (!region.hasAttribute("popover") || typeof region.showPopover !== "function") return
    if (region.matches(":popover-open")) {
      if (document.querySelector("dialog:modal") === null) return
      region.hidePopover()
    }
    region.showPopover()
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
