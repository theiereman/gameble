const TRADES_PAGE = /^\/[a-z]{2}\/trades(\/.*)?$/

type TradesView = "list" | "board"

function tradesView(path: string): TradesView | null {
  const page = TRADES_PAGE.exec(path)
  if (!page) return null
  return page[1] ? "board" : "list"
}

export function keepsFrame(fromPath: string, toPath: string, { phone }: { phone: boolean }): boolean {
  if (fromPath === toPath) return true
  const from = tradesView(fromPath)
  const to = tradesView(toPath)
  if (!from || !to) return false
  // Under 720px the list and a board are each a view of their own (styles/trades.css).
  return !phone || (from === "board" && to === "board")
}
