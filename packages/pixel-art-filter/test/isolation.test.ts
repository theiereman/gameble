import { describe, expect, it } from "vitest"

// Keys are paths relative to this directory, such as "../src/filter.ts".
const sources = import.meta.glob("../src/**/*.ts", { query: "?raw", import: "default", eager: true })

// A string literal (kept) or a comment (dropped).
const STRING_OR_COMMENT = /("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g

// `from "x"`, `import "x"`, `import("x")` and `require("x")`, with any quote.
const SPECIFIER = /\b(?:from|import|require)\s*\(?\s*(["'`])([^"'`]+)\1/g

function withoutComments(source: string): string {
  return source.replace(STRING_OR_COMMENT, (_match, literal: string | undefined) => literal ?? "")
}

function resolve(from: string, specifier: string): string {
  const segments = from.split("/").slice(0, -1)
  for (const segment of specifier.split("/")) {
    if (segment === "..") {
      if (segments.length === 0 || segments[segments.length - 1] === "..") segments.push("..")
      else segments.pop()
    } else if (segment !== ".") {
      segments.push(segment)
    }
  }
  return segments.join("/")
}

describe("package isolation", () => {
  it("finds the package sources", () => {
    expect(Object.keys(sources).length).toBeGreaterThan(0)
  })

  it("imports nothing from outside the package", () => {
    for (const [path, source] of Object.entries(sources)) {
      for (const match of withoutComments(source).matchAll(SPECIFIER)) {
        const specifier = match[2]
        expect(specifier, `${path} imports ${specifier}`).toMatch(/^\.\.?\//)
        const resolved = resolve(path, specifier)
        expect(resolved, `${path} imports ${specifier}`).toMatch(/^\.\.\/(?!\.\.\/)/)
        expect(Object.keys(sources), `${path} imports ${specifier}`).toContain(resolved.endsWith(".ts") ? resolved : `${resolved}.ts`)
      }
    }
  })
})
