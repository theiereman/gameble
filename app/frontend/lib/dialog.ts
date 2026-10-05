// Opening a modal <dialog> from a button (EXPERIENCE.md, Modal): the dialog
// remembers which element opened it, so the dialog controller can give the
// focus back to it when it closes.
const openers = new WeakMap<HTMLDialogElement, HTMLElement>()

export function openDialog(dialog: HTMLDialogElement, opener: HTMLElement): void {
  openers.set(dialog, opener)
  if (!dialog.open) dialog.showModal()
}

// The element that opened the dialog last, forgotten once read.
export function takeOpener(dialog: HTMLDialogElement): HTMLElement | undefined {
  const opener = openers.get(dialog)
  openers.delete(dialog)
  return opener
}
