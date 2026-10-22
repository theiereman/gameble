export function overflowsSideways(element: { scrollWidth: number; clientWidth: number }): boolean {
  return element.scrollWidth > element.clientWidth
}
