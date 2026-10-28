import { reserveCount, RESERVES } from "./booster_bank"
import { idle } from "./booster_state"
import type { BoosterBank, BoosterState, Reserve } from "./booster_types"

export function reserveSelected(state: BoosterState, reserve: Reserve): BoosterState {
  if (reserve === state.reserve || reserveCount(state.bank, reserve) <= 0 || !idle(state)) return state
  if (state.phase === "dealt" && !state.revealed.every(Boolean)) return state
  const resting = state.phase === "sealed" || state.phase === "empty"
  if (!resting) return { ...state, reserve }
  return { ...state, reserve, phase: "sealed", status: "sealed", reason: null }
}

export function reservesUnlocked(before: BoosterBank, after: BoosterBank): readonly Reserve[] {
  return RESERVES.filter((reserve) => reserveCount(before, reserve) === 0 && reserveCount(after, reserve) > 0)
}
