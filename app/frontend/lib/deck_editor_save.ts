export type SaveResult =
  | { kind: "saved"; body: Record<string, unknown> }
  | { kind: "refused"; code: string; message: string }
  | { kind: "failed" }

export type SendChange = {
  url: string
  method: "POST" | "PATCH" | "DELETE"
  body: Record<string, string | null>
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

async function jsonOf(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    return null
  }
}

export async function sendChange({
  url,
  method,
  body,
  csrfToken,
  fetch: send = globalThis.fetch,
}: SendChange): Promise<SaveResult> {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  let response: Response
  try {
    response = await send(url, { method, headers, body: JSON.stringify(body), credentials: "same-origin" })
  } catch {
    return { kind: "failed" }
  }
  const json = await jsonOf(response)
  if (response.ok) return { kind: "saved", body: isRecord(json) ? json : {} }
  if (response.status !== 422 || !isRecord(json) || !isRecord(json.error)) return { kind: "failed" }
  const { code, message } = json.error
  return typeof code === "string" && typeof message === "string"
    ? { kind: "refused", code, message }
    : { kind: "failed" }
}
