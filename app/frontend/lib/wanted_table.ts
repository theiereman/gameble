import { amountOf, received } from "./listing_form"

export type Choice = "order" | "auction" | "entrust"

export type Picked = Readonly<{ choice: Choice | null; start: string; duration: string }>

// One line as the server drew it: `orders` are the drawn orders' prices, or the eligible orders' when `direct` is false.
export type WantedLine = Readonly<{
  ref: string
  title: string
  copies: number
  value: number
  minimum: number
  stamp: number
  average: number | null
  orders: readonly number[]
  direct: boolean
  changed: boolean
}>

export type WantedTableState = Readonly<{
  lines: readonly WantedLine[]
  picked: Readonly<Record<string, Picked>>
  drawn: Readonly<Record<string, Picked>>
  capLeft: number
  basisPoints: number
  available: number
}>

export type LineAmount = Readonly<{ amount: number; when: "now" | "start" }> | null

export type Totals = Readonly<{
  now: number
  sales: number
  salesAmount: number
  entrusted: number
  entrustedAmount: number
  listed: number
  listedAmount: number
  stamps: number
  allEntrust: number
  over: number
  overTitles: readonly string[]
  lines: Readonly<Record<string, LineAmount>>
}>

// An order at 90% of the edition's average price or more is near enough to sell to.
const NEAR_TENTHS = 9

export function start(
  lines: readonly WantedLine[],
  picked: Readonly<Record<string, Picked>>,
  { capLeft, basisPoints, available }: { capLeft: number; basisPoints: number; available: number },
): WantedTableState {
  return { lines, picked, drawn: picked, capLeft, basisPoints, available }
}

function netOf(price: number, basisPoints: number): number {
  return Number(received(BigInt(price), basisPoints))
}

// The copies a line hands to the Archives: an order line entrusts the copies no order was drawn for.
function entrustedCopies(line: WantedLine, choice: Choice | null): number {
  if (choice === "entrust") return line.copies
  if (choice === "order") return Math.max(line.copies - line.orders.length, 0)
  return 0
}

type CapWalk = { left: number }

// The operation's cap rule: copies counted in table order, a copy that does not fit is skipped and a cheaper one may pass.
function fitting(walk: CapWalk, copies: number, value: number): number {
  const fits = value > 0 ? Math.min(copies, Math.floor(walk.left / value)) : copies
  walk.left -= fits * value
  return fits
}

function auctionAt(price: number, line: WantedLine): Picked {
  return { choice: "auction", start: String(Math.max(price, line.minimum)), duration: "" }
}

// An auction at the lowest order's price converts every order; CONFIER only when the stamps cannot be paid and the copies fit the cap.
function backedPrefillOf(line: WantedLine, walk: CapWalk, funds: number): Picked {
  const stamps = line.stamp * line.copies
  if (stamps > funds && line.copies * line.value <= walk.left) return { choice: "entrust", start: "", duration: "" }
  return auctionAt(line.orders.length > 0 ? Math.min(...line.orders) : (line.average ?? line.minimum), line)
}

function prefillOf(line: WantedLine, walk: CapWalk, funds: number): Picked {
  if (!line.direct) return backedPrefillOf(line, walk, funds)
  const best = line.orders[0]
  if (best !== undefined) {
    if (line.average === null) return auctionAt(best, line)
    return best * 10 >= line.average * NEAR_TENTHS
      ? { choice: "order", start: "", duration: "" }
      : auctionAt(line.average, line)
  }
  if (line.copies * line.value <= walk.left) return { choice: "entrust", start: "", duration: "" }
  return auctionAt(line.average ?? line.minimum, line)
}

// Every line without a choice, and every line a refusal changed, takes the Prefill rule; a typed price is never overwritten.
export function prefill(state: WantedTableState): WantedTableState {
  const walk = { left: state.capLeft }
  let funds = state.available
  const picked: Record<string, Picked> = {}
  for (const line of state.lines) {
    const current = state.picked[line.ref] ?? { choice: null, start: "", duration: "" }
    let next = current
    if (current.choice === null || line.changed) {
      const rule = prefillOf(line, walk, funds)
      next = { ...current, choice: rule.choice, start: current.start.trim() === "" ? rule.start : current.start }
    }
    funds += proceeds(
      line,
      next.choice,
      fitting(walk, entrustedCopies(line, next.choice), line.value),
      state.basisPoints,
    )
    picked[line.ref] = next
  }
  return { ...state, picked, drawn: picked }
}

// What a line's choice puts in the wallet before the stamps are paid: the sales and the entrusted copies, less its stamps.
function proceeds(line: WantedLine, choice: Choice | null, entrusted: number, basisPoints: number): number {
  if (choice === "auction") return -line.stamp * line.copies
  const sold = choice === "order" ? line.orders.slice(0, line.copies) : []
  return sold.reduce((sum, price) => sum + netOf(price, basisPoints), 0) + entrusted * line.value
}

function update(state: WantedTableState, ref: string, change: Partial<Picked>): WantedTableState {
  const current = state.picked[ref]
  if (!current) return state
  const next = { ...current, ...change }
  if (next.choice === current.choice && next.start === current.start && next.duration === current.duration) return state
  return { ...state, picked: { ...state.picked, [ref]: next } }
}

export function choose(state: WantedTableState, ref: string, choice: Choice): WantedTableState {
  const line = state.lines.find((each) => each.ref === ref)
  if (!line || (choice === "order" && (!line.direct || line.orders.length === 0))) return state
  return update(state, ref, { choice })
}

export function setStart(state: WantedTableState, ref: string, start: string): WantedTableState {
  return update(state, ref, { start })
}

export function setDuration(state: WantedTableState, ref: string, duration: string): WantedTableState {
  return update(state, ref, { duration })
}

function startingNet(start: string, basisPoints: number): number {
  const price = amountOf(start)
  if (price === null || price <= 0n || price > BigInt(Number.MAX_SAFE_INTEGER)) return 0
  return Number(received(price, basisPoints))
}

export function totals(state: WantedTableState): Totals {
  const walk = { left: state.capLeft }
  const lines: Record<string, LineAmount> = {}
  let sales = 0
  let salesAmount = 0
  let entrusted = 0
  let entrustedAmount = 0
  let listed = 0
  let listedAmount = 0
  let stamps = 0
  let over = 0
  const overTitles: string[] = []
  for (const line of state.lines) {
    const { choice, start: typed } = state.picked[line.ref] ?? { choice: null, start: "" }
    if (choice === "auction") {
      const net = startingNet(typed, state.basisPoints) * line.copies
      listed += line.copies
      listedAmount += net
      stamps += line.stamp * line.copies
      lines[line.ref] = { amount: net, when: "start" }
      continue
    }
    const sold = choice === "order" ? line.orders.slice(0, line.copies) : []
    const soldAmount = sold.reduce((sum, price) => sum + netOf(price, state.basisPoints), 0)
    const wanting = entrustedCopies(line, choice)
    const fits = fitting(walk, wanting, line.value)
    if (fits < wanting) {
      over += wanting - fits
      overTitles.push(line.title)
    }
    sales += sold.length
    salesAmount += soldAmount
    entrusted += fits
    entrustedAmount += fits * line.value
    lines[line.ref] = choice === null ? null : { amount: soldAmount + fits * line.value, when: "now" }
  }
  const all = { left: state.capLeft }
  const allEntrust = state.lines.reduce((sum, line) => sum + fitting(all, line.copies, line.value) * line.value, 0)
  return {
    now: salesAmount + entrustedAmount,
    sales,
    salesAmount,
    entrusted,
    entrustedAmount,
    listed,
    listedAmount,
    stamps,
    allEntrust,
    over,
    overTitles,
    lines,
  }
}

// A choice, a price or a duration moved away from what the table drew.
export function pending(state: WantedTableState): boolean {
  return state.lines.some((line) => {
    const now = state.picked[line.ref]
    const drawn = state.drawn[line.ref]
    return now?.choice !== drawn?.choice || now?.start !== drawn?.start || now?.duration !== drawn?.duration
  })
}
