// The application's own DOM events (architecture, Consistency Conventions:
// `gameble:<noun-verb>`, declared here only). Each name maps to its detail;
// dispatchGameble and onGameble keep both ends typed.

// A toast to show (EXPERIENCE.md, Toast): the shell's toast region appends
// it from its server-rendered template.
export type ToastDetail = {
  message: string
  title?: string
  tone?: "notice" | "alert"
}

export interface GamebleEventMap {
  "gameble:toast": ToastDetail
}

export type GamebleEventName = keyof GamebleEventMap

export function dispatchGameble<K extends GamebleEventName>(name: K, detail: GamebleEventMap[K], target: EventTarget = window): void {
  target.dispatchEvent(new CustomEvent(name, { detail }))
}

// Listens on `target` (window by default) and returns the function that
// removes the listener, for a controller's disconnect.
export function onGameble<K extends GamebleEventName>(
  name: K,
  listener: (detail: GamebleEventMap[K], event: CustomEvent<GamebleEventMap[K]>) => void,
  target: EventTarget = window
): () => void {
  const handler = (event: Event): void => {
    const custom = event as CustomEvent<GamebleEventMap[K]>
    listener(custom.detail, custom)
  }
  target.addEventListener(name, handler)
  return () => target.removeEventListener(name, handler)
}
