---
id: story-the-weekly-goal-asks-more
type: story
title: "The weekly community goal asks for 125 per active player, never under 500"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: low
estimate: ""
---

# The weekly community goal asks for 125 per active player, never under 500

## Description

The community reaches its weekly goal days before the week ends: 848 / 200 last week, 430 / 300 by this Wednesday. A week's target becomes the previous week's active players times 125, never below 500, in place of times 50, never below 200. Only goals created after the change use the new target; everything else about the goal stays as it is.

## Acceptance Criteria

1. **A new week's target follows the new rule**
   **Given** a number of players who opened at least one pack the previous week
   **When** the goal of the new week is created
   **Then** its target is that number times 125
2. **The target never falls below 500**
   **Given** a previous week with four or fewer active players, or none
   **When** the goal of the new week is created
   **Then** its target is 500
3. **An existing goal keeps its target**
   **Given** the goal of the current week, created under the old rule
   **When** contributions keep arriving after the change ships
   **Then** its target is unchanged, and it is reached when its total meets that target
4. **Past goals are untouched**
   **Given** goals of earlier weeks, reached or missed
   **When** the change ships
   **Then** their target, total and reached state, and the rewards already granted, are unchanged

## Boundaries

- Must not change: what counts toward the goal (every pack opened and every completed trade), who counts as an active player, the Monday 00:00 UTC start of the week, who earns the reward and the reward capsule itself, the goal's screens and texts.

## References

- source — https://github.com/theiereman/gameble/issues/60
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, the community goal (the line "× 50, never below 200" changes with this ticket)

## Notes

- The issue names the code: `packs/game/app/models/game/weekly_goal.rb` (`PER_PLAYER`, `FLOOR`), `test/packs/game/weekly_goal_test.rb`, `packs/game/app/jobs/game/sum_weekly_goal_job.rb`.
- Decision (author, 2026-10-15): no data migration; the current week's goal keeps its old target (300) and the new rule first applies on the next Monday.
- Open question: the issue asks to review completion rate, completion time, contributors and packs per week after three to four weeks. That review is a later ticket, not part of this one.
