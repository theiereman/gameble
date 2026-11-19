const TRADES_PAGE = /^\/[a-z]{2}\/trades(\/.*)?$/

const EXCHANGES_ROOT = /^\/[a-z]{2}\/(trades|market(\/my-(bids|sales))?)$/

type TradesView = "list" | "board"

function tradesView(path: string): TradesView | null {
  const page = TRADES_PAGE.exec(path)
  if (!page) return null
  return page[1] ? "board" : "list"
}

export function keepsFrame(fromPath: string, toPath: string, { phone }: { phone: boolean }): boolean {
  if (fromPath === toPath) return true
  if (EXCHANGES_ROOT.test(fromPath) && EXCHANGES_ROOT.test(toPath)) return true
  const from = tradesView(fromPath)
  const to = tradesView(toPath)
  if (!from || !to) return false
  const listBesideBoard = !phone
  return listBesideBoard || (from === "board" && to === "board")
}
