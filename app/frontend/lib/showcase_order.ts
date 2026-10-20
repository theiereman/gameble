// The owner reordering their profile showcase by dragging a card, read by
// the showcase-order controller. Pure, except sendPlacement, which takes
// its fetch as an argument.

export type Point = { x: number; y: number }
export type Box = { left: number; top: number; width: number; height: number }

/** How far, in px, a mouse or pen moves with its button down before a press becomes a drag; less stays a click. */
export const DRAG_THRESHOLD = 6

/** How long a finger stays still on a card before it picks the card up; a move before then scrolls the page. */
export const TOUCH_HOLD_MS = 400

/** Whether a pointer that moved `dx`, `dy` px since its press has gone past `threshold`. */
export function pastThreshold(dx: number, dy: number, threshold = DRAG_THRESHOLD): boolean {
  return Math.hypot(dx, dy) > threshold
}

const centre = (box: Box): Point => ({ x: box.left + box.width / 2, y: box.top + box.height / 2 })

/** The index of the box whose centre is nearest `point`: the place a dragged card would take. -1 with no box. */
export function nearestIndex(point: Point, boxes: Box[]): number {
  let nearest = -1
  let best = Infinity
  boxes.forEach((box, index) => {
    const { x, y } = centre(box)
    const distance = Math.hypot(point.x - x, point.y - y)
    if (distance < best) {
      best = distance
      nearest = index
    }
  })
  return nearest
}

/** `items` with the one at `from` taken out and put at `to`, the ones between shifting one place. */
export function moveItem<T>(items: readonly T[], from: number, to: number): T[] {
  const moved = [...items]
  const [item] = moved.splice(from, 1)
  if (item === undefined) return [...items]
  moved.splice(Math.min(Math.max(to, 0), moved.length), 0, item)
  return moved
}

/** Which of a card's ◀ ▶ buttons show at `index` among `count` cards: no ◀ on the first, no ▶ on the last. */
export function edgeButtons(index: number, count: number): { earlier: boolean; later: boolean } {
  return { earlier: index > 0, later: index < count - 1 }
}

export type PlacementResult = { kind: "placed" } | { kind: "refused"; message: string } | { kind: "failed" }

export type SendPlacement = {
  url: string
  position: number
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value)

/** PATCHes the card's new place (0 first) as JSON; the server's refusal comes back with its message. */
export async function sendPlacement({ url, position, csrfToken, fetch: send = globalThis.fetch }: SendPlacement): Promise<PlacementResult> {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  let response: Response
  try {
    response = await send(url, { method: "PATCH", headers, body: JSON.stringify({ position }), credentials: "same-origin" })
  } catch {
    return { kind: "failed" }
  }
  if (response.ok) return { kind: "placed" }

  try {
    const body: unknown = await response.json()
    const message = isRecord(body) && isRecord(body.error) ? body.error.message : undefined
    return typeof message === "string" ? { kind: "refused", message } : { kind: "failed" }
  } catch {
    return { kind: "failed" }
  }
}
