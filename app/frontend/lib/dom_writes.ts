export function writeText(element: Element | null, text: string): void {
  if (element && element.textContent !== text) element.textContent = text
}

export function writeData(element: HTMLElement, name: string, value: string | null): void {
  if (value === null) {
    if (name in element.dataset) delete element.dataset[name]
  } else if (element.dataset[name] !== value) element.dataset[name] = value
}

export function writeFlag(element: Element, name: string, on: boolean): void {
  if (on) element.setAttribute(name, "true")
  else element.removeAttribute(name)
}
