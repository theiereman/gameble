export type FrameScheduler = { schedule: () => void; cancel: () => void }

export function frameScheduler(callback: () => void): FrameScheduler {
  let frame = 0
  return {
    schedule: () => {
      if (frame) return
      frame = requestAnimationFrame(() => {
        frame = 0
        callback()
      })
    },
    cancel: () => {
      cancelAnimationFrame(frame)
      frame = 0
    }
  }
}
