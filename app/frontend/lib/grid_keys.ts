export function columnsOf(tops: number[]): number {
  const first = tops[0]
  if (first === undefined) return 1
  const columns = tops.findIndex((top) => top !== first)
  return columns === -1 ? tops.length : columns
}

export function nextIndex(key: string, index: number, count: number, columns: number): number | null {
  const last = count - 1
  switch (key) {
    case "ArrowLeft":
      return Math.max(index - 1, 0)
    case "ArrowRight":
      return Math.min(index + 1, last)
    case "ArrowUp":
      return index - columns >= 0 ? index - columns : index
    case "ArrowDown":
      return index + columns <= last ? index + columns : index
    case "Home":
      return 0
    case "End":
      return last
    default:
      return null
  }
}
