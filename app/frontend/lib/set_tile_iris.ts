// Where a set tile's iris opens: at the point the pointer entered the tile,
// or at its centre when the keyboard (or nothing) opens it.

export type TileBox = { left: number; top: number; width: number; height: number }
export type PointerAt = { clientX: number; clientY: number }
export type IrisOrigin = { x: string; y: string }

export const IRIS_X = "--iris-x"
export const IRIS_Y = "--iris-y"
export const CENTRE: IrisOrigin = { x: "50%", y: "50%" }

const clamp = (value: number, max: number): number => Math.min(Math.max(value, 0), Math.max(max, 0))

/** The pointer's place inside the tile, in pixels from its top left corner; the centre without a pointer. */
export function irisOrigin(box: TileBox, pointer: PointerAt | null): IrisOrigin {
  if (pointer === null) return CENTRE

  return {
    x: `${Math.round(clamp(pointer.clientX - box.left, box.width))}px`,
    y: `${Math.round(clamp(pointer.clientY - box.top, box.height))}px`,
  }
}

/** Whether a pointer of this kind opens the iris from where it enters: a finger never turns a tile. */
export function turnsFrom(pointerType: string): boolean {
  return pointerType === "mouse" || pointerType === "pen"
}
