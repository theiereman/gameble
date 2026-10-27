import type { CelebrationView, ResultView } from "../controllers/booster_celebration_controller"
import { onTable, shownCelebration, shownResult, type BoosterState, type Controls } from "./booster"
import type { BoosterRenderHost } from "./booster_render_host"
import {
  countParts,
  folded,
  foldedLinkName,
  foldedMarks,
  foldedSubline,
  foldedTitle,
  gaugeFractions,
  gaugeTicks,
  juice,
  resultLinkName,
  resultTitle,
  type CelebrationResult,
} from "./celebration"
import { t } from "./i18n"

function resultView(host: BoosterRenderHost, result: CelebrationResult, position: number): ResultView {
  const strings = host.strings.celebration
  const count = countParts(result, strings, host.delimiter)
  const { from, to } = gaugeFractions(result)
  return {
    url: result.url,
    tier: result.tier,
    label: resultLinkName(result, strings, host.delimiter),
    title: resultTitle(result, strings),
    name: result.name,
    before: count.before,
    owned: count.owned,
    rest: count.rest,
    position,
    from,
    to,
    juice: juice(result.tier),
    ticks: gaugeTicks(result),
  }
}

function celebrationView(
  host: BoosterRenderHost,
  state: BoosterState,
  results: readonly CelebrationResult[],
  phone: boolean,
): CelebrationView {
  const strings = host.strings.celebration
  const isFolded = folded(results)
  const shown = shownResult(state)
  const stepping = phone && !isFolded && results.length > 1
  const subline = isFolded ? foldedSubline(results, strings) : null
  return {
    identity: results,
    steps: phone ? state.celebrationSteps : 0,
    still: state.celebrationStill && (!phone || state.celebrationSteps === 0),
    results: isFolded
      ? []
      : phone
        ? [resultView(host, results[shown], 0)]
        : results.map((result, position) => resultView(host, result, position)),
    folded:
      isFolded && subline
        ? {
            label: foldedLinkName(results, strings),
            title: foldedTitle(results, strings),
            marks: foldedMarks(results),
            lead: subline.lead,
            set: subline.set,
            tier: subline.tier,
          }
        : null,
    position: stepping ? t(strings.position, { index: shown + 1, count: results.length }) : null,
  }
}

export function renderCelebrations(host: BoosterRenderHost, state: BoosterState, view: Controls): void {
  const results = shownCelebration(state)
  const phone = state.layout === "phone"
  for (const outlet of host.outlets().celebrations) {
    const shows =
      results !== null && results.length > 0 && (outlet.phone ? phone && onTable(state) && view.plate === null : !phone)
    outlet.render(shows && results ? celebrationView(host, state, results, outlet.phone) : null)
  }
}
