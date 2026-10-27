import { describe, expect, it } from "vitest"
import {
  FALLBACK_FILENAME,
  exportButton,
  exportFilename,
  exportedAt,
  failureMessage,
  nextExportAt,
} from "./data_export"

const labels = { idle: "Exporter", preparing: "Préparation…", retry: "Réessayer" }

describe("exportButton", () => {
  it("offers the export at rest", () => {
    expect(exportButton("idle", labels)).toEqual({ label: "Exporter", disabled: false })
  })

  it("is disabled and says so while the export is prepared", () => {
    expect(exportButton("preparing", labels)).toEqual({ label: "Préparation…", disabled: true })
  })

  it("is disabled under its usual label until the next export is allowed", () => {
    expect(exportButton("waiting", labels)).toEqual({ label: "Exporter", disabled: true })
  })

  it("offers a retry after a failure", () => {
    expect(exportButton("failed", labels)).toEqual({ label: "Réessayer", disabled: false })
  })
})

describe("exportFilename", () => {
  it("reads the file name the server gives", () => {
    const header = `attachment; filename="gameble-export-2026-10-14.json"; filename*=UTF-8''gameble-export-2026-10-14.json`
    expect(exportFilename(header)).toBe("gameble-export-2026-10-14.json")
    expect(exportFilename(`attachment; filename="gameble-export-2026-10-14.json"`)).toBe(
      "gameble-export-2026-10-14.json",
    )
    expect(exportFilename("attachment; filename=gameble-export-2026-10-14.json")).toBe("gameble-export-2026-10-14.json")
  })

  it("keeps only the last path segment", () => {
    expect(exportFilename(`attachment; filename="../../etc/passwd"`)).toBe("passwd")
  })

  it("falls back to a fixed name without a usable header", () => {
    expect(exportFilename(null)).toBe(FALLBACK_FILENAME)
    expect(exportFilename("attachment")).toBe(FALLBACK_FILENAME)
    expect(exportFilename(`attachment; filename=""`)).toBe(FALLBACK_FILENAME)
    expect(exportFilename(`attachment; filename*=UTF-8''%E0%A4%A; filename="plain.json"`)).toBe("plain.json")
  })
})

describe("failureMessage", () => {
  it("reads the message of the server's error", () => {
    expect(
      failureMessage({ error: { code: "throttled", message: "Un export toutes les 5 minutes au plus." } }, "Échec"),
    ).toBe("Un export toutes les 5 minutes au plus.")
  })

  it("falls back on anything else", () => {
    expect(failureMessage(null, "Échec")).toBe("Échec")
    expect(failureMessage("oops", "Échec")).toBe("Échec")
    expect(failureMessage({}, "Échec")).toBe("Échec")
    expect(failureMessage({ error: "throttled" }, "Échec")).toBe("Échec")
    expect(failureMessage({ error: { message: "  " } }, "Échec")).toBe("Échec")
    expect(failureMessage({ error: { message: 42 } }, "Échec")).toBe("Échec")
  })
})

describe("exportedAt", () => {
  it("reads the export's time from the file", () => {
    expect(exportedAt(JSON.stringify({ exportedAt: "2026-10-14T09:30:00Z" }))?.toISOString()).toBe(
      "2026-10-14T09:30:00.000Z",
    )
  })

  it("gives nothing for a file it cannot read", () => {
    expect(exportedAt("not json")).toBeNull()
    expect(exportedAt(JSON.stringify({}))).toBeNull()
    expect(exportedAt(JSON.stringify({ exportedAt: "yesterday" }))).toBeNull()
  })
})

describe("nextExportAt", () => {
  it("reads when the next export is allowed from a refusal", () => {
    const body = { error: { code: "export_too_soon", message: "…", nextExportAt: "2026-10-14T09:35:00Z" } }
    expect(nextExportAt(body)?.toISOString()).toBe("2026-10-14T09:35:00.000Z")
  })

  it("gives nothing for any other failure", () => {
    expect(nextExportAt(null)).toBeNull()
    expect(nextExportAt({ error: { code: "player_required", message: "…" } })).toBeNull()
    expect(nextExportAt({ error: { nextExportAt: "soon" } })).toBeNull()
  })
})
