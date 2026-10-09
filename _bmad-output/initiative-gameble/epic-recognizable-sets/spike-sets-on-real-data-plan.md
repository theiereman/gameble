---
title: 'Sets on real data'
type: 'chore'
ticket: '1'
created: '2026-10-09'
status: 'built'
baseline_revision: '967301ec1970f2e5f5ddefa2f02e672549f23434'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The new set builder (themes, franchises, studios, hall of fame, UFOs) needs numbers only staging's real catalog can give: whether Steam's raw item carries developers and franchises, how many games each franchise and studio holds, which thirty-odd tags make the theme list with the UFOs under about 5 %, and where the hall of fame thresholds sit.

**Approach:** Run a read-only probe over staging's published season and its stored Steam items (writes prevented), write a short report beside the epic with the counts and proposals, then have the author settle the theme list, the franchise and studio minimum, the hall of fame thresholds and the tier percentages, recorded as decisions in the epic's Notes.

</frozen-after-approval>

## Implementation Notes

Oneshot: no application code changes; read-only probes, a report and the epic's Notes.

- Staging was not reachable from the agent's session (auto mode refused production reads); the author ran the three probes over SSH (`docker exec -i … bin/rails runner -`) and pasted their output.
- The probes are kept in `spike-sets-on-real-data-probes/` so story 3 or 4 can rerun them; they pass rubocop and wrap every query in `while_preventing_writes`.
- Surprises: Steam's franchise field holds publisher pages and cross-promotions; 895 cards carry adult tags; percentage tiers are crossed on every theme at once and gold at 100 % is out of reach through packs; season 2 on staging mixes two prestige formulas (logged in `deferred-work.md`).
- The author settled: franchises min 3 with the two filters, studios first developer / min 3 / 20k floor, 42 themes with Adult (UFOs 4.35 %), the four hall of fame rules, tiers 10 / 25 / 50 %. The spec's Sets section still says 25 / 50 / 100 % and "at least N games" for studios.

## Verification

**Manual checks (if no CLI):**
- `epic-recognizable-sets/spike-sets-on-real-data-report.md` gives the counts, the theme list with the UFOs' share, the franchise and studio minimum, the hall of fame thresholds and the tier percentages; each is marked agreed by the author in the epic's Notes.

## Review Triage Log

Quick review, one pass: 22 findings: 0 high, 6 medium, 15 low, 1 false; none rejected.

| # | Finding | Verdict | Action |
|---|---|---|---|
| 1 | "No smaller list stays under 5 %" contradicts the report's own figures | medium | patched: the report now says a few themes can go, but not down to thirty |
| 2 | "None are Peu commune or Rare" contradicts the Phénomènes row | low | patched |
| 3 | "51 most-reviewed games" misstates what was measured; reach unmeasured | medium | patched in the report and `deferred-work.md` (51 of the 104 games with ≥ 200k reviews; how to size it) |
| 4 | Hall of fame tiers get slower once rarities are fixed; the pace line was wrong for hall of fame sets | medium | patched: pace given per kind of set; the author is told |
| 5 | Bronze at 10 % was never simulated | low | patched: labelled a closed-form estimate |
| 6 | The simultaneous tiers stay open and are not logged | medium | deferred |
| 7 | R5, R2 and the spec still hold the old figures | medium | deferred (a spec edit) |
| 8 | 42 themes and wide tags conflict with the spec; Arcade loses its genre | medium | patched in the report; deferred with #7 |
| 9 | "Today's GenreTags plus examples" is inaccurate | low | patched |
| 10 | Theme table omits groupings | low | patched: `probe-3.rb`'s hash is authoritative, and the Note points to it |
| 11 | Lovecraftian size and the size range came from probe 2's groups | low | patched |
| 12 | Unresolved tag names not reported | low | patched: probe 3 printed `[]` |
| 13 | `steam_apps` holds the latest import, not season 2's snapshot | low | patched in the header |
| 14 | Inner join unverified | low | patched: the rarity sizes sum to 12,329 |
| 15 | The title filter tests substrings | low | patched: story 3 matches whole words |
| 16 | Franchises grouped by raw name | low | patched |
| 17 | Epic Note leaves out the franchise fixes | low | patched |
| 18 | Studio normalization strips legal words anywhere | low | patched: wording in the report |
| 19 | HTML entity counts are games with `&amp;` | low | patched |
| 20 | Simulation ignores bonus and reward packs | low | patched: stated |
| 21 | French names in repo text outside `fr.yml` | false | the planning docs already carry French UI words (spec, EXPERIENCE.md), and the names are proposals for story 3's locale files |
| 22 | Explanatory comment in `probe-2.rb` | low | patched: comment removed |
