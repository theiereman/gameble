// How long a toast stays (EXPERIENCE.md, Toast): at least 5 seconds, plus
// one second per started group of ten words.
export const TOAST_BASE_MS = 5000
export const TOAST_MS_PER_TEN_WORDS = 1000

export function toastDuration(text: string): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length
  return TOAST_BASE_MS + Math.ceil(words / 10) * TOAST_MS_PER_TEN_WORDS
}

export function toastActionHref(href: unknown): string | null {
  if (typeof href !== "string") return null
  return /^blob:/.test(href) || /^\/(?![/\\])/.test(href) ? href : null
}

// A toast a page brings on every render while its state lasts (the hub's
// goal reward) carries a key (`data-toast-once`): a browser shows it once.
// The first showing of a key records it and answers true, later ones false.
// Without usable storage (private window, blocked site data) every showing
// answers true: the toast shows rather than never.
export const TOAST_ONCE_PREFIX = "gameble:toast-once:"

type OnceStorage = Pick<Storage, "getItem" | "setItem">

function browserStorage(): OnceStorage | null {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export function firstShowing(key: string, storage: OnceStorage | null = browserStorage()): boolean {
  if (!storage) return true
  try {
    if (storage.getItem(TOAST_ONCE_PREFIX + key) !== null) return false
    storage.setItem(TOAST_ONCE_PREFIX + key, "1")
  } catch {
    // Storage refused: show the toast.
  }
  return true
}

export class RevealHold<T> {
  private revealing = false
  private held: T[] = []

  hold(toast: T, afterReveal: boolean): boolean {
    if (!afterReveal || !this.revealing) return false
    this.held.push(toast)
    return true
  }

  revealingChanged(revealing: boolean): T[] {
    this.revealing = revealing
    if (revealing) return []
    const released = this.held
    this.held = []
    return released
  }

  clear(): void {
    this.revealing = false
    this.held = []
  }
}
