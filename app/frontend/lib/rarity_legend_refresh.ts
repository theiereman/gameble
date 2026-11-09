import type { ChipRefresh } from "./countdown"

export type RarityLegendRefreshHost = Readonly<{
  fetchLegend: () => Promise<ChipRefresh>
  render: (html: string) => void
}>

export class RarityLegendRefresh {
  private wasRevealing = false
  private stopped = false

  constructor(private readonly host: RarityLegendRefreshHost) {}

  openingChanged(revealing: boolean): void {
    if (this.wasRevealing && !revealing) void this.refresh()
    this.wasRevealing = revealing
  }

  stop(): void {
    this.stopped = true
  }

  private async refresh(): Promise<void> {
    const refresh = await this.host.fetchLegend()
    if (!this.stopped && refresh.kind === "render") this.host.render(refresh.html)
  }
}
