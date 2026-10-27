// Opening a modal <dialog> from a button: the dialog remembers the opener so the dialog controller can give the focus back.
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
