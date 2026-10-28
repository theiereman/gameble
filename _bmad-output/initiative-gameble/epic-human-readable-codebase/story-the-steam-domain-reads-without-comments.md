---
id: 7
tracker_status: done
tracker_id: ""
type: story
title: "The steam domain reads without comments"
parent: epic-human-readable-codebase
covers: [R2, R4]
after: [2, 3]
hitl: false
risk: medium
---

# The steam domain reads without comments

## Description

Same cleanup for `app/domains/steam` (49 files, 641 comment lines, 44 reference lines), including the Steam API client's 67 comment lines and `details_policy.rb`, keeping the comments that state a Steam API limit.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under `app/domains/steam`; its tests, `bin/rubocop` and `packwerk check` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
