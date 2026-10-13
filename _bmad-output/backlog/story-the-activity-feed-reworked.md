---
id: story-the-activity-feed-reworked
type: story
title: "The activity feed reworked, starting with a UX session"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: true
risk: medium
estimate: ""
---

# The activity feed reworked, starting with a UX session

## Description

The author reworks the activity feed in detail, through a UX session first, then the stories it yields: first discoveries crowding TOUT at a season's launch, set completions that arrive late, and what the feed shows and filters.

## Acceptance Criteria

Verify: a UX session with the author produces the updated DESIGN.md and EXPERIENCE.md for the feed and a breakdown into stories; after those stories are built, the timed opening benchmark (`RAILS_ENV=test bin/rails game:benchmark_open_pack`) is run again and its p95 recorded.

## References

- source — _bmad-output/initiative-gameble/pending-approvals.md, settled 2026-10-13 (First discoveries in the feed, story 6.7)
- ux — _bmad-output/initiative-gameble/ux-gameble/

## Notes

- Decision (author, 2026-10-13): a backlog ticket that starts with a UX session (bmad-ux), the benchmark rerun included.
