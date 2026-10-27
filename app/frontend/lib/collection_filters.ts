export const SET_OPTIONS_FRAME = "collection-set-options"
export const SET_KIND_FIELD = "set_kind"

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
