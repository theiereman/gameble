---
title: 'A special reserve without cap'
type: 'feature'
ticket: '2'
created: '2026-10-28'
status: 'built'
baseline_revision: 'cde98feaceecbdc0061d9cb6fe723f914aafd0a0'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** the reserve counts every available capsule against its cap of 10, so a full reserve refuses the daily capsule and the goal reward, and a player holding only special capsules sees an empty reserve.

**Approach:** the shown reserve, its cap and the full state count standard capsules only; daily and goal capsules are counted apart as the special reserve, which has no cap and never refuses a claim; opening still takes the oldest available capsule of any kind, and every empty state counts both reserves.

## Boundaries & Constraints

**Always:** the hub GET writes nothing; a player holding only special capsules still opens them; the standard refill and healing keep stopping at 10 standard capsules; the special count is one total.

**Never:** the tabs, the chip links to a tab and the origin looks (entries 3 and 4); a cap or a new table for special capsules; an intro.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Claim with a full standard reserve | 10 standard available | the daily capsule and the goal reward join the special reserve | No error expected |
| Only special capsules | 0 standard, 2 special | shown reserve 0, special 2, the player opens both | No error expected |
| Empty | 0 and 0 | capsule screen shows its empty state | opening answers no capsule available |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/reserve.rb` -- the cap and the counts: standard, special, openable.
- `app/domains/game/app/queries/game/bank_summary.rb` -- adds `special` and `openable` to the summary.
- `app/domains/game/app/operations/game/collect_daily_bonus.rb`, `claim_goal_reward.rb` -- lose the full-reserve refusal.
- `app/helpers/boosters_helper.rb`, `packs_helper.rb`, `shell_helper.rb` -- bank JSON gains `special` and `openable`.
- `app/views/shell/_packs_chip.html.erb`, `pages/_menu_booster.html.erb` -- standard and special counts, none shown at zero on the hub.
- `app/views/pages/_daily_booster.html.erb`, `_goal_reward.html.erb`, `goal_rewards/create.turbo_stream.erb`, `daily_bonuses_controller.rb` -- no full state.
- `app/views/pages/how_it_works.html.erb`, `config/locales/en.yml`, `fr.yml` -- copy follows; dead keys removed.
- `app/frontend/lib/booster_*.ts`, `opening.ts` -- empty and can-open use `openable`; pips and reserve text keep `available`.
- Tests: queries, collect_daily_bonus, goal_reward, bank_races, open_pack, controllers, helpers, vitest fixtures.

## Tasks & Acceptance

**Execution:**
- [ ] `reserve.rb`, `bank_summary.rb` -- standard, special and openable counts -- one source for every view
- [ ] the two claim operations -- drop the refusal, its codes and copy -- the special reserve has no cap
- [ ] bank JSON, packs chip, hub menu, panels, turbo streams -- show both counts, no full swap -- hub and chip
- [ ] front-end bank state -- `openable` for empty and can-open -- special-only players
- [ ] how it works and locales -- follow, remove dead keys in both files
- [ ] tests -- both claims with 10 standard, special-only opening, hub writes nothing

**Acceptance Criteria:**
- Given 10 standard capsules, when the daily capsule and the goal reward are claimed, then both succeed and the standard reserve stays at 10.
- Given only special capsules, when the capsule screen loads, then it is not empty and the capsules open oldest first.

## Implementation Notes

- `Game::Reserve.counts` is the single source: standard (regular kind, cap 10), special (every other kind, uncapped), openable (their sum). The cap check and `full?` read standard only.
- Both claim operations lost their full-reserve step and failure codes; the hub panels, turbo streams and copy lost their full state.
- The bank JSON, shell helper and booster screen carry `special` and `openable`. The booster controller now receives the bank as one `bank` value instead of seven.
- Menu 01 shows a standard and a special badge, neither at zero; the packs chip gains a special count. Empty and can-open gates use `openable`.
- Boundary kept: tabs, chip links and origin colours stay with the next tickets.
- Full Ruby suite, vitest, typecheck, format, stylelint, packwerk, zeitwerk, i18n-tasks, size and planning checks pass; system tests of booster, hub, shell, countdown, daily bonus, live updates and trades pass twice.

## Plan Change Log

## Review Triage Log

Own diff review: removed the now unused `Reserve.count`; restored the zero-badge style still used by the trades badge; moved the bank attributes into one value to keep the controller under its size limit; added hub tests for the special badge and chip count and a vitest case for special-only opening. No open finding.

## Verification

**Commands:**
- `bin/rails test` of the touched files and the Game suite -- expected: 0 failures
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
