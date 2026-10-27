const BLANK = /^\s*$/

export function cloneTemplate<T extends Element = HTMLElement>(template: HTMLTemplateElement): T | null {
  const element = (template.content.cloneNode(true) as DocumentFragment).firstElementChild
  if (!element) return null
  const walker = element.ownerDocument.createTreeWalker(element, NodeFilter.SHOW_TEXT)
  const blanks: Node[] = []
  for (let node = walker.nextNode(); node; node = walker.nextNode()) if (BLANK.test(node.nodeValue ?? "")) blanks.push(node)
  blanks.forEach((node) => node.parentNode?.removeChild(node))
  return element as T
}

export function cloneContent(template: HTMLTemplateElement): DocumentFragment {
  return template.content.cloneNode(true) as DocumentFragment
}

export function cloneFirstElement<T extends Element = HTMLElement>(template: HTMLTemplateElement): T | null {
  return cloneContent(template).firstElementChild as T | null
}
