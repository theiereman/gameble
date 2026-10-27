export class StreamHold<T> {
  private readonly reasons = new Set<string>()
  private waiting: T[][] = []

  constructor(private readonly keep: number) {}

  get held(): boolean {
    return this.reasons.size > 0
  }

  hold(reason: string): void {
    this.reasons.add(reason)
  }

  release(reason: string): T[][] {
    this.reasons.delete(reason)
    if (this.held) return []
    const batches = this.waiting
    this.waiting = []
    return batches
  }

  defer(batch: T[]): void {
    this.waiting.push(batch)
    while (this.waiting.length > 1 && this.waiting.reduce((total, each) => total + each.length, 0) > this.keep)
      this.waiting.shift()
  }
}
