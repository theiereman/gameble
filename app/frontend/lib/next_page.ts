export const TURBO_STREAM = "text/vnd.turbo-stream.html"

export const NEAR_END_MARGIN = "0px 0px 50% 0px"

export function isTurboStream(contentType: string | null | undefined): boolean {
  return (contentType ?? "").split(";")[0].trim().toLowerCase() === TURBO_STREAM
}

export type Phase = "waiting" | "loading" | "holding" | "spent"

export type Step = { kind: "none" } | { kind: "fetch"; url: string } | { kind: "render"; answer: string }

const NOTHING: Step = { kind: "none" }

export class NextPage {
  private current: Phase = "waiting"
  private held: string | null = null

  constructor(private readonly url: string | null) {}

  get phase(): Phase {
    return this.current
  }

  approached(): Step {
    if (this.current !== "waiting" || !this.url) return NOTHING

    this.current = "loading"
    return { kind: "fetch", url: this.url }
  }

  answered(answer: string, focusInLinks: boolean): Step {
    if (this.current !== "loading") return NOTHING

    if (focusInLinks) {
      this.current = "holding"
      this.held = answer
      return NOTHING
    }
    this.current = "spent"
    return { kind: "render", answer }
  }

  focusLeft(): Step {
    if (this.current !== "holding" || this.held === null) return NOTHING

    const answer = this.held
    this.held = null
    this.current = "spent"
    return { kind: "render", answer }
  }

  failed(): void {
    this.held = null
    this.current = "spent"
  }
}

export type StreamRender<T> = (stream: T) => Promise<void> | void

export function renderingWhile<T>(render: StreamRender<T>, current: () => boolean): StreamRender<T> {
  return async (stream) => {
    if (current()) await render(stream)
  }
}
