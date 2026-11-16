---
title: 'Refactor sweep'
type: 'refactor'
ticket: '7'
created: '2026-11-16'
status: 'built'
baseline_revision: 'ae8b7b6be8607bee5b39ca472c56e4b0e339321c'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The epic's six builds left cleanup behind: explanatory comments that AGENTS.md forbids in about twenty new Ruby files, the rule "a player's deck cards" written as the same join in four places, a stat looked up by name the same way in four places, a redundant delete beside a cascading foreign key, a defensive `|| {}` repeated in four trade views, and two empty `elsif` branches in the feed views. The review triage logs and `deferred-work.md` also hold findings that need a decision: clean up, or leave for a story.

**Approach:** Make only the cleanups below, each behaviour-neutral, inside the epic's existing files; record every other finding as rejected or deferred with its reason. No new file, no migration, no change to a rendered page, a JSON answer or a lock order.

Cleanups:
1. Drop the explanatory comments the epic added to Ruby files under `app/` (class headers and the `offerable`, `by_game` and entrust/sale query sentences). Kept: `config/routes.rb`, `config/initializers/event_store.rb`, `bin/docker-entrypoint` and `db/seeds.rb` comments (their files' convention), CSS section headers, strict-locals magic comments, vitest directives, the empty `ignoreFailedKeep` body (the house pattern of `collection_seen_controller.ts`), test file headers.
2. `Game::DeckCard.of_player(player_id)` (join to the player's decks) read by `DecksHolding`, `ReservedCopies.decked`, `TradeSteps#requestable` and `DeckedEditions`. Not by `DeckSteps#decked_elsewhere`: a join under `FOR UPDATE` would also lock `game_decks` rows and change the recorded lock order.
3. `DuelProfiles::Profile#stat(name)` read by `Profile#trump`, `Profile#ranked?`, `DeckEditor#percentiles` and `DeckCoverage.percentile_in`.
4. `ReleasePlayer` stops deleting deck cards itself: `game_deck_cards.deck_id` cascades on delete, as custom set games do.
5. The four trade views pass `decks: @deck_names`: `@deck_names` is set by `load_holdings` with `@picks`, and the helpers read it only when `@picks` is set.
6. `feeds/_entry` and `shell/_live_strip_body` end their tag chain with `elsif card` instead of an empty `duel_stats` branch before `else`.

</intent-contract>

## Implementation Notes

Oneshot: about fifty mechanical lines over some twenty-five files, each change local and behaviour-neutral.

Findings weighed and not built (reason in each line):
- Rejected, cosmetic or worse after the change: the DUEL partial comparing `trump_stat` (reads plainly); `DuelProfiles.call([id])[id]` twice (two callers); `duel_stats.rarities` beside `catalog.rarity` (French needs plural adjectives); the token regex in the deck routes (the whole routes file repeats it; a constant for four lines would differ from every other route); `.deck-holding__tag` / `.trade-card__reserved` and `.sale-cell__decks` / `.deck-holding__names` (merging crosses two BEM blocks or recentres the sale cell's text, and deletes no rule); the duel post borrowing `feed__entry--set` (the previews' no-thumbnail grid depends on it); the coverage JSON built in two controllers (two callers).
- Deferred, outside the epic's files: one shared progress-bar class (other screens' stylesheets) and one day-format helper (four other helpers).
- Deferred, behaviour: `TradeSuggestions.still_spared` reading `FreeEditions` rather than `SpareCopies` (unrated editions would stop counting); the deck deletion's failure and throttle paths and the removal's fallback landing on the new-deck editor rather than Duels (a leftover of the editor being built before the Duels screen); the gap under the ÉCHANGES sub-tab bar on market screens (a visual change to check in a browser); the mid-week season run's weekly baseline and the tribute exclusion (already deferred); the native apps' compile (the author's).
- Resolved upstream: the `library_controller_test.rb` legend failure no longer reproduces in the source (it now expects "3 / 150" alone).

Built:
- 18 Ruby files lose the comments the epic added: class headers, the `offerable` and `by_game` notes, and the entrust and sale queries' added sentence (the entrust header is back to its earlier text).
- `Game::DeckCard.of_player` in `deck_card.rb`; `decks_holding.rb`, `reserved_copies.rb`, `trade_steps.rb` and `decked_editions.rb` read it. `DeckedEditions` now joins the decks instead of an `IN (SELECT id …)` subquery; same rows.
- `Profile#stat` in `duel_profiles.rb`; `deck_editor.rb` and `deck_coverage.rb` read it.
- `release_player.rb` drops its deck-card delete; `DeleteDeck` already relied on the same cascade.
- The four trade views pass `@deck_names` unguarded; `feeds/_entry` and `shell/_live_strip_body` end on `elsif card`, which is false only for the duel post.
- `deferred-work.md`: the library test entry marked resolved; three entries added for this sweep's deferrals.
- No test changed: every change keeps the SQL results, the rendered markup and the lock order; the epic's existing tests cover each touched path.
- Checks run here: `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css` clean; `ruby -c` on every changed Ruby file and an Erubi compile of every changed view. Suites run by the coordinator.

## Plan Change Log

## Review Triage Log

### 2026-11-16 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The sweep's new `deferred-work.md` entry says the new-deck fallbacks are asserted in `deck_blocked_copies_test.rb:127,138`, but those lines cover only `DeckRemovalsController`; no test asserts `DecksController#destroy`'s failure or throttle redirect — evidence corrected: the removal's two are asserted there, the deletion's two by no test.

## Verification

**Commands:** suites run by the coordinator after integration (this build runs no test, per its brief).
- `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css` -- expected: clean
- Coordinator: `bin/rails test test/domains/game test/domains/accounts test/controllers test/models test/helpers test/policies`, system tests `test/system/deck_editor_test.rb test/system/deck_blocked_copies_test.rb test/system/duel_stats_feed_test.rb test/system/duels_test.rb test/system/card_duel_profile_test.rb test/system/trade_board_test.rb test/system/trades_test.rb test/system/market_feed_test.rb test/system/landing_live_feed_test.rb`, then `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

## Auto Run Result

**Summary:** cleanup only across the duel stats and decks epic, with no change to behaviour, markup, JSON or lock order.
- The comments the epic added to 18 Ruby files are gone.
- A player's deck cards are read through one `Game::DeckCard.of_player`.
- A duel stat is looked up through one `DuelProfiles::Profile#stat`.
- `ReleasePlayer` relies on the deck cards' cascade.
- The trade views lose a fallback that is never used.
- The feed views lose two empty branches.
- Every finding from the six builds' records is either built here or recorded as rejected or deferred, with its reason (Implementation Notes, `deferred-work.md`).

**Files changed**
- Comments only: `app/controllers/concerns/{deck_changes,deck_holding_loading}.rb`, `app/controllers/deck_removals_controller.rb`, `app/domains/game/app/models/game/duel_stat_moves.rb`, `operations/game/{keep_exchanges_tab,remove_from_decks,visible_name}.rb`, `queries/game/{deck_slots,exchanges_tab,held_copies,spare_copies}.rb`, `queries/game/market/{entrustable_copies,sellable_copies}.rb`, `app/models/deck_list.rb`.
- `app/domains/game/app/models/game/deck_card.rb`: the `of_player` scope.
- `queries/game/{decks_holding,decked_editions,reserved_copies}.rb`, `operations/game/trade_steps.rb`: read `of_player`; the first three also lose their comments.
- `queries/game/duel_profiles.rb`: `Profile#stat`. `deck_coverage.rb` and `app/models/deck_editor.rb` read it; `deck_editor.rb` also loses its comment.
- `operations/game/release_player.rb`: the explicit deck-card delete is gone.
- `app/views/trades/{new,edit,index,show}.html.erb`: `decks: @deck_names`.
- `app/views/feeds/_entry.html.erb`, `app/views/shell/_live_strip_body.html.erb`: `elsif card` replaces the empty duel branch.
- `_bmad-output/initiative-gameble/deferred-work.md`: the library test entry is resolved, and three sweep deferrals are added.

**Review (quick, pinned):** 1 finding, low, patched: the evidence in a new deferred entry overstated which tests cover the new-deck fallbacks. Nothing deferred or rejected by review. The findings from the earlier builds that were weighed and not built are listed in Implementation Notes:
- Rejected: the trump comparison in the DUEL partial; `call([id])[id]`; the rarity keys; the route token regex; the tag and names CSS; `feed__entry--set` on the duel post; the coverage JSON.
- Deferred: the shared bar and day-format helpers; `still_spared`; the new-deck fallbacks; the market gap; the season baseline; the tribute exclusion; the native compile.

**Follow-up review recommended:** false. No high or medium entry was patched (patched: high 0, medium 0, low 1).

**Verification:**
- Clean: `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`.
- `ruby -c` passes on every changed Ruby file, and every changed view compiles with Rails' Erubi.
- No test, suite, packwerk or zeitwerk run, per the brief: the coordinator runs them (Verification above).

**Residual risks:**
- No test was added. Coverage of the touched paths is the epic's existing suite.
- `DeckedEditions` and `DecksHolding` now build their SQL from one join scope. The rows are the same, but the query text changed, so a query-count or SQL-shape assertion elsewhere would show it.
- The parallel duel build may also edit `duel_profiles.rb` or `deck_card.rb`. Both changes here are small additions, so a cherry-pick conflict there would be easy to settle.
