export interface SubmittableForm {
  readonly dataset: DOMStringMap
  requestSubmit(): void
}

export function submitOnce(form: SubmittableForm, { preview }: { preview: boolean }): boolean {
  if (preview || form.dataset.autoSubmitted !== undefined) return false

  form.dataset.autoSubmitted = ""
  form.dataset.turboAction = "replace"
  form.requestSubmit()
  return true
}
