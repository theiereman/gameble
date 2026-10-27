---
id: 5
tracker_status: done
tracker_id: 273
remote: https://github.com/theiereman/gameble/issues/273
type: story
title: "The game domain: queries, events, jobs and handlers read without comments, and write through operations"
parent: epic-human-readable-codebase
covers: [R2, R4]
after: [2, 3]
hitl: false
risk: high
---

# The game domain: queries, events, jobs and handlers read without comments, and write through operations

## Description

Same cleanup for `app/domains/game/app/queries` (46), `events` (24), `jobs` (9), `handlers` and `lib` (including the 379-line `open_pack_benchmark.rb`'s 63 comment lines); folds in the epic 6 leftovers for `sum_weekly_goal_job.rb`, `grant_goal_rewards_job.rb`, `pack_opened_feed.rb`, and optionally reads the rarity tier through `Catalog::CardSeasonTiers` in `pack_opened_feed.rb` and `trade_accepted.rb` and shares the feed visibility rule between the feed readers, when the existing tests pin the behaviour. Also brings the two writes outside operations into the rule: `WeeklyGoal.insert` and `update_all` in `sum_weekly_goal_job.rb`, and `PlayerState.upsert` in `handlers/player_activity.rb` move behind operations (a handler never publishes, so the operation the handler calls must publish nothing the handler's own event does not already cover). The builder judges each write: one that is truly justified as an exception (a bulk insert whose per-row operation would break its performance or its atomicity) stays where it is and AGENTS.md documents that exception with its reason, for that one only; the plan records which of the two was moved and which kept.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under the game domain; `grep -rnE 'insert|upsert|update_all' app/domains/game/app/jobs app/domains/game/app/handlers` finds no write that is neither behind an operation nor documented in AGENTS.md; `bin/rails test test/domains/game`, `bin/rubocop` and `packwerk check` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md

## Notes

- Unknown: Whether each of the two writes moves behind an operation without changing its atomicity or its query count, or is a documented exception; the builder decides per write and records it.
