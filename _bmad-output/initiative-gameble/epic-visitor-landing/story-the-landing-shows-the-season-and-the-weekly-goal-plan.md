---
title: 'The landing shows the season and the weekly goal'
type: 'feature'
ticket: '5'
created: '2026-10-22'
status: 'built'
baseline_revision: 'c940aa7ff17cb1e53edeb87ca19b885cde10d5ab'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      The goal block's cached figures can lag the Monday boundary by up to a minute while the end time is computed fresh.
    evidence: |-
      Cache key is locale only; accepted stale window, untested.
    severity: low
  - summary: >-
      No request-level test shows the landing itself hits the cache; it is tested at query level.
    evidence: |-
      test/packs/game/landing_queries_test.rb uses a memory store; controller tests run on the null store.
    severity: low
---

<intent-contract>

## Intent

**Problem:** The landing's season panel (module 04) and goal panel (module 02) show "—" placeholders; the visitor sees no season, no figures and no weekly goal.

**Approach:** Two cached queries (per locale, short lifetime) feed the panels: the published season with its three facts, and the current weekly goal with its count, target, gauge and participants, its end shown in the visitor's time zone. A figure that cannot be read shows "—" and the rest renders.

Decisions of the author (theiereman, 2026-10-22): "this week" is the weekly goal's calendar week (Monday 00:00 UTC, the same week as the goal), and "today" is the game's UTC day.

## Boundaries & Constraints

**Always:** Read through the pack's queries; a GET never writes. Cache each block per locale for a short lifetime and cache values, never database ids. No `style` attribute in server HTML. Every string in `en.yml` and `fr.yml` (French plural with a `zero` form). Active players this week = players with at least one opening in the goal's week; capsules today = packs opened within the current UTC day; first discoveries this week = first discoveries within the goal's week; participants = players whose contributions (openings plus trades) this week are above zero. The goal end is shown through the existing local-time helper, never with "UTC" for a visitor whose zone is known. An empty game shows "0" figures and an empty gauge.

**Never:** Do not touch the feed list in module 04, the lore panel, module 05's example tile, or the hub's goal panel. No planning ids, no comments except one-line external constraints.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live game | published season 1, openings, discoveries, a goal total 30 of 200 | name "Season 1 · Grand catalogue", the three counts, line, "30 / 200", 3 lit segments, participants, end | none |
| Empty game | no opening, discovery or contribution | counts "0", count "0 / target", empty gauge, "0 participant" in French | none |
| No published season | none published | season name "—" | none |
| Day and week bounds | pack opened 23:59 UTC the day before; discovery Sunday 23:59 UTC | not counted | none |
| Cache | second request in the lifetime | no query of either block runs | none |
| Unreadable block | the query raises a database error | that block shows "—"; the page renders | rescued per block |

</intent-contract>

## Code Map

- `packs/game/app/queries/game/current_goal.rb` -- reuse for total, target and `next_week_start`; `Game::WeeklyGoal.week_start` gives the week.
- `packs/game/app/models/game/{weekly_contribution,first_discovery,pack}.rb` -- the counts (`openings`, `trades`, `week_start`; `discovered_at`; `opened_at`).
- `packs/catalog/app/queries/catalog/{landing_roadmap,published_season}.rb` -- the caching pattern and the season; Game may depend on Catalog.
- `app/controllers/landings_controller.rb`, `app/views/landings/{_live,_brotherhood}.html.erb` -- the placeholders (`unknown`) to replace; `landing_gauge` and `GoalHelper#goal_lit_segments`; `local_time_sentence(time, :weekday_time, suffix:)` as in `app/views/pages/how_it_works.html.erb`.
- `config/locales/{en,fr}.yml` -- `landings.show.live`, `landings.show.brotherhood.goal`; reuse `pages.home.goal.line`.
- `test/controllers/landings_controller_test.rb`; query tests beside `test/packs/game/`; `with_memory_cache` in `test/packs/catalog/landing_sample_cards_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/*_index_game_packs_opened_at.rb`, `db/schema.rb` -- a concurrent partial index on `opened_at` of opened packs, regenerated as AGENTS.md says -- the day count scans no table
- [ ] `packs/game/app/queries/game/landing_season_facts.rb` -- `call(locale:)` returns season number and the three counts, cached 1 minute -- season panel
- [ ] `packs/game/app/queries/game/landing_goal.rb` -- `call(locale:)` returns total, target, participants, cached 1 minute -- goal panel
- [ ] `app/controllers/landings_controller.rb`, views, helper, locales -- assign both blocks (nil on a database error), render figures, gauge, participants, end time, "—" fallbacks
- [ ] tests -- queries (bounds, empty, cache hit runs no query), controller (both locales, empty, unreadable block)

**Acceptance Criteria:**
- Given a live game, when a visitor opens the landing, then module 04 shows the season and its three facts and module 02 the goal's line, count, gauge, participants and end.
- Given a second request inside the cache window, when it is served, then neither query runs.
- Given an empty game, when the landing renders, then the designed zero states show.

## Implementation Notes

Copy for the goal end follows the approved line: "Fin {jour} à {heure}. Le prochain objectif s'ouvre aussitôt." Counts use the goal's UTC week and the UTC day (author's decisions). A block that raises a database error shows "—".

## Plan Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 7 findings — high 0, medium 0, low 3, false 4, maybe-false 0
- findings:
  - `[low]` `[patch]` Multi-line doc comments in the two queries — removed.
  - `[low]` `[reject]` End time read from `Game::CurrentGoal.next_week_start` in the view — pure date arithmetic, no SQL; fix would add surface.
  - `[low]` `[defer]` Cached goal figures lag the week boundary up to a minute — accepted stale window.
  - `[low]` `[reject]` Unreadable-block test overrides `call` — restored in ensure; works.
  - `[low]` `[defer]` No request-level cache test.
  - `[false]` `[reject]` Counts not season-scoped — the author's decision defines them over the week and UTC day.
  - `[false]` `[reject]` English `zero` redundant — harmless, i18n-tasks reports no issue.

## Verification

**Commands:**
- `npm install && bin/rails test test/packs/game test/controllers/landings_controller_test.rb` -- expected: pass
- `bin/rails test test/system/landing_*_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health` -- expected: pass

## Auto Run Result

Built: both landing panels read two cached queries (1 minute, per locale) with an index on opened packs' `opened_at`. Files: migration and schema, `Game::LandingSeasonFacts`, `Game::LandingGoal`, `LandingsController`, `_live` and `_brotherhood` views, locales, tests. Patched 1 low; deferred 2 low. Follow-up review not recommended. Verified: game and controller tests, landing system tests (21), vitest (543), zeitwerk, packwerk, rubocop, i18n-tasks (one pre-existing inconsistency).
