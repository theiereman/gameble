import { pixelate, type Crop } from "./pixelate"
import { assertColors, type Pixels } from "./pixels"
import { quantize, type Quantized } from "./quantize"

export type FilterOptions = { width: number; height: number; colors?: number; crop?: Crop }

/** Pixelates `source` to `width × height`, then reduces it to `colors` colours. */
export function filter(source: Pixels, { width, height, colors = 16, crop = "cover" }: FilterOptions): Quantized {
  assertColors(colors)
  return quantize(pixelate(source, width, height, { crop }), colors)
}
