// @hotwired/turbo-rails ships no types: these are the parts of window.Turbo the app uses.

export type StreamAction = (this: Element) => void

export interface TurboGlobal {
  visit(location: string, options?: { action?: "advance" | "replace" }): void
  renderStreamMessage(message: string): void
  session: {
    refresh(url: string, options?: { method?: "morph" | "replace"; scroll?: "preserve" | "reset" }): void
    history: { restorationIdentifier: string; replace(location: URL, restorationIdentifier: string): void }
    view: { lastRenderedLocation: URL }
  }
  navigator: { currentVisit?: unknown }
  cache: { clear(): void }
  StreamActions: Record<string, StreamAction>
}

declare global {
  interface Window {
    Turbo: TurboGlobal
  }
}
