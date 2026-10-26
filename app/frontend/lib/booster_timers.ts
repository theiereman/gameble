export type BoosterTimers = {
  readonly disposed: boolean
  wait: (ms: number) => Promise<void>
  later: (ms: number, action: () => void) => void
  dispose: () => void
}

type Clock = {
  setTimeout: (action: () => void, ms: number) => ReturnType<typeof setTimeout>
  clearTimeout: (timer: ReturnType<typeof setTimeout>) => void
}

const GLOBAL_CLOCK: Clock = {
  setTimeout: (action, ms) => globalThis.setTimeout(action, ms),
  clearTimeout: (timer) => globalThis.clearTimeout(timer),
}

export function boosterTimers(clock: Clock = GLOBAL_CLOCK): BoosterTimers {
  const pending = new Set<ReturnType<typeof setTimeout>>()
  let disposed = false

  const wait = (ms: number): Promise<void> =>
    new Promise<void>((resolve) => {
      if (disposed) return
      const timer = clock.setTimeout(() => {
        pending.delete(timer)
        if (!disposed) resolve()
      }, Math.max(0, ms))
      pending.add(timer)
    })

  return {
    get disposed() {
      return disposed
    },
    wait,
    later: (ms, action) => void wait(ms).then(action),
    dispose: () => {
      disposed = true
      pending.forEach((timer) => clock.clearTimeout(timer))
      pending.clear()
    },
  }
}
