---
title: 'The collection grid hides the missing cards by default, where owned cards should come first'
type: 'bugfix'
ticket: '9'
created: '2026-10-13'
status: 'built'
baseline_revision: '2cec8912b67deec6bd190f3e0392d48eaf574748'
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

**Problem:** With no state asked, the collection grid shows only the owned cards whenever the player holds any card of the season, so the missing slots are hidden and a set's album the player holds nothing of opens empty.

**Approach:** The state shown when none is asked is always "all": the whole season keeps its newest-gained-first order (owned before missing), a set keeps its slot order; the filter zone, its count, its script and the card detail's walk use that one default; EXPERIENCE.md's Collection opening row says so.

</frozen-after-approval>

## Implementation Notes

Oneshot: about forty lines across the state query, the grid loading concern, the card detail's walk, the filter helper and script, their tests and one EXPERIENCE.md row. The order under "all" already puts held cards first, newest gain first (`Game::CollectionStates`, `newest_first` on the whole season only), so only the default changes. One default, `Game::CollectionStates::DEFAULT`, replaces `grid_default_state(unique)`; the card detail no longer counts the viewer's cards to find it.

Files: `packs/game/app/queries/game/collection_states.rb` (`DEFAULT = "all"`, the default when no state is asked), `app/controllers/concerns/collection_grid_loading.rb` (`grid_default_state` removed), `app/controllers/library_controller.rb`, `app/controllers/cards_controller.rb` (one query fewer on a detail opened from the grid), `app/helpers/collection_helper.rb` and the library views (the `state_default` local removed, the filter zone reads the constant), `app/frontend/controllers/collection_filters_controller.ts` (fallback "all"), `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (Collection opening row). Tests: the tests that leaned on the owned default now read the owned slots among every slot, or pin every slot; a new set test covers a set album with nothing owned and the filter count on opening. Verification: the full suite has 2 failures that also fail on the baseline (a 14-day trade window and the 30-day session cookie across the daylight saving change), recorded in `deferred-work.md`; everything else green (vitest 224, typecheck, rubocop, packwerk, i18n-tasks, zeitwerk).

## Review Triage Log

Quick review, 3 findings (1 high, 1 low, 1 low).
- high, patch: with TOUT checked by default, switching on POSSÉDÉES (or another state) kept TOUT checked, the form sent both, the grid did not narrow and the count read 2. Fixed: `Game::CollectionStates.sanitize` drops `all` beside another state (server, without JavaScript too), and the filter script unchecks TOUT when another state is switched on and the others when TOUT is; a controller test asks `all` with `owned` and gets the owned cards, the POSSÉDÉES chip alone checked, a count of 1.
- low, defer: the disabled system test of the FILTRES zone still pins the owned default; entry in `deferred-work.md` (system tests cannot be run to verify an edit).
- low, patch: the set test's count-on-opening assertion passed on the baseline too; the new narrowing test covers the count where the default changed.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `npm run test:js`, `npm run typecheck`, `bin/rubocop`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/rails zeitwerk:check` -- expected: green
