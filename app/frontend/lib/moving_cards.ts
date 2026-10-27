export type CardSize = "m" | "s"
export type Lane = { start: number; end: number }

export const CARD_DIMENSIONS: Record<CardSize, { width: number; height: number }> = {
  m: { width: 160, height: 240 },
  s: { width: 112, height: 168 },
}

export const LEFT_GUTTER_CLEARANCE = 16
export const RIGHT_GUTTER_CLEARANCE = 8
export const SIDE_GAUGE_CLEARANCE = 96
export const VIEWPORT_MARGIN = 160
export const SWAY_WAVELENGTH = 420
export const ROTATION_PER_PIXEL = 0.004

export function hasGutterRoom(leftGutter: number, rightGutter: number, cardWidth: number): boolean {
  return (
    leftGutter >= cardWidth + LEFT_GUTTER_CLEARANCE + SIDE_GAUGE_CLEARANCE &&
    rightGutter >= cardWidth + RIGHT_GUTTER_CLEARANCE
  )
}

export function laneBounds(
  side: "left" | "right",
  contentLeft: number,
  contentRight: number,
  viewportWidth: number,
): Lane {
  if (side === "left") return { start: SIDE_GAUGE_CLEARANCE, end: contentLeft - LEFT_GUTTER_CLEARANCE }
  return { start: contentRight + RIGHT_GUTTER_CLEARANCE, end: viewportWidth }
}

export type Placement = {
  anchor: number
  speed: number
  sway: number
  offset: number
  rotation: number
  width: number
  height: number
  lane: Lane
}

export type Frame = {
  scrollY: number
  scrollable: number
  viewportHeight: number
  dragX: number
  dragY: number
}

export type Position = { x: number; y: number; rotation: number; visible: boolean }

export function placeCard(card: Placement, frame: Frame): Position {
  const distance = card.anchor * frame.scrollable - frame.scrollY
  const laneWidth = card.lane.end - card.lane.start
  const room = Math.max(0, (laneWidth - card.width) / 2)
  const offset = card.offset * room
  const sway = Math.min(Math.max(card.sway, 0), laneWidth / 2, Math.max(0, room - Math.abs(offset)))
  const centre = (card.lane.start + card.lane.end) / 2 + offset + Math.sin(distance / SWAY_WAVELENGTH) * sway
  const middle = frame.viewportHeight / 2 + distance * card.speed
  const x = centre - card.width / 2 + frame.dragX
  const y = middle - card.height / 2 + frame.dragY
  const visible = y + card.height > -VIEWPORT_MARGIN && y < frame.viewportHeight + VIEWPORT_MARGIN
  return { x, y, rotation: card.rotation + distance * ROTATION_PER_PIXEL, visible }
}
