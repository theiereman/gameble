export const TYPING_PAUSE_MS = 300

export type Timers = {
  set(callback: () => void, delay: number): number
  clear(handle: number | undefined): void
}

const windowTimers: Timers = {
  set: (callback, delay) => window.setTimeout(callback, delay),
  clear: (handle) => window.clearTimeout(handle),
}

export class Debounce {
  private handle: number | undefined

  constructor(
    private readonly delay: number = TYPING_PAUSE_MS,
    private readonly timers: Timers = windowTimers,
  ) {}

  call(callback: () => void): void {
    this.cancel()
    this.handle = this.timers.set(() => {
      this.handle = undefined
      callback()
    }, this.delay)
  }

  cancel(): void {
    this.timers.clear(this.handle)
    this.handle = undefined
  }
}

export function clearsOnEscape(key: string, value: string): boolean {
  return key === "Escape" && value !== ""
}

export function summaryOf(text: string | null | undefined): string {
  return (text ?? "").trim()
}
