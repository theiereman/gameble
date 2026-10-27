export type RepostResult =
  { kind: "reposted" } | { kind: "refused"; code: string; message: string } | { kind: "failed" }

export type SendRepost = {
  url: string
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const FAILED: RepostResult = { kind: "failed" }

export function repostHref(repostUrl: string, slug: string, season: number): string {
  return repostUrl.replace("SLUG", encodeURIComponent(slug)).replace("NUMBER", String(season))
}

export async function sendRepost({
  url,
  csrfToken,
  fetch: send = globalThis.fetch,
}: SendRepost): Promise<RepostResult> {
  const headers: Record<string, string> = { Accept: "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  let response: Response
  try {
    response = await send(url, { method: "POST", headers, credentials: "same-origin" })
  } catch {
    return FAILED
  }
  if (response.ok) return { kind: "reposted" }
  if (response.status >= 500) return FAILED

  let body: unknown
  try {
    body = await response.json()
  } catch {
    return FAILED
  }
  const error = refusal(body)
  return error ? { kind: "refused", ...error } : FAILED
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

function refusal(value: unknown): { code: string; message: string } | null {
  if (!isRecord(value) || !isRecord(value.error)) return null
  const { code, message } = value.error
  return typeof code === "string" && typeof message === "string" ? { code, message } : null
}
