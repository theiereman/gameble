export type ArtAttributes = Pick<Element, "getAttributeNames" | "getAttribute">

const ART_VALUE = /^data-card-art-/

function artValueNames(element: ArtAttributes): string[] {
  return element.getAttributeNames().filter((name) => ART_VALUE.test(name))
}

export function keepsArtThroughMorph(current: ArtAttributes, incoming: ArtAttributes): boolean {
  if (current.getAttribute("data-art") === "failed") return false
  const names = new Set([...artValueNames(current), ...artValueNames(incoming)])
  return [...names].every((name) => current.getAttribute(name) === incoming.getAttribute(name))
}
