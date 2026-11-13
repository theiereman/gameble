export function writeText(element: Element | null, text: string): void {
  if (element && element.textContent !== text) element.textContent = text
}

export function writeData(element: HTMLElement, name: string, value: string | null): void {
  if (value === null) {
    if (name in element.dataset) delete element.dataset[name]
  } else if (element.dataset[name] !== value) element.dataset[name] = value
}

export function writeFlag(element: Element, name: string, on: boolean): void {
  if (on) writeAttribute(element, name, "true")
  else if (element.hasAttribute(name)) element.removeAttribute(name)
}

export function writeAttribute(element: Element, name: string, value: string): void {
  if (element.getAttribute(name) !== value) element.setAttribute(name, value)
}

export function writeHidden(element: HTMLElement | null, hidden: boolean): void {
  if (element && element.hidden !== hidden) element.hidden = hidden
}

export function writeDisabled(element: HTMLButtonElement | HTMLInputElement | null, disabled: boolean): void {
  if (element && element.disabled !== disabled) element.disabled = disabled
}

export function writeValue(input: HTMLInputElement, value: string): void {
  if (input.value !== value) input.value = value
}
