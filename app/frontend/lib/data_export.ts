export type ExportPhase = "idle" | "preparing" | "failed"

export type ExportLabels = { idle: string; preparing: string; retry: string }

export type ExportButton = { label: string; disabled: boolean }

export function exportButton(phase: ExportPhase, labels: ExportLabels): ExportButton {
  switch (phase) {
    case "preparing":
      return { label: labels.preparing, disabled: true }
    case "failed":
      return { label: labels.retry, disabled: false }
    default:
      return { label: labels.idle, disabled: false }
  }
}

export const FALLBACK_FILENAME = "gameble-export.json"

export function exportFilename(contentDisposition: string | null): string {
  if (!contentDisposition) return FALLBACK_FILENAME
  const encoded = /filename\*=UTF-8''([^;]+)/i.exec(contentDisposition)
  const decoded = encoded ? decodedOrNull(encoded[1].trim()) : null
  if (decoded !== null) return plainFilename(decoded)
  const quoted = /filename="([^"]*)"/i.exec(contentDisposition) ?? /filename=([^;]+)/i.exec(contentDisposition)
  return quoted ? plainFilename(quoted[1].trim()) : FALLBACK_FILENAME
}

function decodedOrNull(value: string): string | null {
  try {
    return decodeURIComponent(value)
  } catch {
    return null
  }
}

function plainFilename(name: string): string {
  const base = name.split(/[\\/]/).pop() ?? ""
  return base === "" ? FALLBACK_FILENAME : base
}

export function failureMessage(body: unknown, fallback: string): string {
  if (typeof body !== "object" || body === null) return fallback
  const error = (body as { error?: unknown }).error
  if (typeof error !== "object" || error === null) return fallback
  const message = (error as { message?: unknown }).message
  return typeof message === "string" && message.trim() !== "" ? message : fallback
}

export function exportedAt(file: string): Date | null {
  try {
    const value: unknown = (JSON.parse(file) as { exportedAt?: unknown }).exportedAt
    const date = typeof value === "string" ? new Date(value) : null
    return date && !Number.isNaN(date.getTime()) ? date : null
  } catch {
    return null
  }
}

export function formatUtc(date: Date, pattern: string): string {
  const pad = (value: number) => String(value).padStart(2, "0")
  const parts: Record<string, string> = {
    d: pad(date.getUTCDate()),
    m: pad(date.getUTCMonth() + 1),
    Y: String(date.getUTCFullYear()),
    H: pad(date.getUTCHours()),
    M: pad(date.getUTCMinutes()),
  }
  return pattern.replace(/%([dmYHM])/g, (_, key: string) => parts[key])
}
