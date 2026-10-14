export type AtZero = "wait" | "visit" | "fetchChip" | "stop"

export type CountdownState = {
  submitting: boolean
  refreshPage: boolean
  refreshUrl: string
}

export type ChipRefresh = { kind: "render"; html: string } | { kind: "retry" } | { kind: "stop" }

export function atZero({ submitting, refreshPage, refreshUrl }: CountdownState): AtZero {
  if (submitting) return "wait"
  if (refreshPage) return "visit"
  if (refreshUrl) return "fetchChip"
  return "stop"
}

export async function fetchChip(url: string, send: typeof globalThis.fetch = globalThis.fetch): Promise<ChipRefresh> {
  try {
    const response = await send(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.ok) return { kind: "render", html: await response.text() }
    return response.status >= 500 ? { kind: "retry" } : { kind: "stop" }
  } catch {
    return { kind: "retry" }
  }
}
