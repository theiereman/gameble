import type { RevealMode } from "./booster_types"
import { NO_TIMINGS, type OpeningTimings } from "./opening_timings"

export type SendReveal = {
  url: string
  mode: RevealMode
  timings?: OpeningTimings
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

export async function sendReveal({
  url,
  mode,
  timings = NO_TIMINGS,
  csrfToken,
  fetch: send = globalThis.fetch,
}: SendReveal): Promise<void> {
  const headers: Record<string, string> = { Accept: "application/json", "Content-Type": "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken
  try {
    await send(url, {
      method: "POST",
      headers,
      body: JSON.stringify({ mode, ...timings }),
      credentials: "same-origin",
      keepalive: true,
    })
  } catch {
    return
  }
}
