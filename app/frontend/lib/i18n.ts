export type Template = string | { zero?: string; one?: string; other: string }

export type Vars = Record<string, string | number>

export function pluralForm(template: Template, count: number | undefined): string {
  if (typeof template === "string") return template
  if (count === 0 && template.zero !== undefined) return template.zero
  if (count === 1 && template.one !== undefined) return template.one
  return template.other
}

export function t(template: Template, vars: Vars = {}): string {
  const count = typeof vars.count === "number" ? vars.count : undefined
  return pluralForm(template, count).replace(/%\{(\w+)\}/g, (match, name: string) =>
    Object.hasOwn(vars, name) ? String(vars[name]) : match,
  )
}

export function formatNumber(value: number, delimiter: string): string {
  const sign = value < 0 ? "-" : ""
  const digits = String(Math.trunc(Math.abs(value)))
  return sign + digits.replace(/\B(?=(\d{3})+(?!\d))/g, delimiter)
}
