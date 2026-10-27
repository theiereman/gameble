---
id: 4
tracker_status: done
tracker_id: 272
remote: https://github.com/theiereman/gameble/issues/272
type: story
title: "The game domain: models and operations read without comments"
parent: epic-human-readable-codebase
covers: [R2, R4]
after: [2, 3]
hitl: false
risk: medium
---

# The game domain: models and operations read without comments

## Description

In `app/domains/game/app/models` and `.../operations` (63 files), removes every planning reference, turns each comment that restates a name or narrates a story into a better name or an extracted method, and keeps a comment only for an external constraint, in one line; folds in the epic 6 leftovers for `weekly_goal.rb`, `pack.rb` and `holding.rb` (whose comment about `last_gained_at` is wrong, deferred-work 2026-10-13). No behaviour or query change.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under `app/domains/game/app/models` and `.../operations`; `bin/rails test test/domains/game`, `bin/rubocop` and `packwerk check` pass; the diff touches no test.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
