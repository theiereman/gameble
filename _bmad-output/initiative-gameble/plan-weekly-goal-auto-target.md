---
title: 'The weekly mission target follows what the community did the week before'
type: 'feature'
ticket: ''
created: '2026-11-13'
status: 'built'
baseline_revision: '13f81b2371d2a27fcc61f00a6569748bd83a9e71'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The weekly mission's target is the previous week's active players × 125 (at least 500). It ignores how much the community actually did, so it can sit far above or below what players reach week after week.

**Approach:** Recompute the target each week from the previous week, the way Garmin's auto step goal does: start from what was done and add a little when the mission was reached, ease down when it was missed.

Decisions (author, 2026-11-13, "follow and damp"):
- T = the previous week's total (openings + trades, summed from the contribution rows), C = the previous week's target.
- Previous week reached (T ≥ C): target = T × 1.05.
- Previous week missed (T < C): target = (C + T) / 2, so one bad week does not crash it.
- Rounded up to the next multiple of 10, never below 500.
- No previous week goal row: 500.
- The spec's CAP-12 target rule is updated to this rule.

Examples: C=1000,T=1300 → 1370; C=1000,T=1000 → 1050; C=1000,T=600 → 800; C=1000,T=200 → 600; C=600,T=100 → 500.

</frozen-after-approval>

## Implementation Notes

Oneshot: the rule lives in one class method (`Game::WeeklyGoal.target_for`) that both the week's creation and the pre-creation read (`Game::CurrentGoal`) call, plus its tests and the spec line.

## Verification

**Commands:**
- `bin/rails test test/domains/game/weekly_goal_test.rb test/domains/game/weekly_goal_operations_test.rb test/domains/game/goal_reward_test.rb test/jobs/live_goal_job_test.rb` -- expected: green
- `bundle exec rubocop` on touched Ruby files, `bundle exec packwerk check`, `script/check_planning_references` -- expected: clean

## Review Triage Log

Quick review, one pass: 0 high, 1 medium, 4 low, 1 false.
- medium (patched): no test computed a target through the job or the page's fallback read; added one covering both with a reached previous week.
- low (patched): `GROWTH_PERCENT = 105` read as 105% growth; renamed `GROWTH_FACTOR = 1.05r`.
- low (patched): a test name claimed it proved "not the summed total"; renamed to what it proves (only the previous week counts).
- low (rejected): an opening committed in the milliseconds after Monday's first job run is missing from T, so a borderline week could be judged missed for the target yet reached for the reward; the old rule had the same window, and closing it means reworking the job's ordering for a rare, harmless outcome.
- low (rejected): a missing previous week row with older history falls back to 500; that is the decided rule, already covered by the floor test.
- false: plan frontmatter in the diff differs from disk; the diff was taken before review bookkeeping was written.
