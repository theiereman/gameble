const openers = new WeakMap<HTMLDialogElement, HTMLElement>()

export function openDialog(dialog: HTMLDialogElement, opener: HTMLElement): void {
  openers.set(dialog, opener)
  if (!dialog.open) dialog.showModal()
}

export function takeOpener(dialog: HTMLDialogElement): HTMLElement | undefined {
  const opener = openers.get(dialog)
  openers.delete(dialog)
  return opener
}
