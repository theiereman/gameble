---
id: bug-a-foreign-key-violation-on-holdings-fails-the-full-suite-at-random
type: bug
title: "A foreign key violation on holdings fails the full suite at random"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: low
severity: P2
estimate: ""
---

# A foreign key violation on holdings fails the full suite at random

## Description

Three builds on 2026-10-19 saw the full `bin/rails test` (parallel workers) fail once with a foreign key violation on `game_holdings.card_season_id`, in `Game::WeeklyGoalTest` and `Game::OpenPackTest`; each file passes alone and the suite passes on a rerun, even with the failing seed. Find the shared state (fixtures, a test deleting card seasons or catalog rows another test still references, transaction or worker leakage) and fix it at the cause.

## Acceptance Criteria

Verify: the cause is named in the plan; the full suite run 10 times in a row with parallel workers shows no foreign key violation; no test is skipped or retried to get there.

## References

- builds — plans of tickets 13.13 and #77 (their verification notes)

## Notes

- Filed on 2026-10-19 from the author's decisions on the day's builds.
