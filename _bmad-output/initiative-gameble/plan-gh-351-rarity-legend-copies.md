---
title: 'The rarity legend shows copies and stays current after an opening'
type: 'bugfix'
ticket: ''
created: '2026-11-09'
status: 'built'
baseline_revision: '2d352fb9b4a18dcac15e93ca6752a7f7ce5600d8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** GitHub #351: players read the top bar and its rarity popover as out of sync. The bar sums copies, duplicates included (1,395 commons), while the popover counts distinct cards (1,283), and on the capsule screen the popover keeps its page-load figures after an opening.

**Approach:** Add a "Copies" column to the popover holding exactly the bar's figures, per rarity and in total, so the two read as different measures. Re-render the popover from the server when an opening's reveal ends.

## Boundaries & Constraints

**Always:** The Copies figure per rarity equals the bar's for the same player, by reusing `Game::TierCounts`. Strings in both locales ("Copies" / "Exemplaires"). At phone width (`max-width: 719px`) the popover drops the "This season" column and keeps Rarity, All seasons, Copies. The chrome hears the opening only through the existing `gameble:opening-revealing` event. A failed refresh leaves the current figures in place silently.

**Never:** Change what the top bar counts or how it ticks during a reveal. Replace `#rarity-counter` after an opening (that would rewrite the bar and could show a next capsule's unrevealed cards). Add `data-rarity-counter-target` inside the legend (tests guard this). Touch friend invitations (#354) or comment on GitHub.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Duplicates | 3 copies of one common | Row: All seasons 1, Copies 3 | No error expected |
| No copy left | Holding with quantity 0 | Copies 0 | No error expected |
| Totals | Copies across rarities | Total row Copies = sum of the five | No error expected |
| Opening ends | `revealing` goes true then false | One fetch; `#rarity-legend` replaced | Non-OK or network failure: nothing changes |
| Page connects idle | `revealing: false` with no prior true | No fetch | No error expected |
| Controller gone mid-fetch | Navigation during the request | Response is not rendered | No error expected |
| Signed-out request | GET without a player | Refused by policy | Standard Pundit refusal |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/rarity_legend.rb` -- `Row`/`Legend` data; `self.row` builds figures. Add copies here.
- `app/domains/game/app/queries/game/tier_counts.rb` -- copies per tier keyed by tier number; reuse unchanged.
- `app/helpers/shell_helper.rb:179-185` -- memoized `shell_tier_counts` and `shell_rarity_legend`; pass the former to the latter to avoid a second query.
- `app/views/shell/_rarity_legend.html.erb` -- the table; rendered by `_rarity_counter.html.erb` and `library/_status.html.erb`.
- `app/views/shell/_rarity_counter.html.erb` -- root of `rarity-counter` controller; add the legend URL value.
- `app/frontend/controllers/rarity_counter_controller.ts` -- listens to `gameble:tier-revealed`; add the opening listener.
- `app/frontend/lib/countdown.ts:18` -- `fetchChip` is a generic turbo-stream GET returning `ChipRefresh`; reuse it. `countdown_controller.ts:102-108` shows the guarded render.
- `app/frontend/lib/booster_rules.ts:23` -- revealing statuses; `complete` is outside them, so `revealing` falls to false when a reveal ends. `booster_controller.ts:177` dispatches `false` on connect, hence the true-then-false guard.
- `app/controllers/packs_chips_controller.rb`, `app/policies/top_bar_policy.rb`, `app/views/top_bars/show.turbo_stream.erb` -- pattern for a one-stream GET. `top_bars#show` is only called by the native bridge; do not reuse it on web.
- `app/frontend/styles/shell-rarity-legend.css`, `shell-screens.css:114` -- legend styles; phone media query.
- `test/integration/shell_test.rb:177-215`, `test/controllers/library_controller_test.rb:119`, `test/domains/game/rarity_legend_test.rb`, `test/controllers/top_bars_controller_test.rb` -- tests to update or mirror.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/rarity_legend.rb` -- `call(player, copies: TierCounts.call(player))`; `Row` gains `copies`, totals get the sum -- one source for the bar's figures.
- [ ] `app/helpers/shell_helper.rb` -- pass `copies: shell_tier_counts` -- no extra query on pages with the bar.
- [ ] `app/views/shell/_rarity_legend.html.erb` -- fourth `<th scope="col">` and a `td.rarity-legend__copies` in each body and total row; mark the season column cells for phone hiding -- the column itself.
- [ ] `app/frontend/styles/shell-rarity-legend.css` -- copies cell styled as the owned figure; inside `@media (max-width: 719px)` hide the season column -- four columns do not fit a phone.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `shell.rarity.columns.copies` -- both locales.
- [ ] `config/routes.rb`, `app/controllers/rarity_legends_controller.rb`, `app/policies/rarity_legend_policy.rb`, `app/views/rarity_legends/show.turbo_stream.erb` -- GET `rarity-legend` replacing `#rarity-legend` -- refresh only the popover.
- [ ] `app/views/shell/_rarity_counter.html.erb`, `app/frontend/controllers/rarity_counter_controller.ts` -- legend URL value; on `gameble:opening-revealing` true then false, `fetchChip` and render unless disconnected -- closes the stale window.
- [ ] `test/domains/game/rarity_legend_test.rb` -- copies per rarity, zero quantity, total sum, equality with `TierCounts`.
- [ ] `test/integration/shell_test.rb`, `test/controllers/library_controller_test.rb` -- four headers in both locales, Copies shown; repoint assertions that assumed the last cell is the owned figure.
- [ ] `test/controllers/rarity_legends_controller_test.rb` -- player gets the replace stream, signed-out request is refused.
- [ ] `test/system/` opening test touching the counter -- after a reveal ends, the popover shows the new figures, with retrying matchers.

**Acceptance Criteria:**
- Given a player with duplicates, when they open the popover from the bar, then each Copies figure equals the bar's figure for that rarity.
- Given the capsule screen, when a reveal finishes, then the popover's owned and Copies figures include that capsule without navigation.
- Given a phone-width viewport, when the popover opens, then it shows three columns with no horizontal overflow.

## Implementation Notes

Extracted `RarityLegendRefresh` from the controller so the idle, failure and stopped-mid-request rows are unit tested. The library screens have no top bar counter, so they pay one extra query for the copies: their query budgets go up by one.

## Plan Change Log

## Review Triage Log

Pass 1 (quick): high 0, medium 0, low 2, false 0, maybe-false 0.

| Verdict | Route | Finding | Evidence |
|---|---|---|---|
| low | patch | French three-column table overflows the popover at phone width | Confirmed in the real app: fixed by tighter phone padding and gap. Measured with the longest figures: no overflow at 360, 375, 390; 2px at 320. |
| low | rejected | Legend stays stale when a held capsule's POST outlasts its reveal | Mechanism confirmed (`booster_opening_sequence.ts:127`, `opening_queue.ts:15`), but the POST must outlast a multi-second reveal or fail, and the next navigation heals it. The fix adds a second listener and a guard, and the intent allows only `gameble:opening-revealing`. |

## Design Notes

`Game::RarityLegend` takes `copies:` rather than adding `SUM(quantity)` to its SQL: its query keeps published seasons only and `TierCounts` does not, so a second computation could drift from the bar.

`replace` on `#rarity-legend` closes the popover if it is open when a reveal ends; a player is watching cards at that moment, so this is accepted over splitting the partial.

## Verification

**Commands:**
- `bin/rails test test/domains/game/rarity_legend_test.rb test/integration/shell_test.rb test/controllers/library_controller_test.rb test/controllers/rarity_legends_controller_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass
- `bin/rails test test/system/<touched file>.rb -n /name/` -- expected: pass
