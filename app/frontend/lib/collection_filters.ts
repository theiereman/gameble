export const SET_OPTIONS_FRAME = "collection-set-options"
export const SET_KIND_FIELD = "set_kind"
export const RESULTS_FRAME = "collection-results"
export const RESULTS_STATUS = "collection-results-status"

export interface ChipGroup {
  name: string
  checked: readonly string[]
  fallback?: string
}

export type GroupCounts = ReadonlyMap<string, number>

export function chipsOn({ checked, fallback }: ChipGroup): number {
  if (fallback !== undefined && checked.length === 1 && checked[0] === fallback) return 0
  return checked.length
}

export function countsByGroup(groups: readonly ChipGroup[]): GroupCounts {
  const counts = new Map<string, number>()
  for (const group of groups) counts.set(group.name, (counts.get(group.name) ?? 0) + chipsOn(group))
  return counts
}

export function countOf(counts: GroupCounts, names: readonly string[]): number {
  return names.reduce((sum, name) => sum + (counts.get(name) ?? 0), 0)
}

export function totalOf(counts: GroupCounts): number {
  return countOf(counts, Array.from(counts.keys()))
}

export function groupNames(list: string | undefined): string[] {
  return (list ?? "").split(" ").filter((name) => name !== "")
}

export type Reload = "grid" | "sets" | "none"

export function reloadOnChange(field: { type: string; name: string }): Reload {
  if (field.type === "checkbox") return "grid"
  if (field.type === "radio" && field.name === SET_KIND_FIELD) return "sets"
  return "none"
}

export function reloadsSets(submitter: { dataset: DOMStringMap } | null | undefined): boolean {
  return submitter?.dataset.turboFrame === SET_OPTIONS_FRAME
}

export interface FrameSubmitter {
  type: string
  readonly dataset: DOMStringMap
  remove(): void
}

export interface FrameForm<S extends FrameSubmitter> {
  append(submitter: S): void
  requestSubmit(submitter: S): void
}

export function submitToFrame<S extends FrameSubmitter>(
  form: FrameForm<NoInfer<S>>,
  submitter: S,
  frame: string,
): void {
  submitter.type = "submit"
  submitter.dataset.turboFrame = frame
  form.append(submitter)
  try {
    form.requestSubmit(submitter)
  } finally {
    submitter.remove()
  }
}
