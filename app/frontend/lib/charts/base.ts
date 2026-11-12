import { compactTick } from "./format"
import type { DrawOptions } from "./types"

export const LABEL_FONT_SIZE = 11
export const LINE_WIDTH = 2
export const BAR_END_RADIUS = 4
export const ANIMATION_MS = 400
export const PICOIN_AXIS_WIDTH = 48

export function animation({ reducedMotion }: DrawOptions): false | { duration: number } {
  return reducedMotion ? false : { duration: ANIMATION_MS }
}

export function labelFont({ theme }: DrawOptions) {
  return { family: theme.fontFamily, size: LABEL_FONT_SIZE, weight: "bold" as const }
}

export function categoryAxis(options: DrawOptions) {
  return {
    type: "category" as const,
    offset: true,
    grid: { display: false, offset: true },
    border: { color: options.theme.grid },
    ticks: { color: options.theme.axisText, font: labelFont(options), maxRotation: 0, autoSkipPadding: 12 },
  }
}

export function picoinAxis(options: DrawOptions) {
  return {
    type: "linear" as const,
    grid: { color: options.theme.grid, lineWidth: 1 },
    border: { display: false },
    afterFit: (axis: { width: number }) => {
      axis.width = PICOIN_AXIS_WIDTH
    },
    ticks: {
      color: options.theme.axisText,
      font: labelFont(options),
      maxTicksLimit: 5,
      precision: 0,
      callback: (value: number | string) => compactTick(Number(value), options.locale),
    },
  }
}

export function tooltipFrame(options: DrawOptions) {
  return {
    backgroundColor: options.theme.tooltipBackground,
    borderColor: options.theme.tooltipBorder,
    borderWidth: 2,
    cornerRadius: 0,
    displayColors: false,
    titleColor: options.theme.text,
    bodyColor: options.theme.text,
    footerColor: options.theme.text,
    titleFont: labelFont(options),
    bodyFont: labelFont(options),
    footerFont: labelFont(options),
  }
}

export function dayTitle(labels: readonly string[]) {
  return (items: ReadonlyArray<{ dataIndex: number }>): string => {
    const index = items[0]?.dataIndex
    return index === undefined ? "" : (labels[index] ?? "")
  }
}
