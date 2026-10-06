// The islands' words (AD-18): every template comes from the locale files
// through props, resolved here, never written in code. Pure: no DOM.

/** A locale string, or a plural one as Rails' I18n stores it. */
export type Template = string | { zero?: string; one?: string; other: string }

export type Vars = Record<string, string | number>

/**
 * The plural form for `count`, by the app's I18n default rule (used by
 * both locales): `zero` when the count is 0 and the template has one,
 * `one` when it is 1, else `other`.
 */
export function pluralForm(template: Template, count: number | undefined): string {
  if (typeof template === "string") return template
  if (count === 0 && template.zero !== undefined) return template.zero
  if (count === 1 && template.one !== undefined) return template.one
  return template.other
}

/**
 * The template filled in: its plural form picked by `vars.count`, then
 * each `%{name}` replaced by `vars.name`. A placeholder without a value is
 * left as it is, so a missing word shows rather than vanishes.
 */
export function t(template: Template, vars: Vars = {}): string {
  const count = typeof vars.count === "number" ? vars.count : undefined
  return pluralForm(template, count).replace(/%\{(\w+)\}/g, (match, name: string) =>
    Object.hasOwn(vars, name) ? String(vars[name]) : match,
  )
}

/**
 * A whole number with its digits grouped by three with the locale's
 * delimiter (`number.format.delimiter`: U+00A0 in French, "," in English).
 */
export function formatNumber(value: number, delimiter: string): string {
  const sign = value < 0 ? "-" : ""
  const digits = String(Math.trunc(Math.abs(value)))
  return sign + digits.replace(/\B(?=(\d{3})+(?!\d))/g, delimiter)
}
