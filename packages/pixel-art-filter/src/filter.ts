import { pixelate, type Crop } from "./pixelate"
import { assertColors, type Pixels } from "./pixels"
import { DEFAULT_COLORS, quantize, type Quantized } from "./quantize"

export type FilterOptions = { width: number; height: number; colors?: number; crop?: Crop; anchor?: number }

/** Pixelates `source` to `width × height`, then reduces it to `colors` colours. */
export function filter(source: Pixels, { width, height, colors = DEFAULT_COLORS, crop = "cover", anchor }: FilterOptions): Quantized {
  assertColors(colors)
  return quantize(pixelate(source, width, height, { crop, anchor }), colors)
}
