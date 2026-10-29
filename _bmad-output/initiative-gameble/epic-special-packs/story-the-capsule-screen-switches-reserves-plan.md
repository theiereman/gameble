---
title: 'The capsule screen switches reserves'
type: 'feature'
ticket: '3'
created: '2026-10-28'
status: done
baseline_revision: '07e042d3a7c45c94abc94a78dc2235f8b546078b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** the capsule screen opens the oldest capsule of one undivided reserve; the player cannot choose between standard and special capsules, the chips and the hub entry cannot send them to the right tab, and a capsule arriving while the screen is open is not signalled.

**Approach:** the screen shows STANDARD and SPÉCIALES tabs; the selected tab decides which reserve's oldest capsule opens; the opening request names the reserve; the tabs enable live when a capsule appears.

## Boundaries & Constraints

**Always:** both tabs always shown, an empty tab greyed, disabled and named unavailable with its reason; opening the screen selects STANDARD, or SPÉCIALES when no standard capsule is available, or the tab the chip asked for; a tab unlocking while the player is on the page enables plainly (polite announcement, selected tab and focus unchanged, no badge, no highlight); the oldest capsule of the selected tab opens first and its origin name (daily capsule, goal reward) shows on the canister and in the "EN OUVERTURE" panel; the standard reserve keeps its pips and countdown, the special one has neither; vocabulary "capsule standard" / "capsule spéciale"; the reveal itself is unchanged.

**Never:** the per-origin colours and emblems (their own ticket); a new route or a database id in a URL; a write on GET; React or markup built in script (server templates cloned by the controller); a `style` attribute.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Both kinds | 3 standard, 2 special, tab SPÉCIALES chosen | the oldest special opens, standard untouched | none |
| No standard | 0 standard, 2 special, plain entry | screen opens on SPÉCIALES | none |
| Chip | special chip followed | screen opens on SPÉCIALES; with 0 special the chip is disabled | invalid reserve param falls back to the default tab |
| Live unlock | standard countdown ends on the page | STANDARD enables, announcement, selection unchanged | none |
| Emptied tab | last special opened, standard left | next opening uses the other reserve | no capsule at all: empty state |
| Bad request | POST with an unknown reserve | 400 `invalid_reserve` | message in both locales |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/reserve.rb`, `bank_summary.rb` -- add the reserve kinds, `next_special_kind`
- `app/domains/game/app/operations/game/open_pack.rb` -- `reserve:` keyword picks the oldest capsule of that reserve; unknown value is `Failure(:invalid_reserve)`
- `app/controllers/packs_controller.rb`, `boosters_controller.rb` -- pass the reserve; choose the initial tab
- `app/helpers/boosters_helper.rb`, `packs_helper.rb` -- `reserve` value on the root, `nextSpecialKind` in both JSON banks
- `app/views/boosters/_reserves.html.erb` (new), `_strip`, `_info`, `_booster`, `_canister` -- the tablist and the origin line
- `app/frontend/lib/booster_*.ts`, `opening.ts` -- `reserve` in the state, selection transition, request parameter
- `app/frontend/controllers/booster_reserves_controller.ts` (new), `booster_controller.ts`, `booster_info_controller.ts`, `booster_canister_controller.ts` -- render and select
- chips and hub entry partials (grep `booster_path`) -- the tab each link opens

## Tasks & Acceptance

**Execution:**
- [ ] Backend: reserve kinds, `OpenPack` keyword, controller params, JSON, initial tab, locale keys
- [ ] Views: tablist, origin line, chip links
- [ ] Frontend: state, bank parsing, opening request, tabs controller, announcements, info panel per reserve
- [ ] CSS for the tabs in the booster stylesheet
- [ ] Tests: operation, controllers, vitest state, system test

**Acceptance Criteria:**
- Given both kinds, when the player selects SPÉCIALES and opens, then the oldest special capsule opens and the standard reserve is unchanged.
- Given no special capsule, then SPÉCIALES is disabled with its reason and cannot be selected.
- Given the screen open with 0 standard, when a countdown ends, then STANDARD enables without moving the selection.

## Implementation Notes

- The opening request names the reserve as a `reserve` query parameter; the bank (page values, opening answer, JSON bank) carries `nextSpecialKind`; `gameble:bank-changed` already carried both counts and now drives both top-bar chips.
- `Game::Reserve.counts` returns the oldest special kind from the same single query, so the bank summary stays at two queries.
- Tabs render server side and are rewritten by `booster-reserves`; the root state holds `reserve`, switches to the other reserve when the selected one empties after an opening, and leaves the selection alone when a tab unlocks live (announcement only).
- Top bar: `packs-chip` link (standard) plus `special-chip` link to the special tab, greyed and out of the tab order at zero; the booster screen's static chip gets a static special chip; the daily capsule arc flies to the special chip.
- Not done: no test or check was run after the session crash (the coordinator runs them once). The packs-chip glow was not touched; the live tab unlock has unit coverage only.

## Plan Change Log

## Review Triage Log

Self-review of the diff: no high or medium finding; low: the origin shown before an opening can differ from the pack drawn when a daily and a goal capsule share one timestamp (the opening panel then shows the drawn pack's origin).

## Verification

**Commands:**
- `bin/rails test` on touched suites, `bin/rails test test/system/booster_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: clean
