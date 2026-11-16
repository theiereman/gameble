export type SparkPoint = Readonly<{ x: number; y: number }>

type Spark = {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  colour: string
  life: number
  age: number
  gravity: number
  bounces: boolean
}

const BLAST_COLOURS = ["#ffc21a", "#ffc21a", "#efe6cf", "#66c0f4", "#fff3c4", "#fff3c4", "#ff8a1f"]
const DUST_COLOURS = ["#8fa8bf", "#c9d6e2"]
const BLAST_SIZES = [4, 4, 6, 6, 8]
const FLOOR_ABOVE_EDGE = 14
const GRID = 2
const BLINK_BEFORE_END = 0.4

const pick = <T>(items: readonly T[]): T => items[Math.floor(Math.random() * items.length)]
const between = (low: number, high: number) => low + Math.random() * (high - low)

// Pixels thrown on the stage's canvas, snapped to a 2 px grid, falling and
// bouncing on the stage's floor; the loop runs only while some are alive.
export class Sparks {
  private sparks: Spark[] = []
  private frame = 0
  private last = 0

  constructor(private readonly canvas: () => HTMLCanvasElement | null) {}

  burst(from: SparkPoint, count: number): void {
    for (let index = 0; index < count; index++) {
      const angle = Math.random() * Math.PI * 2
      const speed = between(260, 900)
      this.sparks.push({
        x: from.x,
        y: from.y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 380,
        size: pick(BLAST_SIZES),
        colour: pick(BLAST_COLOURS),
        life: between(1.3, 2.4),
        age: 0,
        gravity: 1500,
        bounces: true,
      })
    }
    this.run()
  }

  dust(from: SparkPoint, reach: number): void {
    for (let index = 0; index < 12; index++) {
      const side = index % 2 === 0 ? -1 : 1
      this.sparks.push({
        x: from.x + side * reach + between(-10, 10),
        y: from.y,
        vx: side * between(60, 220),
        vy: -between(40, 160),
        size: Math.random() < 0.5 ? 4 : 6,
        colour: pick(DUST_COLOURS),
        life: between(0.35, 0.65),
        age: 0,
        gravity: 500,
        bounces: false,
      })
    }
    this.run()
  }

  clear(): void {
    this.sparks = []
    cancelAnimationFrame(this.frame)
    this.frame = 0
    const canvas = this.canvas()
    canvas?.getContext("2d")?.clearRect(0, 0, canvas.width, canvas.height)
  }

  // The canvas is drawn in CSS pixels, so a spark's place is its place on the stage.
  origin(): DOMRect | null {
    const canvas = this.canvas()
    if (!canvas) return null
    const box = canvas.getBoundingClientRect()
    const width = Math.round(box.width)
    const height = Math.round(box.height)
    if (canvas.width !== width) canvas.width = width
    if (canvas.height !== height) canvas.height = height
    return box
  }

  private run(): void {
    if (this.frame) return
    this.last = performance.now()
    this.frame = requestAnimationFrame((now) => this.step(now))
  }

  private step(now: number): void {
    const canvas = this.canvas()
    const context = canvas?.isConnected ? canvas.getContext("2d") : null
    if (!canvas || !context) {
      this.sparks = []
      this.frame = 0
      return
    }
    const elapsed = Math.min(0.05, (now - this.last) / 1000)
    this.last = now
    context.clearRect(0, 0, canvas.width, canvas.height)
    const floor = canvas.height - FLOOR_ABOVE_EDGE
    this.sparks = this.sparks.filter((spark) => this.move(spark, elapsed, floor))
    this.sparks.forEach((spark) => this.draw(context, spark))
    this.frame = this.sparks.length > 0 ? requestAnimationFrame((next) => this.step(next)) : 0
  }

  private move(spark: Spark, elapsed: number, floor: number): boolean {
    spark.age += elapsed
    if (spark.age > spark.life) return false
    spark.vy += spark.gravity * elapsed
    spark.x += spark.vx * elapsed
    spark.y += spark.vy * elapsed
    if (spark.bounces && spark.y > floor) {
      spark.y = floor
      spark.vy *= -0.42
      spark.vx *= 0.7
    }
    return true
  }

  private draw(context: CanvasRenderingContext2D, spark: Spark): void {
    const blinking = spark.life - spark.age < BLINK_BEFORE_END && Math.floor(spark.age * 20) % 2 === 1
    if (blinking) return
    context.fillStyle = spark.colour
    const snap = (value: number) => Math.round(value / GRID) * GRID
    context.fillRect(snap(spark.x), snap(spark.y), spark.size, spark.size)
  }
}
