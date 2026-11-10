import { flush, idle, offer, type Throttle } from "./annonce_status"

export const OUTBID_INTERVAL_MS = 30_000

export type Outbids = ReadonlyMap<string, Throttle>

export type OutbidStep = { outbids: Outbids; say: string | null; wait: number | null }

export const noOutbids: Outbids = new Map()

function stepped(outbids: Outbids, key: string, { throttle, say, wait }: ReturnType<typeof offer>): OutbidStep {
  return { outbids: new Map(outbids).set(key, throttle), say, wait }
}

export function offerOutbid(outbids: Outbids, key: string, text: string, now: number): OutbidStep {
  return stepped(outbids, key, offer(outbids.get(key) ?? idle, text, "milestone", now, false, OUTBID_INTERVAL_MS))
}

export function flushOutbid(outbids: Outbids, key: string, now: number): OutbidStep {
  return stepped(outbids, key, flush(outbids.get(key) ?? idle, now))
}
