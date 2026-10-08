---
title: 'Weekly goal: contributions, the periodic sum and the hub panel'
type: 'feature'
ticket: '3'
created: '2026-10-07'
status: done
baseline_revision: '47cea18b653361d83cd2a5ab133491a1eade4cca'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Brotherhood has no weekly goal: nothing counts the packs players open together, and the hub shows no shared gauge.

**Approach:** Each pack-opened event writes the opener's own contribution row for the UTC week (unique per player and week, no shared row, AD-9/AD-10). A periodic job (config/recurring.yml, AD-12) sums the rows into one goal row per week, which also fixes the target. The hub shows the goal panel in its in-progress state with the single Brotherhood line, in French and English.

## Boundaries & Constraints

**Always:** A week starts Monday 00:00 UTC. Target = previous week's active players (at least one pack opened) x 50, never below 200. The handler runs in the opening's transaction, writes only the opener's row, is one upsert, never fails the opening. The hub read is one cheap query (AD-11, GET never writes). The Brotherhood line is the only Brotherhood copy; "vous", no title; code speaks of weekly goal, locale files of "objectif communautaire".

**Never:** Completed trades counting 1 (story 6.9). Reached, missed and rollover states, the reward booster, the gauge broadcast (later stories). No per-player figure on the panel. No row written by every player.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Opening | a player opens 3 packs in a week | one contribution row, openings = 3 | duplicate never fails |
| Week boundary | opening Sunday 23:59:59 UTC vs Monday 00:00 UTC | two different weeks | none |
| Sum | several players have rows | next job run sets the week's total to their sum | rerun is idempotent |
| Target | previous week had 4 active players / 2 / none | 200 / 200 / 200 (floor); 10 players -> 500 | none |
| Panel | before any job run | total 0 and the computed target | none |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/open_pack.rb` -- publishes `Game::PackOpened {player_id, pack_id}` in the transaction; unchanged.
- `config/initializers/event_store.rb` -- subscribe the new handler (synchronous).
- `packs/game/app/handlers/game/handlers/` -- new `pack_opened.rb`.
- `packs/game/app/models/game/` -- new `weekly_contribution.rb`, `weekly_goal.rb` (week helpers, target).
- `packs/game/app/jobs/game/` -- new `sum_weekly_goal_job.rb`; `config/recurring.yml` entry.
- `packs/game/app/queries/game/current_goal.rb` -- hub read.
- `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb`, new `_goal.html.erb`, `app/frontend/styles/hub.css`, `config/locales/{en,fr}.yml`.
- `test/controllers/pages_controller_test.rb` -- query budgets (PLAYER 13, VISITOR 4) gain 1.

## Tasks & Acceptance

**Execution:**
- [x] migration `game_weekly_contributions` (player_id, week_start date, openings, unique player+week) and `game_weekly_goals` (week_start unique, target, total, summed_at)
- [x] models, handler + subscription, job + recurring entry, query
- [x] hub panel (in-progress), CSS, EN/FR locales
- [x] tests: handler, week boundary, target, job, panel, query budget

**Acceptance Criteria:**
- Given several players open packs, when the job runs, then the week's goal total equals the sum of their openings.
- Given last week had N active players, when this week's goal is created, then target = max(200, 50 x N).
- Given the hub, then the panel shows "n / target" and the Brotherhood line with the real target, in fr and en, for players and visitors.

## Implementation Notes

Implemented directly in this session (no implementation subagent). Decisions:
- Active = a contribution row with openings > 0 (trades, story 6.9, will add their own column).
- Job schedule "every 10 seconds" (AD-13 gauge cadence); it sums the current and previous week, and creates the current week's goal row (target frozen at creation).
- Panel is shown to visitors too (public figure), reward line is "A rare booster" (granted by a later story).

## Plan Change Log

## Review Triage Log

- medium, patched: migration CHECK hard-coded the floor (target >= 200) while the constant is tuned in play; now target > 0.
- low, patched: the job wrote both rows every 10 s; it now updates only when the total changed.
- low, rejected: handler could fail the opening on a DB error (that is the AD-10 contract: synchronous handler, upsert on own row; a savepoint would hide real faults); missing-row fallback costs a second read only until the first job run; no test for the recurring entry (same as the existing one); late-job target freeze is by design; visually-hidden is a shared class used by other views; extra panel tests (lit gauge) are minor.
- low, kept: reward text says "for every contributor" (EXPERIENCE: every contributor of the week gets the booster; delivered by a later story).

## Verification

**Commands:**
- `bin/rails test` (ignore card_face_visual_test.rb), `bundle exec rubocop`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js`
