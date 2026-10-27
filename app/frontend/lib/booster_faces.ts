import { RARITIES, type Rarity } from "./card_types"
import type { OpeningAnswer } from "./opening"
import { serverTemplate } from "./server_html"
import { cloneContent } from "./templates"

export class BoosterFaces {
  readonly rarityNames = {} as Record<Rarity, string>
  private readonly rarityLabels = {} as Record<Rarity, string>
  private readonly icons = new Map<Rarity, HTMLTemplateElement>()
  private readonly faces = new Map<number, Map<string, HTMLTemplateElement>>()

  readRarities(templates: HTMLTemplateElement[]): void {
    for (const template of templates) {
      const tier = template.dataset.tier as Rarity
      if (!RARITIES.includes(tier)) continue
      this.icons.set(tier, template)
      this.rarityNames[tier] = template.dataset.name ?? tier
      this.rarityLabels[tier] = template.dataset.label ?? this.rarityNames[tier]
    }
  }

  readFaces(templates: HTMLTemplateElement[]): void {
    this.faces.clear()
    for (const template of templates) {
      const index = Number(template.dataset.index)
      const size = template.dataset.size ?? ""
      if (!this.faces.has(index)) this.faces.set(index, new Map())
      this.faces.get(index)!.set(size, template)
    }
  }

  keepFaces(answer: OpeningAnswer): void {
    this.faces.clear()
    answer.cards.forEach((card, index) => {
      const sizes = new Map<string, HTMLTemplateElement>()
      for (const [size, html] of Object.entries(card.faces)) sizes.set(size, serverTemplate(html))
      this.faces.set(index, sizes)
    })
  }

  faceFragment(index: number, size: string): DocumentFragment | null {
    const template = this.faces.get(index)?.get(size)
    return template ? cloneContent(template) : null
  }

  icon(tier: Rarity): DocumentFragment | null {
    const template = this.icons.get(tier)
    return template ? cloneContent(template) : null
  }

  tierLabel(tier: Rarity): string {
    return this.rarityLabels[tier] ?? tier
  }
}
