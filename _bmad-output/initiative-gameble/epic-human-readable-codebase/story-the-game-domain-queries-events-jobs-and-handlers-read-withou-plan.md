---
title: 'The game domain: queries, events, jobs and handlers read without comments, and write through operations'
type: 'refactor'
ticket: 5
created: '2026-10-27'
status: 'built'
baseline_revision: '0db736ce'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The game domain's queries, events, jobs, handlers and benchmark carry about 400 comment lines that narrate code or cite planning ids, and two writes sit outside operations.

**Approach:** Delete the narrating comments; move the two writes behind operations unless a documented exception is justified.

## Boundaries & Constraints

**Always:** `script/check_planning_references` clean; behaviour unchanged; same query count.

**Never:** touch models and operations of 12.4 beyond the new operations; add planning ids.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] queries, events, jobs, handlers, `lib/` -- delete full-line comments, keep two external-constraint one-liners (benchmark rake reload, rate-limit cache store)
- [x] `pack_opened_feed.rb`, `trade_accepted.rb` -- read the rarity tier through `Catalog::CardSeasonTiers` (identical query, tests pin it)
- [x] `sum_weekly_goal_job.rb` -- writes moved behind `Game::CreateWeeklyGoal` and `Game::SumWeeklyGoal`
- [x] `player_activity.rb` -- upsert moved behind `Game::RecordPlayerActivity`

**Acceptance Criteria:**
- Given the game domain, when `script/check_planning_references` runs, then it reports nothing.
- Given jobs and handlers, when grepped for `insert|upsert|update_all`, then no write is left outside an operation.

## Implementation Notes

Verdicts on the two writes: both moved, no exception kept, AGENTS.md unchanged.
- `WeeklyGoal.insert` / `update_all` (sum job): moved. One insert and one update per week, as before; the per-week operation keeps the aggregate, the update and the count of moved rows; the job still enqueues the reward grant after the operation, from a read. Nothing published: the weekly sum has no event of its own.
- `PlayerState.upsert` (player activity handler): moved. The operation is one upsert, publishes nothing (the handler's own event already covers it), joins the caller's transaction and adds no query. The "nothing more is published" test still holds.
- The optional shared feed visibility rule between feed readers was not attempted (optional in the ticket).

Review: no review subagents run in this worktree session; the diff was self-reviewed. `ApplicationOperation` wraps a returned value in `Success`, so the new operations return plain values (a first draft double-wrapped `Success(false)` and a test caught it).

## Plan Change Log

## Review Triage Log

Self-review only; no findings.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/domains/accounts test/domains/catalog test/controllers` -- 2344 runs, 0 failures
- `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- clean
