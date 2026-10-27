export type TileBox = { left: number; top: number; width: number; height: number }
export type PointerAt = { clientX: number; clientY: number }
export type IrisOrigin = { x: string; y: string }

export const IRIS_X = "--iris-x"
export const IRIS_Y = "--iris-y"
export const CENTRE: IrisOrigin = { x: "50%", y: "50%" }

const clamp = (value: number, max: number): number => Math.min(Math.max(value, 0), Math.max(max, 0))

export function irisOrigin(box: TileBox, pointer: PointerAt | null): IrisOrigin {
  if (pointer === null) return CENTRE

  return {
    x: `${Math.round(clamp(pointer.clientX - box.left, box.width))}px`,
    y: `${Math.round(clamp(pointer.clientY - box.top, box.height))}px`,
  }
}

export function turnsFrom(pointerType: string): boolean {
  return pointerType === "mouse" || pointerType === "pen"
}
