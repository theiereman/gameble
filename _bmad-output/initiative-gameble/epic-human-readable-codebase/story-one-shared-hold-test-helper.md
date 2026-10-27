---
id: 11
tracker_status: done
tracker_id: 279
remote: https://github.com/theiereman/gameble/issues/279
type: story
title: "One shared `hold` test helper"
parent: epic-human-readable-codebase
covers: [R4]
after: [10]
hitl: false
risk: low
---

# One shared `hold` test helper

## Description

Replaces the 30 copies of `def hold` in the tests with one helper in `test/support/` (the `LibraryRequests#hold` of the request tests being the seed), keeping each call site's arguments (`reserved:`, `gained_at:`, `player:`).

## Acceptance Criteria

Verify: `git grep -c 'def hold' test` returns one definition; `bin/rails test` is green with the same test count.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
